import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_services.dart';
import 'app_theme.dart';

const int minimumAge =
    20; // Existing formal rule; see README for the 18+ conflict.

class Love21App extends StatelessWidget {
  const Love21App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Love 21',
    debugShowCheckedModeBanner: false,
    theme: buildLoveTheme(),
    home: const WelcomePage(),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    showBack: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const BrandMark(),
        const SizedBox(height: 24),
        Container(
          height: 225,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5D8D0), Color(0xFFE9C5B4), LoveColors.wine],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 24,
                top: 26,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 108,
                  color: Colors.white.withValues(alpha: .3),
                ),
              ),
              const Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Text(
                  'A slower way\nto find something real.',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Meaningful love, unhurried',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Build a daily rhythm around the things you love. Complete the 21-day challenge before meeting people.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: LoveColors.charcoal,
          ),
        ),
        const SizedBox(height: 16),
        const NoticeBox(
          'Adults only • Age and identity checks required before discovery',
          Icons.verified_user_outlined,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => go(context, const CreateAccountPage()),
          child: const Text('Start your journey'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => go(context, const LoginPage()),
          child: const Text('I already have an account'),
        ),
        TextButton(
          onPressed: () => showDemoNotice(context),
          child: const Text('Explore the screens in demo mode'),
        ),
        const Center(
          child: Text(
            'By continuing, you agree to Love 21’s community rules and privacy terms.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: LoveColors.taupe),
          ),
        ),
      ],
    ),
  );
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});
  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate() ||
        _birthDate == null ||
        _gender == null) {
      notice(context, 'Add your birth date and gender to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (LoveBackend.configured) {
        final eligible = await LoveBackend.checkBirthDateBeforeSignUp(
          _birthDate!,
        );
        if (!mounted) return;
        if (!eligible) {
          go(context, const AgeRestrictionPage());
          return;
        }
        await LoveBackend.createAccount(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          birthDate: _birthDate!,
          gender: _gender!,
        );
      } else {
        await showDemoNotice(context);
      }
      if (!mounted) return;
      go(
        context,
        ContactVerificationPage(
          email: _email.text.trim(),
          name: _name.text.trim(),
          birthDate: _birthDate!,
          gender: _gender!,
        ),
      );
    } on AuthException catch (e) {
      if (mounted) notice(context, e.message);
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Could not create the account. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Create account',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A good connection starts with a little context.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your birth date stays private. The server checks whether you meet the age requirement.',
        ),
        const SizedBox(height: 18),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'Use at least 8 characters',
                ),
                validator: (v) => v != null && v.length >= 8
                    ? null
                    : 'Use at least 8 characters',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _chooseBirthDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            _birthDate?.toLocal().toString().split(' ').first ??
                'Date of birth',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const [
            DropdownMenuItem(value: 'Man', child: Text('Man')),
            DropdownMenuItem(value: 'Woman', child: Text('Woman')),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 14),
        const NoticeBox(
          'Design notes say 18+, while the formal product rule says 20+. This app keeps the formal 20+ rule until approved otherwise.',
          Icons.info_outline,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating…' : 'Create account'),
        ),
      ],
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _error = false;
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = true);
      return;
    }
    if (!LoveBackend.configured) {
      await showDemoNotice(context);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await LoveBackend.signIn(email: _email.text, password: _password.text);
      if (!mounted) return;
      if (!await LoveBackend.checkAgeEligibility()) {
        go(context, const AgeRestrictionPage());
        return;
      }
      if (mounted) go(context, const MainShell());
    } on AuthException catch (_) {
      if (mounted) setState(() => _error = true);
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Love 21 could not confirm your account. Retry when online.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Welcome back',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick up where you left off.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        if (_error) ...[
          const SizedBox(height: 12),
          const ErrorBox(
            'We could not sign you in. Check your email and password, then try again.',
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => go(context, RecoveryPage(email: _email.text)),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy ? null : _login,
          child: Text(_busy ? 'Signing in…' : 'Log in'),
        ),
        TextButton(
          onPressed: () => go(context, const MainShell()),
          child: const Text('Preview the app (demo only)'),
        ),
      ],
    ),
  );
}

class RecoveryPage extends StatelessWidget {
  RecoveryPage({super.key, required this.email});
  final String email;
  final _email = TextEditingController();
  @override
  Widget build(BuildContext context) {
    _email.text = email;
    return FlowPage(
      title: 'Account recovery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Let’s get you back in.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your account email. The server will send a secure reset link if recovery is available.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (!LoveBackend.configured) {
                await showDemoNotice(context);
                return;
              }
              try {
                await LoveBackend.client.auth.resetPasswordForEmail(
                  _email.text.trim(),
                );
                if (context.mounted)
                  notice(
                    context,
                    'If the account can be recovered, a reset link has been sent.',
                  );
              } catch (_) {
                if (context.mounted)
                  notice(context, 'Could not send the reset link. Try again.');
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}

class ContactVerificationPage extends StatelessWidget {
  const ContactVerificationPage({
    super.key,
    required this.email,
    required this.name,
    required this.birthDate,
    required this.gender,
  });
  final String email, name, gender;
  final DateTime birthDate;
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Verify your email',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 60,
          color: LoveColors.wine,
        ),
        const SizedBox(height: 16),
        Text(
          'Check your inbox',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to $email. Your account stays gated until the provider confirms it.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            if (!LoveBackend.configured) {
              await showDemoNotice(context);
              return;
            }
            try {
              await LoveBackend.resendEmailVerification(email);
              if (context.mounted)
                notice(
                  context,
                  'If the address can be verified, a new link has been sent.',
                );
            } catch (_) {
              if (context.mounted)
                notice(
                  context,
                  'Could not resend. Check the address and retry.',
                );
            }
          },
          child: const Text('Resend verification link'),
        ),
        const SizedBox(height: 10),
        const NoticeBox(
          'Demo mode does not send email or create a real account.',
          Icons.visibility_outlined,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => go(context, HobbiesPage(name: name)),
          child: const Text('Preview next step (demo only)'),
        ),
      ],
    ),
  );
}

