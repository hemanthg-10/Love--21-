import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<int> love21VerifiedDays = ValueNotifier<int>(0);
final ValueNotifier<bool> love21NavigationUnlocked = ValueNotifier<bool>(false);
final ValueNotifier<int> love21SelectedTab = ValueNotifier<int>(0);

/// Local-only demo data. These simulated outcomes never call Supabase.
class LoveDemo {
  LoveDemo._();
  static const _daysKey = 'love21_demo_verified_days';
  static const _ageKey = 'love21_demo_age_eligible';
  static const _discoveryEligibilityKey = 'love21_demo_discovery_eligible';
  static const _genderKey = 'love21_demo_registered_gender';
  static const _previewNoticeKey = 'love21_demo_preview_notice_shown';
  static const _interestsKey = 'love21_demo_interested_profiles';
  static const _messagesKey = 'love21_demo_chat_messages';
  static const _likesKey = 'love21_demo_incoming_likes';
  static bool get enabled => !LoveBackend.configured;

  static Future<int> verifiedDays() async {
    final value = (await SharedPreferences.getInstance()).getInt(_daysKey) ?? 0;
    love21VerifiedDays.value = value.clamp(0, 21).toInt();
    return love21VerifiedDays.value;
  }

  static Future<void> setVerifiedDays(int value) async {
    final safeValue = value.clamp(0, 21).toInt();
    love21VerifiedDays.value = safeValue;
    await (await SharedPreferences.getInstance()).setInt(_daysKey, safeValue);
  }

  static Future<void> addVerifiedDay() async =>
      setVerifiedDays((await verifiedDays()) + 1);
  static Future<void> setAgeEligible(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_ageKey, value);
  static Future<bool> ageEligible() async =>
      (await SharedPreferences.getInstance()).getBool(_ageKey) ?? true;
  static Future<String> identityStatus() async => 'pending';
  static Future<bool> discoveryEligible() async =>
      (await SharedPreferences.getInstance()).getBool(
        _discoveryEligibilityKey,
      ) ??
      false;
  static Future<void> setDiscoveryEligible(bool value) async {
    love21NavigationUnlocked.value = value;
    await (await SharedPreferences.getInstance()).setBool(
      _discoveryEligibilityKey,
      value,
    );
  }

  static Future<void> setRegisteredGender(String value) async =>
      (await SharedPreferences.getInstance()).setString(_genderKey, value);
  static Future<String?> registeredGender() async =>
      (await SharedPreferences.getInstance()).getString(_genderKey);
  static Future<bool> previewNoticeShown() async =>
      (await SharedPreferences.getInstance()).getBool(_previewNoticeKey) ?? false;
  static Future<void> markPreviewNoticeShown() async =>
      (await SharedPreferences.getInstance()).setBool(_previewNoticeKey, true);

