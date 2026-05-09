import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallerSignupScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;

  const CallerSignupScreen({super.key, this.onAuthStateChanged});

  @override
  State<CallerSignupScreen> createState() => _CallerSignupScreenState();
}

class _CallerSignupScreenState extends State<CallerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        if (response.session == null &&
            Supabase.instance.client.auth.currentSession == null) {
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Account created! Please confirm your email to activate.')),
              );
              Navigator.popUntil(context, (route) => route.isFirst);
              return;
            }
          }
        }

        await Supabase.instance.client.functions
            .invoke('complete-onboarding', body: {
          'role': 'caller',
          'full_name': _fullNameController.text.trim(),
          'invite_code': _inviteCodeController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Account created successfully! Please check your email for verification.')),
          );
          widget.onAuthStateChanged?.call();
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('An unexpected error occurred'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Caller Signup'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phone_outlined,
                  size: 80, color: Color(0xFFF5B545)),
              const SizedBox(height: 32),
              const Text(
                'Caller Registration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join to make secure calls to assigned leads',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inviteCodeController,
                decoration: InputDecoration(
                  labelText: 'Invite Code / Organization Code',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Invite code is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Password is required';
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B545),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black87))
                    : const Text('CREATE ACCOUNT',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