class AgeRestrictionPage extends StatelessWidget {
  const AgeRestrictionPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Age requirement',
    showBack: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, size: 60, color: LoveColors.wine),
        const SizedBox(height: 18),
        Text(
          'You can’t continue yet.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'Love 21 is configured for people aged $minimumAge or older. The server checks eligibility. Users who do not meet the requirement cannot join the challenge or use discovery.',
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Return to welcome'),
        ),
      ],
    ),
  );
}

class HobbiesPage extends StatefulWidget {
  const HobbiesPage({super.key, required this.name});
  final String name;
  @override
  State<HobbiesPage> createState() => _HobbiesPageState();
}

class _HobbiesPageState extends State<HobbiesPage> {
  final _selected = <String>{};
  final _groups = const {
    'Daily hobbies': ['Cooking', 'Gardening', 'Photography', 'Writing'],
    'Movement': ['Walking', 'Running', 'Yoga', 'Fitness', 'Football'],
    'Culture': ['Books', 'Cinema', 'Music', 'Travel', 'Art'],
  };
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Your interests',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What do you enjoy?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a few things you would happily make time for. You can edit these later.',
        ),
        for (final group in _groups.entries) ...[
          const SizedBox(height: 16),
          Text(group.key, style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final item in group.value)
                FilterChip(
                  label: Text(item),
                  selected: _selected.contains(item),
                  onSelected: (v) => setState(
                    () => v ? _selected.add(item) : _selected.remove(item),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => go(context, ProfilePreviewPage(name: widget.name)),
          child: const Text('Preview your profile'),
        ),
        const SizedBox(height: 8),
        const NoticeBox(
          'Interests help with hobby-based discovery. Challenge photos are private.',
          Icons.favorite_border,
        ),
      ],
    ),
  );
}

class ProfilePreviewPage extends StatefulWidget {
  const ProfilePreviewPage({super.key, required this.name});
  final String name;
  @override
  State<ProfilePreviewPage> createState() => _ProfilePreviewPageState();
}

class _ProfilePreviewPageState extends State<ProfilePreviewPage> {
  final _bio = TextEditingController();
  String? _preference;
  Uint8List? _profilePhoto;
  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) setState(() => _profilePhoto = bytes);
      }
    } catch (_) {
      if (mounted) notice(context, 'Could not open the photo library.');
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Profile preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A first impression, in your words.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _pickProfilePhoto,
            child: CircleAvatar(
              radius: 54,
              backgroundColor: LoveColors.blush,
              backgroundImage: _profilePhoto == null
                  ? null
                  : MemoryImage(_profilePhoto!),
              child: _profilePhoto == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: LoveColors.wine,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Choose a profile photo separately')),
        const SizedBox(height: 16),
        Text(
          widget.name.isEmpty ? 'Your name' : widget.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bio,
          maxLength: 180,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText: 'A few words about you',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _preference,
          decoration: const InputDecoration(labelText: 'I am interested in'),
          items: const [
            DropdownMenuItem(value: 'Man', child: Text('Men')),
            DropdownMenuItem(value: 'Woman', child: Text('Women')),
            DropdownMenuItem(value: 'Both', child: Text('Men and women')),
          ],
          onChanged: (value) => setState(() => _preference = value),
        ),
        const SizedBox(height: 14),
        const NoticeBox(
          'Challenge photos are stored separately and never appear here unless you choose a profile photo yourself.',
          Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => go(context, const IdentityPage()),
          child: const Text('Continue to identity check'),
        ),
      ],
    ),
  );
}