  static Future<List<Map<String, dynamic>>> interestedProfiles() async {
    final raw = (await SharedPreferences.getInstance()).getString(_interestsKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).map((row) => Map<String, dynamic>.from(row as Map)).toList(); }
    catch (_) { return []; }
  }
  static Future<void> addInterestedProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await interestedProfiles();
    final id = profile['candidate_id'].toString();
    if (rows.any((row) => row['candidate_id'].toString() == id)) return;
    rows.insert(0, {...profile, 'id': id, 'matched_at': DateTime.now().toIso8601String(), 'demo_status': 'Demo interest • awaiting mutual interest'});
    await prefs.setString(_interestsKey, jsonEncode(rows));
  }
  static Future<List<Map<String, dynamic>>> demoMessages(String profileId) async {
    final raw = (await SharedPreferences.getInstance()).getString(_messagesKey);
    if (raw == null) return [];
    try { final all = Map<String, dynamic>.from(jsonDecode(raw) as Map); return (all[profileId] as List? ?? []).map((row) => Map<String, dynamic>.from(row as Map)).toList(); }
    catch (_) { return []; }
  }
  static Future<void> addDemoMessage(String profileId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesKey);
    final all = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final rows = List<Map<String, dynamic>>.from((all[profileId] as List? ?? []).map((row) => Map<String, dynamic>.from(row as Map)));
    rows.add({'sender_id': 'demo_me', 'body': text.trim(), 'created_at': DateTime.now().toIso8601String()});
    all[profileId] = rows;
    await prefs.setString(_messagesKey, jsonEncode(all));
  }
  static Future<String?> quizAnswer(int day) async =>
      (await SharedPreferences.getInstance()).getString('love21_quiz_$day');
  static Future<void> saveQuizAnswer(int day, String answer) async =>
      (await SharedPreferences.getInstance()).setString('love21_quiz_$day', answer);
  static Future<List<Map<String, dynamic>>> incomingLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_likesKey);
    if (raw != null) {
      try { return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    }
    final seeded = [
      {'candidate_id':'demo_like_maya','display_name':'Maya','age':22,'gender':'Woman','short_bio':'Loves weekend hikes and quiet coffee shops.','interests':['Hiking','Coffee','Travel'],'message':'Maybe this is the beginning of something lovely.'},
      {'candidate_id':'demo_like_anika','display_name':'Anika','age':23,'gender':'Woman','short_bio':'Finding joy in music, books, and new recipes.','interests':['Music','Reading','Cooking'],'message':'Someone noticed your smile. Start with a simple hello.'},
    ];
    await prefs.setString(_likesKey, jsonEncode(seeded));
    return seeded;
  }
  static Future<void> removeIncomingLike(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await incomingLikes(); rows.removeWhere((e) => e['candidate_id'] == id);
    await prefs.setString(_likesKey, jsonEncode(rows));
  }
  static Future<void> reset() async {
    await (await SharedPreferences.getInstance()).clear();
    love21VerifiedDays.value = 0;
    love21NavigationUnlocked.value = false;
  }
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

  static Future<List<Map<String, dynamic>>> discoveryCandidates({
    int offset = 0,
  }) async {
    final result = await client.rpc(
      'get_discovery_candidates_page',
      params: {'p_offset': offset, 'p_limit': 20},
    );
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> mySavedProfiles() async {
    final result = await client.rpc('my_saved_discovery_profiles');
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> myProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in again.');
    final row = await client
        .from('profiles')
        .select('full_name, short_bio, profile_photo_path')
        .eq('id', user.id)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> updateMyProfile({
    required String fullName,
    required String shortBio,
    String? profilePhotoPath,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in again.');
    await client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'short_bio': shortBio.trim(),
          if (profilePhotoPath != null) 'profile_photo_path': profilePhotoPath,
        })
        .eq('id', user.id);
  }

  static Future<String> uploadProfilePhoto(XFile photo) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in again.');
    final path =
        '${user.id}/${DateTime.now().toUtc().microsecondsSinceEpoch}.jpg';
    await client.storage
        .from('private-profile-photos')
        .uploadBinary(
          path,
          await photo.readAsBytes(),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  static Future<String?> myProfilePhotoUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    return client.storage
        .from('private-profile-photos')
        .createSignedUrl(path, 15 * 60);
  }

  static Future<void> removeMyProfilePhoto(String path) async {
    await client.storage.from('private-profile-photos').remove([path]);
  }

  static Future<Map<String, dynamic>> photoRevealStatus(
    String connectionId,
  ) async {
    final result = await client.rpc(
      'my_photo_reveal_status',
      params: {'p_connection_id': connectionId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<bool> setPhotoRevealConsent(
    String connectionId,
    bool consented,
  ) async {
    final result = await client.rpc(
      'set_photo_reveal_consent',
      params: {'p_connection_id': connectionId, 'p_consented': consented},
    );
    return result == true;
  }

  static Future<String?> revealedPartnerPhotoUrl(String connectionId) async {
    final path = await client.rpc(
      'my_revealed_partner_photo_path',
      params: {'p_connection_id': connectionId},
    );
    if (path == null || path.toString().isEmpty) return null;
    return client.storage
        .from('private-profile-photos')
        .createSignedUrl(path.toString(), 15 * 60);
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
    if (client.auth.currentUser == null) return [];
    final result = await client.rpc('my_connection_previews');
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
