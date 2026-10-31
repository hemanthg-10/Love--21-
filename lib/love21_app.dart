import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_services.dart';
import 'app_theme.dart';

const int minimumAge = 18;

DateTime latestEligibleBirthDate([DateTime? todayOverride]) {
  final today = todayOverride ?? DateTime.now();
  final year = today.year - minimumAge;
  final lastDay = DateTime(year, today.month + 1, 0).day;
  return DateTime(year, today.month, today.day.clamp(1, lastDay).toInt());
}

bool isAtLeastMinimumAge(DateTime birthDate, [DateTime? todayOverride]) {
  final latest = latestEligibleBirthDate(todayOverride);
  final date = DateTime(birthDate.year, birthDate.month, birthDate.day);
  return !date.isAfter(latest);
}

String? oppositeGenderPreference(String? registeredGender) =>
    switch (registeredGender) {
      'Man' => 'Women',
      'Woman' => 'Men',
      _ => null,
    };

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
    sketchAlignment: const Alignment(0.7, -0.8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        const BrandMark(),
        const SizedBox(height: 20),
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
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/love21_couple_banner.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.32),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        LoveColors.wine.withValues(alpha: .04),
                        LoveColors.wine.withValues(alpha: .76),
                      ],
                      stops: const [0.28, 1],
                    ),
                  ),
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
        const SizedBox(height: 18),
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
  final _confirmPassword = TextEditingController();
  final _phone = TextEditingController();
  String _countryCode = '+91';
  DateTime? _birthDate;
  String? _gender;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final latest = latestEligibleBirthDate(now);
    final date = await showDatePicker(
      context: context,
      initialDate: latest,
      firstDate: DateTime(1900),
      lastDate: latest,
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
    if (!isAtLeastMinimumAge(_birthDate!)) {
      notice(
        context,
        'You must be at least 18 years old to create an account.',
      );
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
        await LoveDemo.setRegisteredGender(_gender!);
        await showDemoNotice(context);
      }
      if (!mounted) return;
      go(
        context,
        ContactVerificationPage(
          email: _email.text.trim(),
          name: _name.text.trim(),
          phone: '$_countryCode${_phone.text.replaceAll(RegExp(r'\D'), '')}',
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
    sketchAlignment: const Alignment(0.7, -0.15),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Confirm your password'
                    : v != _password.text
                    ? 'Passwords do not match. Please try again.'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 112,
              child: DropdownButtonFormField<String>(
                value: _countryCode,
                decoration: const InputDecoration(labelText: 'Code'),
                items: const [
                  DropdownMenuItem(value: '+91', child: Text('+91')),
                  DropdownMenuItem(value: '+1', child: Text('+1')),
                  DropdownMenuItem(value: '+44', child: Text('+44')),
                  DropdownMenuItem(value: '+61', child: Text('+61')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _countryCode = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: (v) =>
                    (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7)
                    ? 'Enter a valid mobile number'
                    : null,
              ),
            ),
          ],
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
          'You must be at least 18 to create an account. Your age is checked by the server.',
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
    sketchAlignment: const Alignment(0.7, 0.35),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 142,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/love21_login_couple.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.28),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        LoveColors.wine.withValues(alpha: .35),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Pick up where you left off.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
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

class ContactVerificationPage extends StatefulWidget {
  const ContactVerificationPage({
    super.key,
    required this.email,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.phone,
  });
  final String email, name, gender;
  final String phone;
  final DateTime birthDate;
  @override
  State<ContactVerificationPage> createState() =>
      _ContactVerificationPageState();
}

class _ContactVerificationPageState extends State<ContactVerificationPage> {
  final _emailCode = TextEditingController();
  final _phoneCode = TextEditingController();
  bool _emailVerified = false;
  bool _phoneVerified = false;
  @override
  void dispose() {
    _emailCode.dispose();
    _phoneCode.dispose();
    super.dispose();
  }

  void _verify(TextEditingController code, bool email) {
    if (!LoveDemo.enabled) {
      notice(
        context,
        'OTP delivery requires configured email and SMS providers.',
      );
      return;
    }
    if (code.text.trim() != '123456') {
      notice(context, 'Demo OTP is 123456.');
      return;
    }
    setState(() {
      if (email) {
        _emailVerified = true;
      } else {
        _phoneVerified = true;
      }
    });
    notice(context, '${email ? 'Email' : 'Mobile'} demo OTP verified.');
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Verify your contacts',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoticeBox(
          'Demo OTP mode • Codes are simulated locally and are not sent.',
          Icons.science_outlined,
        ),
        const SizedBox(height: 14),
        Text('Email OTP', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Enter the 6-digit code for ${widget.email}.'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Email verification code',
            counterText: '',
          ),
        ),
        OutlinedButton(
          onPressed: () => _verify(_emailCode, true),
          child: Text(_emailVerified ? 'Email verified' : 'Verify email OTP'),
        ),
        const SizedBox(height: 24),
        Text('Mobile OTP', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Enter the 6-digit code for ${widget.phone}.'),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Mobile verification code',
            counterText: '',
          ),
        ),
        OutlinedButton(
          onPressed: () => _verify(_phoneCode, false),
          child: Text(_phoneVerified ? 'Mobile verified' : 'Verify mobile OTP'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _emailVerified && _phoneVerified
              ? () => go(
                  context,
                  HobbiesPage(
                    name: widget.name,
                    registeredGender: widget.gender,
                  ),
                )
              : null,
          child: const Text('Continue'),
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
  const HobbiesPage({
    super.key,
    required this.name,
    required this.registeredGender,
  });
  final String name;
  final String registeredGender;
  @override
  State<HobbiesPage> createState() => _HobbiesPageState();
}

class _HobbiesPageState extends State<HobbiesPage> {
  final _selected = <String>{};
  final _groups = const {
    'Daily Hobbies': [
      'Cooking',
      'Baking',
      'Gardening',
      'Photography',
      'Reading',
      'Writing',
      'Journaling',
      'DIY Projects',
      'Pet Care',
      'Home Decorating',
    ],
    'Gaming & Technology': [
      'Video Gaming',
      'Mobile Gaming',
      'PC Gaming',
      'Console Gaming',
      'Esports',
      'Online Multiplayer Games',
      'Board Games',
      'Puzzles',
      'Coding',
      'Technology',
      'Robotics',
    ],
    'Sports & Movement': [
      'Walking',
      'Running',
      'Gym',
      'Fitness',
      'Yoga',
      'Football',
      'Cricket',
      'Badminton',
      'Basketball',
      'Volleyball',
      'Swimming',
      'Cycling',
      'Hiking',
      'Trekking',
    ],
    'Creative Activities': [
      'Drawing',
      'Painting',
      'Music',
      'Singing',
      'Playing Instruments',
      'Dancing',
      'Crafting',
      'Fashion',
      'Content Creation',
      'Videography',
    ],
    'Culture & Entertainment': [
      'Books',
      'Cinema',
      'TV Series',
      'Anime',
      'Travel',
      'Podcasts',
      'Theatre',
      'Museums',
      'Live Events',
    ],
    'Food & Outdoors': [
      'Food Exploring',
      'Café Hopping',
      'Restaurant Exploring',
      'Camping',
      'Nature Walks',
      'Adventure Activities',
      'Volunteering',
      'Exploring New Places',
    ],
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
                  selectedColor: LoveColors.wine,
                  labelStyle: TextStyle(
                    color: _selected.contains(item)
                        ? Colors.white
                        : LoveColors.charcoal,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (v) => setState(
                    () => v ? _selected.add(item) : _selected.remove(item),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const NoticeBox(
          'Interests help with hobby-based discovery. Challenge photos are private.',
          Icons.favorite_border,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => go(
                  context,
                  ProfilePreviewPage(
                    name: widget.name,
                    registeredGender: widget.registeredGender,
                  ),
                ),
          child: const Text('Preview your profile'),
        ),
      ],
    ),
  );
}

class ProfilePreviewPage extends StatefulWidget {
  const ProfilePreviewPage({
    super.key,
    required this.name,
    required this.registeredGender,
  });
  final String name;
  final String registeredGender;
  @override
  State<ProfilePreviewPage> createState() => _ProfilePreviewPageState();
}

class _ProfilePreviewPageState extends State<ProfilePreviewPage> {
  final _bio = TextEditingController();
  Uint8List? _profilePhoto;
  String? get _preference => oppositeGenderPreference(widget.registeredGender);
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
    bottomAction: FilledButton(
      onPressed: _preference == null
          ? null
          : () => go(context, const IdentityPage()),
      child: const Text('Continue to identity check'),
    ),
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
              radius: 58,
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
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Discovery preference'),
          child: Row(
            children: [
              const Icon(Icons.favorite_border, color: LoveColors.wine),
              const SizedBox(width: 10),
              Text(
                _preference == null
                    ? 'Preference unavailable'
                    : 'Interested in $_preference',
                style: TextStyle(
                  color: _preference == null
                      ? LoveColors.red
                      : LoveColors.charcoal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const NoticeBox(
          'Challenge photos are stored separately and never appear here unless you choose a profile photo yourself.',
          Icons.lock_outline,
        ),
        const SizedBox(height: 20),
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
          'For your safety, identity documents are accepted only through a secure authorised verification provider. Do not upload them directly to Love 21.',
          Icons.privacy_tip_outlined,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: null,
          icon: Icon(Icons.upload_file_outlined),
          label: Text('Add Proof • Provider setup required'),
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
    love21VerifiedDays.addListener(_onVerifiedDaysChanged);
    _load();
  }

  void _onVerifiedDaysChanged() {
    if (!mounted) return;
    final value = love21VerifiedDays.value.clamp(0, 21).toInt();
    if (value != _verified) setState(() => _verified = value);
  }

  @override
  void dispose() {
    love21VerifiedDays.removeListener(_onVerifiedDaysChanged);
    super.dispose();
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
      love21VerifiedDays.value = value.clamp(0, 21).toInt();
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
        Row(
          children: [
            Expanded(
              child: Text(
                '$_verified of 21 days verified',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.local_fire_department, color: LoveColors.coral),
            const SizedBox(width: 4),
            Text(
              '$_verified day streak',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
        if (_error != null) ErrorBox(_error!),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.08,
          ),
          itemCount: 21,
          itemBuilder: (context, i) {
            final verified = i < _verified;
            final current = i == _verified && _verified < 21;
            final fill = verified
                ? LoveColors.wine
                : current
                ? LoveColors.blush
                : LoveColors.card;
            final stroke = verified
                ? LoveColors.wine
                : current
                ? LoveColors.rose
                : LoveColors.border;
            return CustomPaint(
              painter: DayHeartPainter(
                fill: fill,
                stroke: stroke,
                strokeWidth: current ? 2 : 1,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: verified
                          ? Colors.white
                          : current
                          ? LoveColors.wine
                          : LoveColors.taupe,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        if (_verified == 21)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'You showed up for yourself every day.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LoveColors.wine,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
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

class DayHeartPainter extends CustomPainter {
  const DayHeartPainter({
    required this.fill,
    required this.stroke,
    this.strokeWidth = 1,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .5, h * .93)
      ..cubicTo(w * .42, h * .84, w * .05, h * .55, w * .05, h * .34)
      ..cubicTo(w * .05, h * .08, w * .39, h * .04, w * .5, h * .29)
      ..cubicTo(w * .61, h * .04, w * .95, h * .08, w * .95, h * .34)
      ..cubicTo(w * .95, h * .55, w * .58, h * .84, w * .5, h * .93)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant DayHeartPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _ChallengeCompletionPageState extends State<ChallengeCompletionPage> {
  bool _eligible = false;
  bool _loading = false;
  Future<void> _check() async {
    final wasUnlocked = love21NavigationUnlocked.value;
    setState(() => _loading = true);
    if (LoveDemo.enabled) {
      final days = await LoveDemo.verifiedDays();
      final demoAccess = days >= 21;
      await LoveDemo.setDiscoveryEligible(demoAccess);
      if (!mounted) return;
      setState(() {
        _eligible = demoAccess;
        _loading = false;
      });
      if (demoAccess) {
        if (!wasUnlocked && mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Demo access enabled'),
              content: const Text(
                'Identity verification is still pending. Secure provider integration is required for production verification. You can continue exploring the local demo experience.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Continue to Discover'),
                ),
              ],
            ),
          );
        }
        if (mounted) go(context, const MainShell(initialIndex: 1));
      } else {
        notice(context, 'Complete the 21-day challenge to open the demo.');
      }
      return;
    }
    if (!LoveBackend.configured) {
      if (mounted) {
        setState(() {
          _eligible = false;
          _loading = false;
        });
        love21NavigationUnlocked.value = false;
        notice(
          context,
          'The server is not configured, so eligibility cannot be confirmed.',
        );
      }
      return;
    }
    try {
      final days = await LoveBackend.verifiedDayCount();
      love21VerifiedDays.value = days.clamp(0, 21).toInt();
      final result = await LoveBackend.canDiscover();
      love21NavigationUnlocked.value = result && days >= 21;
      if (mounted) setState(() => _eligible = result && days >= 21);
      if (result && days >= 21 && mounted) {
        if (!wasUnlocked) notice(context, 'Discovery Unlocked!');
        go(context, const MainShell(initialIndex: 1));
      }
    } catch (_) {
      if (mounted)
        notice(context, 'The backend could not confirm eligibility.');
    } finally {
      if (mounted && !_eligible) setState(() => _loading = false);
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
          title: LoveDemo.enabled ? 'Demo eligibility' : 'Discovery',
          value: _eligible
              ? (LoveDemo.enabled ? 'Demo unlocked' : 'Unlocked by server')
              : 'Still locked',
          body: _eligible
              ? (LoveDemo.enabled
                    ? 'The local challenge simulation is complete. Sample profiles are clearly marked as demo data.'
                    : 'Your account is eligible. Candidate profiles must come from the backend.')
              : LoveDemo.enabled
              ? 'Demo mode cannot verify identity. Discovery stays locked until a secure identity provider and backend are configured.'
              : 'Challenge completion alone does not unlock discovery until the backend confirms age, identity, and eligibility.',
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
  String? _quizAnswer;
  static const _quizOptions = ['Energised', 'Relaxed', 'Accomplished'];
  @override
  void initState() {
    super.initState();
    LoveDemo.quizAnswer(widget.day).then((v) {
      if (mounted) setState(() => _quizAnswer = v);
    });
  }

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
    if (_quizAnswer == null) {
      notice(context, 'Please select one answer to continue.');
      return;
    }
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
        const SizedBox(height: 12),
        Text(
          "Today's Quick Quiz",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text("How did today's activity make you feel?"),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final answer in _quizOptions)
              ChoiceChip(
                label: Text(answer),
                selected: _quizAnswer == answer,
                onSelected: (selected) async {
                  if (!selected) return;
                  setState(() => _quizAnswer = answer);
                  await LoveDemo.saveQuizAnswer(widget.day, answer);
                },
              ),
          ],
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
  bool _autoReturnScheduled = false;
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _scheduleAutoReturnIfVerified();
  }

  void _scheduleAutoReturnIfVerified() {
    if (_status != 'verified' || _autoReturnScheduled) return;
    _autoReturnScheduled = true;
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _returnToChallenge();
    });
  }

  Future<void> _returnToChallenge() async {
    if (widget.submissionId != null &&
        !LoveDemo.enabled &&
        LoveBackend.configured) {
      try {
        final days = await LoveBackend.verifiedDayCount();
        love21VerifiedDays.value = days.clamp(0, 21).toInt();
      } catch (_) {
        // The challenge screen will retry its normal progress refresh.
      }
    }
    if (!mounted) return;
    love21SelectedTab.value = 0;
    final navigator = Navigator.of(context);
    var foundMainShell = false;
    navigator.popUntil((route) {
      if (route.settings.name == 'MainShell') {
        foundMainShell = true;
        return true;
      }
      return route.isFirst;
    });
    if (foundMainShell) return;
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'MainShell'),
        builder: (_) => const MainShell(),
      ),
      (_) => false,
    );
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
      if (mounted) {
        setState(() => _status = value);
        _scheduleAutoReturnIfVerified();
      }
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
  const DiscoveryGatePage({super.key, this.previewOnly = false});
  final bool previewOnly;
  @override
  State<DiscoveryGatePage> createState() => _DiscoveryGatePageState();
}

class _DiscoveryGatePageState extends State<DiscoveryGatePage> {
  bool _loading = false;
  bool? _eligible;
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _savedCandidates = [];
  bool _showSaved = false;
  bool _loadingMore = false;
  @override
  void initState() {
    super.initState();
    if (widget.previewOnly) {
      _eligible = true;
      _candidates = _demoProfiles();
      return;
    }
    _check();
  }

  List<Map<String, dynamic>> _demoProfiles() => List.generate(
    10,
    (i) => {
      'candidate_id': 'demo_${i + 1}',
      'age': 22 + i % 8,
      'display_name': ['Maya', 'Anika', 'Riya', 'Tara', 'Nisha'][i % 5],
      'gender': 'Preview only',
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
    },
  );

  Future<void> _check() async {
    if (LoveDemo.enabled) {
      final days = await LoveDemo.verifiedDays();
      final navigationEligible = await LoveDemo.discoveryEligible();
      final registeredGender = await LoveDemo.registeredGender();
      final targetGender = switch (oppositeGenderPreference(registeredGender)) {
        'Women' => 'Woman',
        'Men' => 'Man',
        _ => null,
      };
      final eligible = days >= 21 && navigationEligible;
      love21NavigationUnlocked.value = eligible;
      if (mounted)
        setState(() {
          _eligible = eligible;
          _candidates = eligible
              ? List.generate(10, (i) {
                  return {
                    'candidate_id': 'demo_${i + 1}',
                    'age': 22 + i % 8,
                    'display_name': [
                      'Maya',
                      'Anika',
                      'Riya',
                      'Tara',
                      'Nisha',
                    ][i % 5],
                    'gender': targetGender ?? 'Preview only',
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
        });
      return;
    }
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      setState(() => _eligible = false);
      love21NavigationUnlocked.value = false;
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await LoveBackend.canDiscover();
      final candidates = result
          ? await LoveBackend.discoveryCandidates()
          : <Map<String, dynamic>>[];
      love21NavigationUnlocked.value = result;
      if (mounted)
        setState(() {
          _eligible = result;
          _candidates = candidates;
          _savedCandidates = [];
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

  Future<void> _act(Map<String, dynamic> profile, String action) async {
    final id = profile['candidate_id'].toString();
    if (LoveDemo.enabled) {
      if (action == 'interested') await LoveDemo.addInterestedProfile(profile);
      if (mounted)
        setState(() {
          _candidates.remove(profile);
          if (action == 'view_later')
            _savedCandidates.insert(0, profile);
          else
            _savedCandidates.removeWhere(
              (p) => p['candidate_id'].toString() == id,
            );
        });
      if (action == 'view_later' && mounted)
        notice(context, 'Saved for later.');
      if (action == 'interested' && mounted)
        notice(
          context,
          'Interest saved to Connections. It is a demo interest, not a confirmed match.',
        );
      return;
    }
    setState(() => _loading = true);
    try {
      if (action == 'interested') {
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
      } else if (action == 'view_later') {
        await LoveBackend.recordDiscoveryAction(
          otherUserId: id,
          action: action,
        );
      }
      if (mounted) {
        setState(() {
          _candidates.removeWhere(
            (candidate) => candidate['candidate_id'].toString() == id,
          );
          _savedCandidates.removeWhere(
            (candidate) => candidate['candidate_id'].toString() == id,
          );
        });
        if (action == 'view_later') notice(context, 'Saved for later.');
      }
    } catch (_) {
      if (mounted)
        notice(context, 'That action could not be saved. Retry when online.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSaved() async {
    setState(() {
      _showSaved = true;
      _loadingMore = true;
    });
    try {
      final saved = LoveDemo.enabled
          ? _savedCandidates
          : await LoveBackend.mySavedProfiles();
      if (mounted) setState(() => _savedCandidates = saved);
    } catch (_) {
      if (mounted) notice(context, 'Saved profiles could not be loaded.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMore() async {
    if (LoveDemo.enabled || _loadingMore || _showSaved) return;
    setState(() => _loadingMore = true);
    try {
      final next = await LoveBackend.discoveryCandidates(
        offset: _candidates.length,
      );
      if (mounted) setState(() => _candidates.addAll(next));
    } catch (_) {
      if (mounted) notice(context, 'More profiles could not be loaded.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LoveColors.canvas,
      builder: (_) => CandidateDetailsSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _eligible == true;
    return FlowPage(
      title: widget.previewOnly ? 'Discovery preview' : 'Discovery access',
      previewTabs: widget.previewOnly,
      actions: open
          ? const []
          : [IconButton(onPressed: _check, icon: const Icon(Icons.refresh))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.previewOnly)
            const NoticeBox(
              'Preview only • Identity is still pending. These sample profiles do not create matches or unlock real discovery.',
              Icons.visibility_outlined,
            ),
          if (!open)
            StateCard(
              title: LoveDemo.enabled
                  ? 'Demo eligibility'
                  : 'Server eligibility',
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
          if (!open) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _check,
              child: Text(_loading ? 'Checking…' : 'Check eligibility'),
            ),
          ],
          if (open)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showSaved
                    ? () => setState(() => _showSaved = false)
                    : _loadSaved,
                icon: Icon(
                  _showSaved ? Icons.explore_outlined : Icons.bookmark_outline,
                ),
                label: Text(
                  _showSaved ? 'Back to discovery' : 'Saved for later',
                ),
              ),
            ),
          if (open)
            if (_loadingMore && _showSaved && _savedCandidates.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_showSaved && _savedCandidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('Profiles you save will appear here.'),
              )
            else if (_showSaved)
              for (final profile in _savedCandidates)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: AnonymousProfileCard(
                    profile: profile,
                    loading: _loading,
                    onDetails: () => _openDetails(profile),
                    onAction: (action) => _act(profile, action),
                  ),
                ),
          if (open && !_showSaved)
            if (_candidates.isNotEmpty)
              for (final profile in _candidates)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: AnonymousProfileCard(
                    profile: profile,
                    loading: _loading,
                    onDetails: () => _openDetails(profile),
                    onAction: (action) => _act(profile, action),
                  ),
                )
            else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No more eligible profiles are available right now. Check again later.',
                ),
              ),
          if (open && !_showSaved && _candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading…' : 'Load more profiles'),
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
              (profile['display_name'] ?? 'Love 21 member').toString() +
                  ' • ' +
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
              (profile['display_name'] ?? 'Love 21 member').toString() +
                  ' • ' +
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
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  final _pages = const [
    ChallengeDashboardPage(),
    DiscoveryGatePage(),
    LikesPage(),
    ConnectionsPage(),
    SettingsPage(),
  ];
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4).toInt();
    love21SelectedTab.value = _index;
    love21NavigationUnlocked.addListener(_onEligibilityChanged);
    love21SelectedTab.addListener(_onTabChanged);
    if (LoveDemo.enabled) {
      LoveDemo.discoveryEligible().then((eligible) {
        if (mounted) love21NavigationUnlocked.value = eligible;
      });
    } else {
      love21NavigationUnlocked.value = false;
      if (LoveBackend.configured &&
          LoveBackend.client.auth.currentUser != null) {
        _loadServerEligibility();
      }
    }
  }

  Future<void> _loadServerEligibility() async {
    try {
      final days = await LoveBackend.verifiedDayCount();
      love21VerifiedDays.value = days.clamp(0, 21).toInt();
      final eligible = days >= 21 && await LoveBackend.canDiscover();
      if (mounted) {
        if (eligible && widget.initialIndex > 0) {
          setState(() => _index = widget.initialIndex.clamp(0, 3).toInt());
        }
        love21NavigationUnlocked.value = eligible;
      }
    } catch (_) {
      if (mounted) love21NavigationUnlocked.value = false;
    }
  }

  void _onEligibilityChanged() {
    if (!mounted) return;
    setState(() {
      if (!love21NavigationUnlocked.value) _index = 0;
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final next = love21SelectedTab.value.clamp(0, 4).toInt();
    if (next != _index) setState(() => _index = next);
  }

  Future<void> _selectTab(int index) async {
    if (index == 0) {
      love21SelectedTab.value = 0;
      setState(() => _index = 0);
      return;
    }
    final eligible = LoveDemo.enabled
        ? await LoveDemo.discoveryEligible()
        : await LoveBackend.canDiscover();
    if (!mounted) return;
    love21NavigationUnlocked.value = eligible;
    if (eligible) {
      love21SelectedTab.value = index;
      setState(() => _index = index);
    }
  }

  @override
  void dispose() {
    love21NavigationUnlocked.removeListener(_onEligibilityChanged);
    love21SelectedTab.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = love21NavigationUnlocked.value;
    return Scaffold(
      body: SafeArea(child: unlocked ? _pages[_index] : _pages.first),
      bottomNavigationBar: unlocked
          ? LoveBottomNavigation(selectedIndex: _index, onSelected: _selectTab)
          : null,
    );
  }
}

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});
  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  List<Map<String, dynamic>> _likes = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await LoveDemo.incomingLikes();
    if (mounted) setState(() => _likes = rows);
  }

  Future<void> _likeBack(Map<String, dynamic> profile) async {
    await LoveDemo.addInterestedProfile(profile);
    await LoveDemo.removeIncomingLike(profile['candidate_id'].toString());
    if (!mounted) return;
    await _load();
    notice(context, "It's a match! You both showed interest. (Demo)");
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'People who like you',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("See who's interested in getting to know you."),
        const SizedBox(height: 12),
        if (_likes.isEmpty)
          const StateCard(
            title: 'Likes',
            value: 'Your admirers will appear here.',
            body: 'Stay consistent, express yourself and let meaningful connections grow.',
            color: LoveColors.coral,
            icon: Icons.favorite_border,
          ),
        for (final p in _likes)
          Card(
            color: LoveColors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${p['display_name']} · ${p['age']} · ${p['gender']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(p['short_bio'].toString()),
                  Chip(
                    avatar: const Icon(Icons.favorite, color: LoveColors.wine),
                    label: const Text('Liked your profile'),
                  ),
                  Text(
                    '“${p['message']}”',
                    style: const TextStyle(
                      color: LoveColors.wine,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => CandidateDetailsSheet(profile: p),
                    ),
                    child: const Text('View Profile'),
                  ),
                  FilledButton(
                    onPressed: () => _likeBack(p),
                    child: const Text('Like Back'),
                  ),
                ],
              ),
            ),
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
    if (!love21NavigationUnlocked.value) return;
    if (LoveDemo.enabled) {
      final rows = await LoveDemo.interestedProfiles();
      if (mounted) setState(() => _connections = rows);
      return;
    }
    if (!LoveBackend.configured || LoveBackend.client.auth.currentUser == null)
      return;
    setState(() => _loading = true);
    try {
      if (!await LoveBackend.canDiscover()) {
        love21NavigationUnlocked.value = false;
        if (mounted) setState(() => _connections = []);
        return;
      }
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
    child: !love21NavigationUnlocked.value
        ? const LockedFeatureMessage()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeBox(
                'Connections appear after the backend confirms mutual interest. Your conversations stay anonymous.',
                Icons.visibility_off_outlined,
              ),
              const SizedBox(height: 14),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_connections.isEmpty)
                const StateCard(
                  title: 'Connections',
                  value: 'No connections yet',
                  body: 'When someone shares your interest, your anonymous conversation will be ready here.',
                  color: LoveColors.amber,
                  icon: Icons.people_outline,
                ),
              for (var i = 0; i < _connections.length; i++)
                Column(
                  children: [
                    Card(
                      color: LoveColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: LoveColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${_connections[i]['display_name'] ?? 'Love 21 member'} • ${_connections[i]['age']} • ${_connections[i]['gender']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_connections[i]['short_bio'] ?? '')
                                      .toString()
                                      .isEmpty
                                  ? 'A Love 21 member.'
                                  : _connections[i]['short_bio'].toString(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connected ${_connectionDate(_connections[i]['matched_at'])} • ${_revealCountdown(_connections[i]['matched_at'])}',
                              style: const TextStyle(
                                color: LoveColors.taupe,
                                fontSize: 12,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final tag
                                    in (_connections[i]['interests'] as List? ??
                                            const [])
                                        .take(4))
                                  Chip(label: Text(tag.toString())),
                              ],
                            ),
                            FilledButton.icon(
                              onPressed: () => go(
                                context,
                                ChatPage(
                                  connectionId: _connections[i]['id']
                                      .toString(),
                                ),
                              ),
                              icon: const Icon(Icons.forum_outlined),
                              label: const Text('Open Chat'),
                            ),
                            OutlinedButton(
                              onPressed: () => go(
                                context,
                                RevealPage(
                                  connectionId: _connections[i]['id']
                                      .toString(),
                                ),
                              ),
                              child: const Text('Photo Reveal Consent'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _unmatch(_connections[i]['id'].toString()),
                              child: const Text('Unmatch'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
            ],
          ),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.connectionId});
  final String connectionId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _busy = false;
  bool _loading = true;
  bool get _isLocalDemoConnection =>
      LoveDemo.enabled || widget.connectionId.startsWith('demo_');
  @override
  void initState() {
    super.initState();
    love21SelectedTab.value = 2;
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLocalDemoConnection) {
      final rows = await LoveDemo.demoMessages(widget.connectionId);
      if (mounted)
        setState(() {
          _messages = rows;
          _loading = false;
        });
      return;
    }
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await LoveBackend.connectionMessages(widget.connectionId);
      if (mounted) {
        setState(() {
          _messages = rows;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients)
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      if (mounted) notice(context, 'Could not load messages.');
    }
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_isLocalDemoConnection) {
        await LoveDemo.addDemoMessage(widget.connectionId, _message.text);
        _message.clear();
        await _load();
        return;
      }
      await LoveBackend.sendTextMessage(
        connectionId: widget.connectionId,
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
    expandBody: true,
    persistentTabs: true,
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateCard(
            title: 'Connection',
            value: 'Anonymous',
            body: 'Text-only conversation. Photo reveal eligibility: 14 days after mutual acceptance.',
            color: LoveColors.amber,
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start with a kind question.',
                      style: TextStyle(color: LoveColors.taupe),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final mine = _isLocalDemoConnection
                          ? _messages[index]['sender_id'] == 'demo_me'
                          : _messages[index]['sender_id'] ==
                                LoveBackend.client.auth.currentUser?.id;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .76,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? LoveColors.wine : LoveColors.blush,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _messages[index]['body'].toString(),
                            style: TextStyle(
                              color: mine ? Colors.white : LoveColors.onyx,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  enabled: !_busy,
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
          const Padding(
            padding: EdgeInsets.only(top: 5, bottom: 4),
            child: Text(
              'Private text-only chat • No images or attachments',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: LoveColors.taupe),
            ),
          ),
        ],
      ),
    ),
  );
}

class RevealPage extends StatefulWidget {
  const RevealPage({super.key, required this.connectionId});
  final String connectionId;
  @override
  State<RevealPage> createState() => _RevealPageState();
}

class _RevealPageState extends State<RevealPage> {
  Map<String, dynamic>? _status;
  String? _revealedPhotoUrl;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await LoveBackend.photoRevealStatus(widget.connectionId);
      final photoUrl = result['both_consented'] == true
          ? await LoveBackend.revealedPartnerPhotoUrl(widget.connectionId)
          : null;
      if (mounted)
        setState(() {
          _status = result;
          _revealedPhotoUrl = photoUrl;
        });
    } catch (_) {
      if (mounted)
        notice(context, 'Reveal status is unavailable from the server.');
    }
  }

  Future<void> _consent(bool value) async {
    setState(() => _busy = true);
    try {
      await LoveBackend.setPhotoRevealConsent(widget.connectionId, value);
      await _load();
      if (mounted)
        notice(
          context,
          value ? 'Your consent was recorded.' : 'Your consent was withdrawn.',
        );
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Consent is available only after the server confirms 14 days.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
        StateCard(
          title: 'Reveal status',
          value: _status?['eligible'] == true
              ? 'Consent available'
              : 'Waiting period',
          body: _status == null
              ? 'Checking with the server…'
              : (_status!['eligible'] == true
                    ? (_status!['both_consented'] == true
                          ? 'Both people consented. Photo delivery remains protected until the secure reveal service is configured.'
                          : (_status!['my_consented'] == true
                                ? 'Your consent is recorded. Waiting for the other person.'
                                : 'You have been connected for 14 days. Would you like to reveal your profile photo?'))
                    : 'The server is counting down from mutual acceptance. Photos remain hidden.'),
          color: LoveColors.amber,
          icon: Icons.lock_clock_outlined,
        ),
        const SizedBox(height: 12),
        if (_revealedPhotoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              _revealedPhotoUrl!,
              height: 280,
              fit: BoxFit.cover,
            ),
          ),
        if (_status?['eligible'] == true &&
            _status?['both_consented'] != true) ...[
          FilledButton(
            onPressed: _busy ? null : () => _consent(true),
            child: Text(_busy ? 'Saving…' : 'I consent to photo reveal'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _consent(false),
            child: const Text('Decline / withdraw consent'),
          ),
        ],
        const NoticeBox(
          'A photo is never shown from one person’s consent alone. Secure photo delivery must also be enabled by the service.',
          Icons.lock_outline,
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
    child: !love21NavigationUnlocked.value
        ? const LockedFeatureMessage()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your account, your boundaries.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              SettingItem(
                Icons.person_outline,
                'Profile',
                'Edit your profile information',
                () => go(context, const EditProfilePage()),
              ),
              SettingItem(
                Icons.notifications_outlined,
                'Notifications',
                'Reminders and updates',
                () =>
                    go(context, const BasicSettingPage(title: 'Notifications')),
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
            ],
          ),
  );
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedPhoto;
  String? _photoUrl;
  String? _photoPath;
  bool _loading = true;
  bool _saving = false;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await LoveBackend.myProfile();
      _name.text = (profile['full_name'] ?? '').toString();
      _bio.text = (profile['short_bio'] ?? '').toString();
      _photoPath = profile['profile_photo_path'] as String?;
      _photoUrl = await LoveBackend.myProfilePhotoUrl(_photoPath);
    } catch (_) {
      if (mounted) notice(context, 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file != null && mounted) setState(() => _selectedPhoto = file);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!LoveBackend.configured ||
        LoveBackend.client.auth.currentUser == null) {
      notice(context, 'Profile editing requires a signed-in backend account.');
      return;
    }
    setState(() => _saving = true);
    String? uploadedPath;
    try {
      if (_selectedPhoto != null)
        uploadedPath = await LoveBackend.uploadProfilePhoto(_selectedPhoto!);
      await LoveBackend.updateMyProfile(
        fullName: _name.text,
        shortBio: _bio.text,
        profilePhotoPath: uploadedPath,
      );
      if (uploadedPath != null && _photoPath != null) {
        try {
          await LoveBackend.removeMyProfilePhoto(_photoPath!);
        } catch (_) {
          /* Retain the previous private object if cleanup fails. */
        }
      }
      if (!mounted) return;
      notice(context, 'Profile updated.');
      Navigator.pop(context);
    } catch (_) {
      if (uploadedPath != null) {
        try {
          await LoveBackend.removeMyProfilePhoto(uploadedPath);
        } catch (_) {
          /* A private orphan can be removed by storage cleanup. */
        }
      }
      if (mounted)
        notice(context, 'Your profile could not be saved. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: 'Edit profile',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: LoveColors.blush,
                          child: _selectedPhoto != null
                              ? FutureBuilder<Uint8List>(
                                  future: _selectedPhoto!.readAsBytes(),
                                  builder: (context, snap) => snap.hasData
                                      ? ClipOval(
                                          child: Image.memory(
                                            snap.data!,
                                            width: 108,
                                            height: 108,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_outline,
                                          size: 42,
                                          color: LoveColors.wine,
                                        ),
                                )
                              : _photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    _photoUrl!,
                                    width: 108,
                                    height: 108,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_outline,
                                      size: 42,
                                      color: LoveColors.wine,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person_outline,
                                  size: 42,
                                  color: LoveColors.wine,
                                ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Change photo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bio,
                  maxLength: 180,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                  ),
                  validator: (v) => (v?.length ?? 0) > 180
                      ? 'Use 180 characters or fewer'
                      : null,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save Changes'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const NoticeBox(
                  'Your birth date, registered gender, verification and eligibility remain protected.',
                  Icons.lock_outline,
                ),
              ],
            ),
          ),
  );
}

class LockedFeatureMessage extends StatelessWidget {
  const LockedFeatureMessage({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 24),
    child: NoticeBox(
      'Complete all 21 verified challenge days to unlock this section.',
      Icons.lock_outline,
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
    child: !love21NavigationUnlocked.value
        ? const LockedFeatureMessage()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              SwitchListTile(
                value: _notifications,
                onChanged: (value) => _save(notifications: value),
                title: const Text('Notifications'),
                subtitle: const Text(
                  'Challenge reminders and connection updates',
                ),
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

class DemoPreviewSectionPage extends StatelessWidget {
  const DemoPreviewSectionPage({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    const titles = ['Challenge', 'Discover', 'Connections', 'Settings'];
    const descriptions = [
      'Your 21-day challenge preview.',
      'Browse sample profiles in Discovery preview.',
      'Real connections appear after backend-confirmed mutual interest.',
      'Preview account and safety settings.',
    ];
    return FlowPage(
      title: '${titles[index]} preview',
      previewTabs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoticeBox(
            'Preview mode • Age and identity eligibility are bypassed for screen previews only.',
            Icons.visibility_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            descriptions[index],
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (index == 2)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Your connections will appear here after a real mutual match.',
              ),
            ),
        ],
      ),
    );
  }
}

class LoveBottomNavigation extends StatelessWidget {
  const LoveBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.auto_stories_outlined),
        label: 'Challenge',
      ),
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        label: 'Discover',
      ),
      NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Likes'),
      NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        label: 'Connections',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Settings',
      ),
    ],
  );
}

class FlowPage extends StatelessWidget {
  const FlowPage({
    super.key,
    required this.child,
    this.title,
    this.showBack = true,
    this.actions = const [],
    this.sketchAlignment,
    this.bottomAction,
    this.expandBody = false,
    this.persistentTabs = false,
    this.previewTabs = false,
  });
  final Widget child;
  final String? title;
  final bool showBack;
  final List<Widget> actions;
  final Alignment? sketchAlignment;
  final Widget? bottomAction;
  final bool expandBody;
  final bool persistentTabs;
  final bool previewTabs;
  @override
  Widget build(BuildContext context) {
    final hasSketchBackground = true;
    final artworkAlignment = sketchAlignment ?? const Alignment(0, -0.1);
    return Scaffold(
      backgroundColor: LoveColors.canvas,
      extendBodyBehindAppBar: hasSketchBackground,
      appBar: AppBar(
        backgroundColor: hasSketchBackground
            ? Colors.transparent
            : LoveColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: actions,
      ),
      bottomNavigationBar: (persistentTabs || previewTabs)
          ? SafeArea(
              child: LoveBottomNavigation(
                selectedIndex: previewTabs ? 1 : love21SelectedTab.value,
                onSelected: (index) {
                  if (previewTabs) {
                    if (index != 1)
                      go(context, DemoPreviewSectionPage(index: index));
                    return;
                  }
                  love21SelectedTab.value = index;
                  final nav = Navigator.of(context);
                  if (nav.canPop())
                    nav.popUntil(
                      (route) =>
                          route.settings.name == 'MainShell' || route.isFirst,
                    );
                },
              ),
            )
          : bottomAction == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: bottomAction!,
            ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            if (hasSketchBackground)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.6,
                    child: ClipRect(
                      child: Transform.scale(
                        scale: 1.04,
                        alignment: artworkAlignment,
                        child: Image.asset(
                          'assets/images/love21_global_background_40_transparent.png',
                          fit: BoxFit.cover,
                          alignment: artworkAlignment,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (expandBody)
              Positioned.fill(child: child)
            else
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  hasSketchBackground
                      ? MediaQuery.paddingOf(context).top + kToolbarHeight + 10
                      : 10,
                  20,
                  30,
                ),
                children: [child],
              ),
          ],
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/love21_logo.png',
    width: 138,
    height: 108,
    fit: BoxFit.contain,
    semanticLabel: 'Love 21',
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
void go(BuildContext context, Widget page) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: RouteSettings(name: page.runtimeType.toString()),
    builder: (_) => page,
  ),
);
String _connectionDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Connected';
  final days = DateTime.now().difference(date).inDays;
  return days <= 0 ? 'today' : '$days days ago';
}

String _revealCountdown(dynamic value) {
  final matched = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  if (matched == null) return 'Reveal timer unavailable';
  final remaining = matched
      .add(const Duration(days: 14))
      .difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) return 'Photo reveal consent available';
  return 'Photo reveal in ${remaining.inDays}d ${remaining.inHours.remainder(24)}h';
}

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
