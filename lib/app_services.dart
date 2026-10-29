import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only demo data. These simulated outcomes never call Supabase.
class LoveDemo {
  LoveDemo._();
  static const _daysKey = 'love21_demo_verified_days';
  static const _ageKey = 'love21_demo_age_eligible';
  static const _identityKey = 'love21_demo_identity_status';
  static const enabled = true;

  static Future<int> verifiedDays() async =>
      (await SharedPreferences.getInstance()).getInt(_daysKey) ?? 0;
  static Future<void> setVerifiedDays(int value) async =>
      (await SharedPreferences.getInstance()).setInt(
        _daysKey,
        value.clamp(0, 21),
      );
  static Future<void> addVerifiedDay() async =>
      setVerifiedDays((await verifiedDays()) + 1);
  static Future<void> setAgeEligible(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_ageKey, value);
  static Future<bool> ageEligible() async =>
      (await SharedPreferences.getInstance()).getBool(_ageKey) ?? true;
  static Future<void> setIdentityStatus(String value) async =>
      (await SharedPreferences.getInstance()).setString(_identityKey, value);
  static Future<String> identityStatus() async =>
      (await SharedPreferences.getInstance()).getString(_identityKey) ??
      'verified';
  static Future<void> reset() async =>
      (await SharedPreferences.getInstance()).clear();
}

class LoveBackend {
  LoveBackend._();

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get configured => _url.isNotEmpty && _publishableKey.isNotEmpty;
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (configured) {
      await Supabase.initialize(url: _url, publishableKey: _publishableKey);
    }
  }

  static Future<AuthResponse> createAccount({
    required String email,
    required String password,
    required String fullName,
    required DateTime birthDate,
    required String gender,
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'birth_date': birthDate.toIso8601String().split('T').first,
        'gender': gender,
      },
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> resendEmailVerification(String email) {
    return client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  static Future<bool> checkAgeEligibility() async {
    final result = await client.rpc('check_my_age_eligibility');
    return result == true;
  }

  static Future<bool> checkBirthDateBeforeSignUp(DateTime birthDate) async {
    final result = await client.rpc(
      'check_age_for_registration',
      params: {'p_birth_date': birthDate.toIso8601String().split('T').first},
    );
    return result == true;
  }

  static Future<int> verifiedDayCount() async {
    final result = await client.rpc('my_verified_day_count');
    return (result as num).toInt();
  }

  static Future<bool> canParticipateInChallenge() async {
    final result = await client.rpc('my_challenge_eligibility');
    return result == true;
  }

  static Future<String> identityStatus() async {
    final user = client.auth.currentUser;
    if (user == null) return 'pending';
    final row = await client
        .from('profiles')
        .select('identity_status')
        .eq('id', user.id)
        .single();
    return row['identity_status'] as String;
  }

  static Future<bool> canDiscover() async {
    final result = await client.rpc('my_discovery_eligibility');
    return result == true;
  }

  static Future<List<Map<String, dynamic>>> discoveryCandidates() async {
    final result = await client.rpc('get_discovery_candidates');
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<String> submitChallengePhoto({
    required XFile photo,
    required String caption,
    required int challengeDay,
  }) async {
    final user = client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in again to submit your day.');

    final Uint8List bytes = await photo.readAsBytes();
    final objectPath =
        '${user.id}/${DateTime.now().toUtc().microsecondsSinceEpoch}.jpg';
    await client.storage
        .from('private-challenge-photos')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    try {
      final result = await client.rpc(
        'submit_challenge_day',
        params: {
          'p_challenge_day': challengeDay,
          'p_photo_path': objectPath,
          'p_caption': caption.trim(),
        },
      );
      return result.toString();
    } catch (_) {
      // Keep rejected uploads private and remove an object that was never recorded.
      try {
        await client.storage.from('private-challenge-photos').remove([
          objectPath,
        ]);
      } catch (_) {
        // A server cleanup job should remove orphaned private uploads.
      }
      rethrow;
    }
  }

  static Future<String> challengeSubmissionStatus(String submissionId) async {
    final row = await client
        .from('challenge_submissions')
        .select('status')
        .eq('id', submissionId)
        .single();
    return row['status'] as String;
  }

  static Future<void> appealChallengeSubmission({
    required String submissionId,
    required String reason,
  }) async {
    await client.rpc(
      'appeal_challenge_submission',
      params: {'p_submission_id': submissionId, 'p_reason': reason.trim()},
    );
  }

  static Future<String?> submitInterest({
    required String otherUserId,
    String? promptComment,
  }) async {
    final result = await client.rpc(
      'submit_interest',
      params: {
        'p_target_user_id': otherUserId,
        'p_prompt_comment': promptComment,
      },
    );
    return result?.toString();
  }

  static Future<void> recordDiscoveryAction({
    required String otherUserId,
    required String action,
  }) {
    return client.rpc(
      'record_discovery_action',
      params: {'p_target_user_id': otherUserId, 'p_action': action},
    );
  }

  static Future<void> sendTextMessage({
    required String connectionId,
    required String text,
  }) {
    return client.rpc(
      'send_connection_message',
      params: {'p_connection_id': connectionId, 'p_message': text.trim()},
    );
  }

  static Future<void> blockUser(String userId) =>
      client.rpc('block_user', params: {'p_blocked_user_id': userId});

  static Future<String> reportUser({
    required String userId,
    required String category,
    required String details,
  }) async {
    final id = await client.rpc(
      'report_user',
      params: {
        'p_reported_user_id': userId,
        'p_category': category,
        'p_details': details,
      },
    );
    return id.toString();
  }

  static Future<void> unmatch(String connectionId) => client.rpc(
    'unmatch_connection',
    params: {'p_connection_id': connectionId},
  );

  static Future<void> updateSettings({
    required bool notificationsEnabled,
    required bool profileVisible,
  }) => client.rpc(
    'update_my_settings',
    params: {
      'p_notifications_enabled': notificationsEnabled,
      'p_profile_visible': profileVisible,
    },
  );

  static Future<Map<String, dynamic>> mySettings() async {
    final user = client.auth.currentUser;
    if (user == null)
      return {'notifications_enabled': true, 'profile_visible': true};
    final row = await client
        .from('user_settings')
        .select('notifications_enabled, profile_visible')
        .eq('user_id', user.id)
        .maybeSingle();
    return row ?? {'notifications_enabled': true, 'profile_visible': true};
  }

  static Future<void> requestAccountDeletion() =>
      client.rpc('request_account_deletion');

  static Future<List<Map<String, dynamic>>> connectionMessages(
    String connectionId,
  ) async {
    final result = await client
        .from('messages')
        .select('id, sender_id, body, created_at')
        .eq('connection_id', connectionId)
        .order('created_at');
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> myConnections() async {
    final user = client.auth.currentUser;
    if (user == null) return [];
    final result = await client
        .from('connections')
        .select('id, user_a, user_b, matched_at')
        .or('user_a.eq.' + user.id + ',user_b.eq.' + user.id)
        .isFilter('unmatched_at', null)
        .order('matched_at', ascending: false);
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