class IdentityPage extends StatefulWidget {
  const IdentityPage({super.key});
  @override
  State<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends State<IdentityPage> {
  String _status = 'pending';
  bool _loading = false;
  Future<void> _refresh() async {
    if (!LoveBackend.configured || LoveBackend.client.auth.currentUser == null)
      return;
    setState(() => _loading = true);
    try {
      final value = await LoveBackend.identityStatus();
      if (mounted) setState(() => _status = value);
    } catch (_) {
      if (mounted) notice(context, 'Could not refresh identity status.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Identity verification',
    actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A safer community, by design.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Identity checks must run through an authorized provider, with your consent. No provider is configured for this project yet.',
        ),
        const SizedBox(height: 18),
        StateCard(
          title: 'Identity status',
          value: _loading ? 'Checking…' : _status,
          body: _status == 'verified'
              ? 'The authorized provider confirmed your identity.'
              : _status == 'failed'
              ? 'The provider could not verify you. Retry through the approved provider when connected.'
              : 'Challenge and discovery remain gated until the provider confirms your identity.',
          color: _status == 'verified'
              ? LoveColors.green
              : _status == 'failed'
              ? LoveColors.red
              : LoveColors.amber,
          icon: _status == 'verified'
              ? Icons.verified_outlined
              : _status == 'failed'
              ? Icons.error_outline
              : Icons.hourglass_top,
        ),
        const SizedBox(height: 12),
        const NoticeBox(
          'Do not upload identity documents into this demo app.',
          Icons.privacy_tip_outlined,
        ),
        const SizedBox(height: 18),
        const FilledButton(
          onPressed: null,
          child: Text('Provider setup required'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => go(context, const ChallengeIntroPage()),
          child: const Text('Preview challenge rules (demo only)'),
        ),
      ],
    ),
  );
}

class ChallengeIntroPage extends StatelessWidget {
  const ChallengeIntroPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'The 21-day challenge',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Consistency makes room for connection.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a daily hobby moment, capture it, and submit it for review. A day counts only after the backend marks it Verified.',
        ),
        const SizedBox(height: 16),
        const RuleLine(
          Icons.verified_outlined,
          'Verified only',
          'Pending and rejected submissions do not count.',
        ),
        const RuleLine(
          Icons.lock_outline,
          'Private by default',
          'Challenge photos never automatically become profile photos.',
        ),
        const RuleLine(
          Icons.calendar_month_outlined,
          '21 verified days',
          'Discovery stays locked until the backend confirms challenge and account eligibility.',
        ),
        const SizedBox(height: 12),
        const NoticeBox(
          'Missed-day policy is unresolved. A proposed grace-token rule in the design is not treated as approved.',
          Icons.info_outline,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => go(context, const ChallengeDashboardPage()),
          child: const Text('Preview challenge dashboard'),
        ),
      ],
    ),
  );
}

class ChallengeDashboardPage extends StatefulWidget {
  const ChallengeDashboardPage({super.key});
  @override
  State<ChallengeDashboardPage> createState() => _ChallengeDashboardPageState();
}

class _ChallengeDashboardPageState extends State<ChallengeDashboardPage> {
  int _verified = 0;
  String? _error;
  bool _canSubmit = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (LoveDemo.enabled) {
      final value = await LoveDemo.verifiedDays();
      if (mounted)
        setState(() {
          _verified = value;
          _canSubmit = true;
        });
      return;
    }
    if (!LoveBackend.configured || LoveBackend.client.auth.currentUser == null)
      return;
    try {
      final value = await LoveBackend.verifiedDayCount();
      final canSubmit = await LoveBackend.canParticipateInChallenge();
      if (mounted)
        setState(() {
          _verified = value;
          _canSubmit = canSubmit;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Progress could not be refreshed. Retry when online.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Your challenge',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'One day at a time.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$_verified of 21 days verified',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: _verified / 21,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: LoveColors.wine,
          backgroundColor: LoveColors.elevated,
        ),
        const SizedBox(height: 14),
        if (LoveDemo.enabled)
          const NoticeBox(
            'DEMO MODE • Local progress is saved on this device. Review outcomes are simulated.',
            Icons.visibility_outlined,
          ),
        if (_error != null) ErrorBox(_error!),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            21,
            (i) => Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _verified ? LoveColors.wine : LoveColors.card,
                border: Border.all(
                  color: i < _verified ? LoveColors.wine : LoveColors.border,
                ),
              ),
              child: Text(
                (i + 1).toString(),
                style: TextStyle(
                  color: i < _verified ? Colors.white : LoveColors.taupe,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const StateCard(
          title: 'Today',
          value: 'Ready to submit',
          body:
              'Choose a hobby activity and share one private photo for review.',
          color: LoveColors.amber,
          icon: Icons.camera_alt_outlined,
        ),
        const SizedBox(height: 12),
        if (LoveBackend.configured && !_canSubmit)
          const NoticeBox(
            'Contact, age, and identity checks must be verified before the challenge can begin.',
            Icons.lock_outline,
          ),
        FilledButton(
          onPressed: _verified >= 21
              ? () => go(context, const ChallengeCompletionPage())
              : _canSubmit
              ? () => go(context, DailySubmissionPage(day: _verified + 1))
              : null,
          child: Text(
            _verified >= 21
                ? 'View challenge completion'
                : _canSubmit
                ? 'Submit today’s activity'
                : 'Challenge locked',
          ),
        ),
        if (LoveDemo.enabled && _verified < 21) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await LoveDemo.addVerifiedDay();
              await _load();
              if (mounted)
                notice(
                  context,
                  'Demo review: Day ${_verified} marked Verified.',
                );
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('Simulate verified day'),
          ),
          OutlinedButton(
            onPressed: () async {
              await LoveDemo.reset();
              await _load();
              if (mounted) notice(context, 'Local demo progress reset.');
            },
            child: const Text('Reset demo progress'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => go(context, const DiscoveryGatePage()),
          child: const Text('Check discovery access'),
        ),
      ],
    ),
  );
}

class ChallengeCompletionPage extends StatefulWidget {
  const ChallengeCompletionPage({super.key});
  @override
  State<ChallengeCompletionPage> createState() =>
      _ChallengeCompletionPageState();
}

