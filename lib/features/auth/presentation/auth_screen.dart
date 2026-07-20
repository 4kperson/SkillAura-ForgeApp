import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  var _isSignUp = false;
  var _isLoading = false;
  var _obscurePassword = true;
  var _submitted = false;
  String? _message;
  var _messageIsSuccess = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _selectMode(bool signUp) {
    if (_isLoading || signUp == _isSignUp) return;
    setState(() {
      _isSignUp = signUp;
      _message = null;
      _messageIsSuccess = false;
      _submitted = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _message = null;
      _messageIsSuccess = false;
    });

    try {
      final repository = AuthRepository(Supabase.instance.client);
      final response = _isSignUp
          ? await repository.signUp(
              email: _email.text.trim(),
              password: _password.text,
            )
          : await repository.signIn(
              email: _email.text.trim(),
              password: _password.text,
            );

      if (response.session == null) {
        setState(() {
          _message = 'Confirmation sent. Check your inbox to continue.';
          _messageIsSuccess = true;
        });
      } else if (mounted) {
        context.go('/home');
      }
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } catch (_) {
      setState(() => _message = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.height < 720;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            const Positioned.fill(child: _Atmosphere()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    compact ? 20 : 28,
                    22,
                    24 + mediaQuery.viewInsets.bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandMark(),
                          SizedBox(height: compact ? 26 : 42),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Column(
                              key: ValueKey(_isSignUp),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSignUp
                                      ? 'Your next level\nstarts here.'
                                      : 'Return to the\nwork that matters.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: compact ? 36 : 42,
                                        fontWeight: FontWeight.w800,
                                        height: 1.02,
                                        letterSpacing: -1.7,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _isSignUp
                                      ? 'Turn intention into daily proof. Build focus, momentum, and a standard you refuse to break.'
                                      : 'Your discipline is already in motion. Sign in and keep the promise you made to yourself.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 24 : 34),
                          _CredentialPanel(
                            compact: compact,
                            formKey: _formKey,
                            email: _email,
                            password: _password,
                            isSignUp: _isSignUp,
                            isLoading: _isLoading,
                            obscurePassword: _obscurePassword,
                            submitted: _submitted,
                            message: _message,
                            messageIsSuccess: _messageIsSuccess,
                            onModeChanged: _selectMode,
                            onPasswordVisibilityChanged: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onSubmit: _submit,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Securely powered by Supabase. Your progress stays yours.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.72,
                                  ),
                                  letterSpacing: 0.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF171123), Color(0xFF0B0910), Color(0xFF07070B)],
        stops: [0, 0.52, 1],
      ),
    ),
    child: CustomPaint(painter: _GlowPainter()),
  );
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.width * 0.55,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0x3D8B5CF6), Color(0x008B5CF6)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.88, size.height * 0.08),
                radius: size.width * 0.55,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB79AFF), Color(0xFF7447F5)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D8B5CF6),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORGE',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
          Text(
            'BY SKILLAURA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryBright,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ],
  );
}

class _CredentialPanel extends StatelessWidget {
  const _CredentialPanel({
    required this.compact,
    required this.formKey,
    required this.email,
    required this.password,
    required this.isSignUp,
    required this.isLoading,
    required this.obscurePassword,
    required this.submitted,
    required this.message,
    required this.messageIsSuccess,
    required this.onModeChanged,
    required this.onPasswordVisibilityChanged,
    required this.onSubmit,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool isSignUp;
  final bool isLoading;
  final bool obscurePassword;
  final bool submitted;
  final String? message;
  final bool messageIsSuccess;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 14 : 18),
    decoration: BoxDecoration(
      color: const Color(0xE6121019),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0x1FFFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 42,
          offset: Offset(0, 20),
        ),
      ],
    ),
    child: Form(
      key: formKey,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeSelector(
            isSignUp: isSignUp,
            enabled: !isLoading,
            onChanged: onModeChanged,
          ),
          SizedBox(height: compact ? 16 : 22),
          _FieldLabel(text: 'EMAIL ADDRESS'),
          const SizedBox(height: 8),
          TextFormField(
            controller: email,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: _fieldDecoration(
              hintText: 'you@example.com',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (value) => value != null && value.contains('@')
                ? null
                : 'Enter a valid email address',
          ),
          SizedBox(height: compact ? 12 : 17),
          _FieldLabel(text: 'PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller: password,
            enabled: !isLoading,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => onSubmit(),
            decoration: _fieldDecoration(
              hintText: 'At least 8 characters',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: isLoading ? null : onPasswordVisibilityChanged,
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 21,
                ),
              ),
            ),
            validator: (value) => value != null && value.length >= 8
                ? null
                : 'Use at least 8 characters',
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: message == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _StatusMessage(
                      message: message!,
                      success: messageIsSuccess,
                    ),
                  ),
          ),
          SizedBox(height: compact ? 16 : 20),
          Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFA17BFF), Color(0xFF7247F5)],
                    ),
              color: isLoading ? const Color(0xFF332A42) : null,
              boxShadow: isLoading
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x3D8B5CF6),
                        blurRadius: 22,
                        offset: Offset(0, 9),
                      ),
                    ],
            ),
            child: FilledButton(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : FittedBox(
                        key: const ValueKey('ready'),
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isSignUp
                                  ? 'Begin your journey'
                                  : 'Continue to Forge',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(icon, size: 21),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFF1B1722),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: AppColors.primaryBright, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFFB7185)),
    ),
  );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.isSignUp,
    required this.enabled,
    required this.onChanged,
  });

  final bool isSignUp;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF0D0B12),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: 'Sign in',
            selected: !isSignUp,
            onTap: enabled ? () => onChanged(false) : null,
          ),
        ),
        Expanded(
          child: _ModeButton(
            label: 'Create account',
            selected: isSignUp,
            onTap: enabled ? () => onChanged(true) : null,
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF292135) : Colors.transparent,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : const Color(0xFFFB7185);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline_rounded : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
