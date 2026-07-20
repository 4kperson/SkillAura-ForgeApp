import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = AuthRepository(Supabase.instance.client);
      final response = _isSignUp
          ? await repo.signUp(
              email: _email.text.trim(),
              password: _password.text,
            )
          : await repo.signIn(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (response.session == null) {
        setState(() => _error = 'Check your email to confirm your account.');
      } else if (mounted) {
        context.go('/home');
      }
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF171024), Color(0xFF09070D)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA97BFF), Color(0xFF6E44FF)],
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x806E44FF), blurRadius: 28),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _isSignUp ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Build discipline, one day at a time.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 34),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        filled: true,
                        fillColor: const Color(0xFF211A2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        filled: true,
                        fillColor: const Color(0xFF211A2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) => value != null && value.length >= 8
                          ? null
                          : 'Use at least 8 characters',
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(
                          _isLoading
                              ? 'Please wait…'
                              : _isSignUp
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