class _ChallengeCompletionPageState extends State<ChallengeCompletionPage> {
  bool _eligible = false;
  bool _loading = false;
  Future<void> _check() async {
    if (LoveDemo.enabled) {
      final days = await LoveDemo.verifiedDays();
      if (mounted) setState(() => _eligible = days >= 21);
      return;
    }
    if (!LoveBackend.configured) {
      notice(context, 'Demo mode cannot unlock discovery.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await LoveBackend.canDiscover();
      if (mounted) setState(() => _eligible = result);
    } catch (_) {
      if (mounted)
        notice(context, 'The backend could not confirm eligibility.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Challenge complete',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.auto_awesome, size: 58, color: LoveColors.gold),
        const SizedBox(height: 18),
        Text(
          '21 days, thoughtfully kept.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'The backend must confirm every required day and your current account eligibility before discovery opens.',
        ),
        const SizedBox(height: 16),
        StateCard(
          title: 'Discovery',
          value: _eligible ? 'Unlocked by server' : 'Still locked',
          body: _eligible
              ? 'Your account is eligible. Candidate profiles must come from the backend.'
              : 'Challenge completion alone does not unlock discovery until server checks finish.',
          color: _eligible ? LoveColors.green : LoveColors.amber,
          icon: _eligible ? Icons.lock_open : Icons.lock_outline,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _loading ? null : _check,
          child: Text(_loading ? 'Checking…' : 'Check eligibility'),
        ),
      ],
    ),
  );
}

class DailySubmissionPage extends StatefulWidget {
  const DailySubmissionPage({super.key, required this.day});
  final int day;
  @override
  State<DailySubmissionPage> createState() => _DailySubmissionPageState();
}

class _DailySubmissionPageState extends State<DailySubmissionPage> {
  final _caption = TextEditingController();
  XFile? _photo;
  Uint8List? _bytes;
  bool _busy = false;
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted)
          setState(() {
            _photo = file;
            _bytes = bytes;
          });
      }
    } catch (_) {
      if (mounted)
        notice(context, 'Could not open the camera or photo library.');
    }
  }

  Future<void> _submit() async {
    if (_photo == null || _caption.text.trim().isEmpty) {
      notice(context, 'Add a photo and a short caption first.');
      return;
    }
    if (LoveDemo.enabled) {
      await LoveDemo.addVerifiedDay();
      if (mounted)
        go(context, const SubmissionStatusPage(initialStatus: 'verified'));
      return;
    }
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      await showDemoNotice(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final submissionId = await LoveBackend.submitChallengePhoto(
        photo: _photo!,
        caption: _caption.text,
        challengeDay: widget.day,
      );
      if (mounted)
        go(context, SubmissionStatusPage(submissionId: submissionId));
    } catch (_) {
      if (mounted)
        go(context, const SubmissionStatusPage(initialStatus: 'upload_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Daily activity',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Day ' + widget.day.toString(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Capture a real hobby moment. This entry stays private and needs review.',
        ),
        const SizedBox(height: 16),
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(_bytes!, height: 210, fit: BoxFit.cover),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: LoveColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LoveColors.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: LoveColors.wine,
                ),
                SizedBox(height: 8),
                Text('Private challenge photo'),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Library'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          maxLength: 140,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Caption',
            hintText: 'What did this moment mean to you?',
          ),
        ),
        const SizedBox(height: 8),
        const NoticeBox(
          'Pending and rejected entries do not count. A Verified status must come from the server.',
          Icons.privacy_tip_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Uploading…' : 'Submit for review'),
        ),
      ],
    ),
  );
}

class SubmissionStatusPage extends StatefulWidget {
  const SubmissionStatusPage({
    super.key,
    this.submissionId,
    this.initialStatus = 'pending',
  });
  final String? submissionId;
  final String initialStatus;
  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> {
  late String _status;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  Future<void> _appeal() async {
    if (widget.submissionId == null || !LoveBackend.configured) {
      notice(context, 'A real appeal needs a connected backend.');
      return;
    }
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request a review'),
        content: TextField(
          controller: reason,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us why you would like this reviewed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (approved != true || reason.text.trim().isEmpty) {
      reason.dispose();
      return;
    }
    try {
      await LoveBackend.appealChallengeSubmission(
        submissionId: widget.submissionId!,
        reason: reason.text,
      );
      if (mounted) notice(context, 'Your review request was sent.');
    } catch (_) {
      if (mounted) notice(context, 'Could not send the appeal. Try again.');
    } finally {
      reason.dispose();
    }
  }

  Future<void> _refresh() async {
    if (widget.submissionId == null || !LoveBackend.configured) return;
    setState(() => _loading = true);
    try {
      final value = await LoveBackend.challengeSubmissionStatus(
        widget.submissionId!,
      );
      if (mounted) setState(() => _status = value);
    } catch (_) {
      if (mounted) notice(context, 'Could not refresh review status.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'rejected';
    final verified = _status == 'verified';
    final uploadFailed = _status == 'upload_failed';
    return FlowPage(
      title: 'Submission status',
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateCard(
            title: 'Day submission',
            value: _loading
                ? 'Checking…'
                : uploadFailed
                ? 'UPLOAD NEEDS RETRY'
                : _status.toUpperCase(),
            body: verified
                ? 'The backend verified this day. It counts toward the challenge.'
                : rejected
                ? 'This day does not count. Review feedback, resubmit, or appeal.'
                : uploadFailed
                ? 'The upload failed. Nothing was submitted and the day is not counted. Retry the upload.'
                : 'A pending day does not count until the server verifies it.',
            color: uploadFailed
                ? LoveColors.red
                : verified
                ? LoveColors.green
                : rejected
                ? LoveColors.red
                : LoveColors.amber,
            icon: verified
                ? Icons.verified_outlined
                : rejected
                ? Icons.refresh
                : Icons.hourglass_top,
          ),
          const SizedBox(height: 14),
          if (rejected)
            OutlinedButton(
              onPressed: _appeal,
              child: const Text('Request review'),
            ),
          if (widget.submissionId != null)
            OutlinedButton(
              onPressed: _refresh,
              child: const Text('Refresh review status'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to activity'),
          ),
          const SizedBox(height: 8),
          const NoticeBox(
            'Only a server-confirmed Verified result adds one day to progress.',
            Icons.verified_outlined,
          ),
        ],
      ),
    );
  }
}

class DiscoveryGatePage extends StatefulWidget {
  const DiscoveryGatePage({super.key});
  @override
  State<DiscoveryGatePage> createState() => _DiscoveryGatePageState();
}

class _DiscoveryGatePageState extends State<DiscoveryGatePage> {
  bool _loading = false;
  bool? _eligible;
  List<Map<String, dynamic>> _candidates = [];
  int _current = 0;
  Future<void> _check() async {
    if (LoveDemo.enabled) {
      final days = await LoveDemo.verifiedDays();
      if (mounted)
        setState(() {
          _eligible = days >= 21;
          _candidates = days >= 21
              ? List.generate(10, (i) {
                  final female = i % 2 == 0;
                  return {
                    'candidate_id': 'demo_${i + 1}',
                    'age': 22 + i % 8,
                    'gender': female ? 'Woman' : 'Man',
                    'short_bio': [
                      'Loves weekend hikes and quiet coffee shops.',
                      'Finding joy in music, books, and new recipes.',
                      'Fitness, films, and meaningful conversations.',
                    ][i % 3],
                    'interests': [
                      ['Hiking', 'Coffee', 'Travel'],
                      ['Music', 'Reading', 'Cooking'],
                      ['Fitness', 'Movies', 'Art'],
                    ][i % 3],
                  };
                })
              : <Map<String, dynamic>>[];
          _current = 0;
        });
      return;
    }
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      setState(() => _eligible = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await LoveBackend.canDiscover();
      final candidates = result
          ? await LoveBackend.discoveryCandidates()
          : <Map<String, dynamic>>[];
      if (mounted)
        setState(() {
          _eligible = result;
          _candidates = candidates;
          _current = 0;
        });
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Eligibility could not be checked. Discovery stays locked until the server responds.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _interestComment() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a kind note?'),
        content: TextField(
          controller: controller,
          maxLength: 240,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional comment on their prompt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send interest'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _act(String action) async {
    if (_current >= _candidates.length) return;
    final profile = _candidates[_current];
    final id = profile['candidate_id'].toString();
    if (LoveDemo.enabled) {
      if (action == 'interested' && _current % 3 == 0) {
        if (mounted)
          go(context, const MatchCreatedPage(connectionId: 'demo_connection'));
        return;
      }
      if (mounted) setState(() => _current++);
      if (mounted)
        notice(
          context,
          action == 'interested'
              ? 'Demo: interest sent; some profiles may become mutual connections.'
              : action == 'view_later'
              ? 'Saved to View Later.'
              : 'Passed.',
        );
      return;
    }
    setState(() => _loading = true);
    try {
      if (action == 'report_user') {
        go(context, ReportUserPage(userId: id));
        return;
      } else if (action == 'block_user') {
        await LoveBackend.blockUser(id);
        if (mounted) notice(context, 'This profile is blocked.');
      } else if (action == 'interested') {
        final comment = await _interestComment();
        if (comment == null) return;
        final connectionId = await LoveBackend.submitInterest(
          otherUserId: id,
          promptComment: comment.isEmpty ? null : comment,
        );
        if (!mounted) return;
        if (connectionId != null) {
          go(context, MatchCreatedPage(connectionId: connectionId));
          return;
        }
        notice(
          context,
          'Interest sent. A connection appears only after mutual interest is confirmed.',
        );
      } else {
        await LoveBackend.recordDiscoveryAction(
          otherUserId: id,
          action: action,
        );
      }
      if (mounted) setState(() => _current++);
    } catch (_) {
      if (mounted)
        notice(context, 'That action could not be saved. Retry when online.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LoveColors.canvas,
      builder: (_) => CandidateDetailsSheet(profile: profile),
    );
    if (action != null) await _act(action);
  }

  @override
  Widget build(BuildContext context) {
    final open = _eligible == true;
    return FlowPage(
      title: 'Discovery access',
      actions: [IconButton(onPressed: _check, icon: const Icon(Icons.refresh))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateCard(
            title: LoveDemo.enabled ? 'Demo eligibility' : 'Server eligibility',
            value: _loading
                ? 'Checking…'
                : open
                ? (LoveDemo.enabled ? 'Unlocked' : 'Eligible')
                : 'Locked',
            body: open
                ? (LoveDemo.enabled
                      ? '21 verified demo days reached. Ten sample profiles are ready.'
                      : 'Backend confirmed age, identity, account status, and 21 verified days.')
                : (LoveDemo.enabled
                      ? 'Complete 21 verified demo days to unlock sample profiles.'
                      : 'Discovery stays locked until the backend confirms every eligibility check.'),
            color: open ? LoveColors.green : LoveColors.amber,
            icon: open ? Icons.lock_open_outlined : Icons.lock_outline,
          ),
          const SizedBox(height: 12),
          if (LoveDemo.enabled)
            const NoticeBox(
              'DEMO MODE • Profiles and eligibility are simulated locally. Profile gender is filtered to the opposite gender.',
              Icons.cloud_off_outlined,
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _check,
            child: Text(_loading ? 'Checking…' : 'Check again'),
          ),
          if (open)
            if (_current < _candidates.length)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: AnonymousProfileCard(
                  profile: _candidates[_current],
                  loading: _loading,
                  onDetails: () => _openDetails(_candidates[_current]),
                  onAction: _act,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No more eligible profiles are available right now. Check again later.',
                ),
              ),
        ],
      ),
    );
  }
}

class AnonymousProfileCard extends StatelessWidget {
  const AnonymousProfileCard({
    super.key,
    required this.profile,
    required this.loading,
    required this.onDetails,
    required this.onAction,
  });
  final Map<String, dynamic> profile;
  final bool loading;
  final VoidCallback onDetails;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final interests = (profile['interests'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    return Card(
      color: LoveColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: LoveColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: LoveColors.blush,
              child: Icon(
                Icons.person_outline,
                color: LoveColors.wine,
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Anonymous • ' +
                  profile['age'].toString() +
                  ' • ' +
                  profile['gender'].toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: LoveColors.onyx,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (profile['short_bio'] as String?)?.isNotEmpty == true
                  ? profile['short_bio'] as String
                  : 'A Love 21 member who enjoys building a steady daily rhythm.',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                for (final interest in interests) Chip(label: Text(interest)),
              ],
            ),
            TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.expand_circle_down_outlined),
              label: const Text('View details'),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: loading ? null : () => onAction('interested'),
              icon: const Icon(Icons.favorite_border),
              label: const Text('Interested'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: loading ? null : () => onAction('view_later'),
              child: const Text('View Later'),
            ),
            TextButton(
              onPressed: loading ? null : () => onAction('not_for_me'),
              child: const Text('Not for Me'),
            ),
          ],
        ),
      ),
    );
  }
}

class CandidateDetailsSheet extends StatelessWidget {
  const CandidateDetailsSheet({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final interests = (profile['interests'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_outline, size: 52, color: LoveColors.wine),
            const SizedBox(height: 12),
            Text(
              'Anonymous • ' +
                  profile['age'].toString() +
                  ' • ' +
                  profile['gender'].toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              (profile['short_bio'] as String?)?.isNotEmpty == true
                  ? profile['short_bio'] as String
                  : 'This member has not added a description yet.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              children: [
                for (final interest in interests) Chip(label: Text(interest)),
              ],
            ),
            const SizedBox(height: 12),
            const NoticeBox(
              'Profile photo stays hidden during anonymous connection.',
              Icons.visibility_off_outlined,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'interested'),
              child: const Text('Interested'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'view_later'),
              child: const Text('View Later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'not_for_me'),
              child: const Text('Not for Me'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'block_user'),
              child: const Text('Block this profile'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'report_user'),
              child: const Text('Report this profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchCreatedPage extends StatelessWidget {
  const MatchCreatedPage({super.key, required this.connectionId});
  final String connectionId;
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'A connection is mutual',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.favorite, size: 58, color: LoveColors.coral),
        const SizedBox(height: 18),
        Text(
          'You both said yes.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'The backend confirmed mutual interest and eligibility. Your connection starts anonymously. The 14-day photo timer starts from mutual acceptance.',
        ),
        const SizedBox(height: 16),
        const NoticeBox(
          'Chat is text-only. Only the profile photo may be revealed after 14 days and separate consent from both people.',
          Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => go(context, ChatPage(connectionId: connectionId)),
          child: const Text('Open anonymous chat'),
        ),
      ],
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _pages = const [
    ChallengeDashboardPage(),
    DiscoveryGatePage(),
    ConnectionsPage(),
    SettingsPage(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (!LoveBackend.configured) const DemoStrip(),
          Expanded(child: _pages[_index]),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (v) => setState(() => _index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          label: 'Challenge',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          label: 'Connections',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});
  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<Map<String, dynamic>> _connections = [];
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!LoveBackend.configured || LoveBackend.client.auth.currentUser == null)
      return;
    setState(() => _loading = true);
    try {
      final result = await LoveBackend.myConnections();
      if (mounted) setState(() => _connections = result);
    } catch (_) {
      if (mounted)
        notice(context, 'Could not load connections. Retry when online.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unmatch(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unmatch this connection?'),
        content: const Text('Chat access will close for both people.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await LoveBackend.unmatch(id);
      if (mounted) {
        notice(context, 'Connection ended.');
        await _load();
      }
    } catch (_) {
      if (mounted) notice(context, 'Could not unmatch. Retry when online.');
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Anonymous connections',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoticeBox(
          'No left/right swipes. Use Interested, Not for Me, or View Later. A match needs backend-confirmed mutual interest.',
          Icons.visibility_off_outlined,
        ),
        const SizedBox(height: 14),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_connections.isEmpty)
          const StateCard(
            title: 'Connections',
            value: 'No connections yet',
            body: 'Names and photos stay hidden. A connection appears after mutual interest is confirmed by the backend.',
            color: LoveColors.amber,
            icon: Icons.people_outline,
          ),
        for (var i = 0; i < _connections.length; i++)
          Column(
            children: [
              SettingItem(
                Icons.forum_outlined,
                'Anonymous connection ' + (i + 1).toString(),
                'Text-only chat • Photo reveal after 14 days with mutual consent',
                () => go(
                  context,
                  ChatPage(connectionId: _connections[i]['id'].toString()),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _unmatch(_connections[i]['id'].toString()),
                  child: const Text('Unmatch'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => go(context, const ChatPage()),
          child: const Text('Preview chat screen'),
        ),
        OutlinedButton(
          onPressed: () => go(context, const RevealPage()),
          child: const Text('Preview photo reveal consent'),
        ),
      ],
    ),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.connectionId});
  final String? connectionId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _message = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.connectionId == null || !LoveBackend.configured) return;
    try {
      final rows = await LoveBackend.connectionMessages(widget.connectionId!);
      if (mounted) setState(() => _messages = rows);
    } catch (_) {
      if (mounted) notice(context, 'Could not load messages.');
    }
  }

  Future<void> _send() async {
    if (widget.connectionId == null || _message.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await LoveBackend.sendTextMessage(
        connectionId: widget.connectionId!,
        text: _message.text,
      );
      _message.clear();
      await _load();
    } catch (_) {
      if (mounted) notice(context, 'Message was not sent. Retry when online.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Anonymous chat',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StateCard(
          title: 'Connection',
          value: 'Anonymous',
          body: 'Text-only chat. The 14-day timer starts when both people accept.',
          color: LoveColors.amber,
          icon: Icons.chat_bubble_outline,
        ),
        const SizedBox(height: 12),
        if (widget.connectionId == null)
          const NoticeBox(
            'Preview only. Messages are available after a backend-confirmed match.',
            Icons.visibility_outlined,
          ),
        SizedBox(
          height: 260,
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Start with a kind question.',
                    style: TextStyle(color: LoveColors.taupe),
                  ),
                )
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LoveColors.blush,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_messages[index]['body'].toString()),
                    ),
                  ),
                ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _message,
                enabled: widget.connectionId != null,
                maxLength: 2000,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'Write a message',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        const NoticeBox(
          'No images or attachments are allowed in anonymous chat.',
          Icons.lock_outline,
        ),
      ],
    ),
  );
}

class RevealPage extends StatelessWidget {
  const RevealPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Photo reveal',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A little more, when you’re both ready.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'After 14 calendar days from mutual acceptance, each person can separately consent to reveal only their profile photo. No other hidden details are revealed.',
        ),
        const SizedBox(height: 16),
        const StateCard(
          title: 'Reveal status',
          value: 'Not available',
          body: 'The server controls the timer and confirms both consents.',
          color: LoveColors.amber,
          icon: Icons.lock_clock_outlined,
        ),
        const SizedBox(height: 12),
        const CheckboxListTile(
          value: false,
          onChanged: null,
          title: Text('I consent to reveal my profile photo'),
          subtitle: Text('Consent is recorded separately.'),
        ),
        const FilledButton(
          onPressed: null,
          child: Text('Backend setup required'),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Settings & safety',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your account, your boundaries.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        SettingItem(
          Icons.notifications_outlined,
          'Notifications',
          'Reminders and updates',
          () => go(context, const BasicSettingPage(title: 'Notifications')),
        ),
        SettingItem(
          Icons.shield_outlined,
          'Privacy',
          'Profile and photo visibility',
          () => go(context, const BasicSettingPage(title: 'Privacy')),
        ),
        SettingItem(
          Icons.block_outlined,
          'Block or report',
          'Get help with a safety concern',
          () => go(context, const SafetyPage()),
        ),
        SettingItem(
          Icons.favorite_border,
          'Unmatch',
          'Remove a connection at any time',
          () => go(context, const ConnectionsPage()),
        ),
        SettingItem(
          Icons.delete_outline,
          'Delete account',
          'Request account and data deletion',
          () => go(context, const DeleteAccountPage()),
        ),
        const SizedBox(height: 12),
        const NoticeBox(
          'Settings are previews until connected to the backend.',
          Icons.info_outline,
        ),
      ],
    ),
  );
}

class BasicSettingPage extends StatefulWidget {
  const BasicSettingPage({super.key, required this.title});
  final String title;
  @override
  State<BasicSettingPage> createState() => _BasicSettingPageState();
}

class _BasicSettingPageState extends State<BasicSettingPage> {
  bool _notifications = true;
  bool _visible = true;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!LoveBackend.configured || LoveBackend.client.auth.currentUser == null)
      return;
    setState(() => _loading = true);
    try {
      final values = await LoveBackend.mySettings();
      if (mounted)
        setState(() {
          _notifications = values['notifications_enabled'] == true;
          _visible = values['profile_visible'] == true;
        });
    } catch (_) {
      if (mounted)
        notice(context, 'Could not load settings. Retry when online.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool? notifications, bool? visible}) async {
    final nextNotifications = notifications ?? _notifications;
    final nextVisible = visible ?? _visible;
    setState(() {
      _notifications = nextNotifications;
      _visible = nextVisible;
    });
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      notice(context, 'Preview only. This change was not saved.');
      return;
    }
    try {
      await LoveBackend.updateSettings(
        notificationsEnabled: nextNotifications,
        profileVisible: nextVisible,
      );
      if (mounted) notice(context, 'Setting saved.');
    } catch (_) {
      if (mounted)
        notice(context, 'Could not save setting. Retry when online.');
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: widget.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading) const LinearProgressIndicator(),
        SwitchListTile(
          value: _notifications,
          onChanged: (value) => _save(notifications: value),
          title: const Text('Notifications'),
          subtitle: const Text('Challenge reminders and connection updates'),
        ),
        SwitchListTile(
          value: _visible,
          onChanged: (value) => _save(visible: value),
          title: const Text('Profile discoverable'),
          subtitle: const Text(
            'Allow eligible members to see your anonymous profile',
          ),
        ),
        const NoticeBox(
          'Challenge photos remain private. These settings do not change challenge-photo access.',
          Icons.lock_outline,
        ),
      ],
    ),
  );
}

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Safety',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a profile to block or report it. You can unmatch from Connections.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => go(context, const DiscoveryGatePage()),
          child: const Text('Open discovery'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => go(context, const ConnectionsPage()),
          child: const Text('Open connections'),
        ),
      ],
    ),
  );
}

class ReportUserPage extends StatefulWidget {
  const ReportUserPage({super.key, required this.userId});
  final String userId;
  @override
  State<ReportUserPage> createState() => _ReportUserPageState();
}

class _ReportUserPageState extends State<ReportUserPage> {
  final _details = TextEditingController();
  String _category = 'Inappropriate behavior';
  bool _sending = false;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!LoveBackend.configured) {
      await showDemoNotice(context);
      return;
    }
    setState(() => _sending = true);
    try {
      await LoveBackend.reportUser(
        userId: widget.userId,
        category: _category,
        details: _details.text,
      );
      if (mounted) {
        notice(context, 'Report sent to the safety team.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        notice(context, 'Could not send the report. Retry when online.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Report profile',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tell us what happened.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          items: const [
            DropdownMenuItem(
              value: 'Inappropriate behavior',
              child: Text('Inappropriate behavior'),
            ),
            DropdownMenuItem(value: 'Harassment', child: Text('Harassment')),
            DropdownMenuItem(
              value: 'Fake profile',
              child: Text('Fake profile'),
            ),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _details,
          maxLength: 2000,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Details (optional)'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send report'),
        ),
      ],
    ),
  );
}

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Delete account',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your data deserves a clear exit.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Deletion must be confirmed and processed by the backend. Some records may be retained when required for safety or law.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            if (!LoveBackend.configured ||
                LoveBackend.client.auth.currentUser == null) {
              await showDemoNotice(context);
              return;
            }
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Request account deletion?'),
                content: const Text(
                  'This starts a backend deletion request. Some records may be retained for legal or safety reasons.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Request deletion'),
                  ),
                ],
              ),
            );
            if (confirm != true) return;
            try {
              await LoveBackend.requestAccountDeletion();
              if (context.mounted)
                notice(context, 'Deletion request received.');
            } catch (_) {
              if (context.mounted)
                notice(
                  context,
                  'Could not submit the request. Retry when online.',
                );
            }
          },
          style: FilledButton.styleFrom(backgroundColor: LoveColors.red),
          child: const Text('Request account deletion'),
        ),
      ],
    ),
  );
}

class FlowPage extends StatelessWidget {
  const FlowPage({
    super.key,
    required this.child,
    this.title,
    this.showBack = true,
    this.actions = const [],
  });
  final Widget child;
  final String? title;
  final bool showBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LoveColors.canvas,
    appBar: AppBar(
      leading: showBack && Navigator.of(context).canPop()
          ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            )
          : null,
      title: title == null
          ? null
          : Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
      actions: actions,
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [if (!LoveBackend.configured) const DemoStrip(), child],
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: LoveColors.wine,
        child: Text(
          'L',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            fontSize: 22,
          ),
        ),
      ),
      SizedBox(width: 9),
      Text(
        'Love 21',
        style: TextStyle(
          color: LoveColors.wine,
          fontFamily: 'serif',
          fontWeight: FontWeight.w700,
          fontSize: 21,
        ),
      ),
    ],
  );
}

class DemoStrip extends StatelessWidget {
  const DemoStrip({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: NoticeBox(
      'DEMO • Backend not connected; actions are not saved or verified.',
      Icons.visibility_outlined,
    ),
  );
}

class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, this.icon, {super.key});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: LoveColors.blush,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: LoveColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: LoveColors.wine),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: LoveColors.charcoal,
            ),
          ),
        ),
      ],
    ),
  );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE4E6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: LoveColors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: LoveColors.red, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.title,
    required this.value,
    required this.body,
    required this.color,
    required this.icon,
  });
  final String title, value, body;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: LoveColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: LoveColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: LoveColors.taupe,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: LoveColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RuleLine extends StatelessWidget {
  const RuleLine(this.icon, this.title, this.body, {super.key});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: LoveColors.wine),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(color: LoveColors.charcoal, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SettingItem extends StatelessWidget {
  const SettingItem(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    super.key,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: LoveColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: LoveColors.border),
    ),
    child: ListTile(
      leading: Icon(icon, color: LoveColors.wine),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;
void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
Future<void> showDemoNotice(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Demo mode'),
    content: const Text(
      'This preview does not create accounts or save progress. Connect Supabase and an authorized identity provider before using real data.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);
