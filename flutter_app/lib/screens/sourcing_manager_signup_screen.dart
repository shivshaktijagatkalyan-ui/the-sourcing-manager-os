import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SourcingManagerSignupScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;

  const SourcingManagerSignupScreen({super.key, this.onAuthStateChanged});

  @override
  State<SourcingManagerSignupScreen> createState() =>
      _SourcingManagerSignupScreenState();
}

class _SourcingManagerSignupScreenState
    extends State<SourcingManagerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      // Sign up with Supabase Auth
      final response = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Handle session recovery if email verification is disabled but session not returned immediately
        if (response.session == null && client.auth.currentSession == null) {
          try {
            await client.auth.signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
          } catch (_) {
            // If sign-in fails (e.g. email confirmation required), notify user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Account created! Please confirm your email to activate.')),
              );
              Navigator.pop(context);
              return;
            }
          }
        }

        // Call complete-onboarding Edge Function
        final onboarding =
            await client.functions.invoke('complete-onboarding', body: {
          'role': 'sourcing_manager',
          'full_name': _fullNameController.text.trim(),
          'company': _companyController.text.trim(),
          'city': _cityController.text.trim(),
          'area': 'Mira Road', // Default for pilot, could be made dynamic
        });

        if (mounted) {
          if (onboarding.data?['ok'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Sourcing Manager account created successfully!')),
            );
            widget.onAuthStateChanged?.call();
            Navigator.popUntil(context, (route) => route.isFirst);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(onboarding.data?['reason'] ?? 'Onboarding failed'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
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
  void dispose() {
    _fullNameController.dispose();
    _companyController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Sourcing Manager Signup'),
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
              const Icon(Icons.business_center_outlined,
                  size: 80, color: Color(0xFFF5B545)),
              const SizedBox(height: 32),
              const Text(
                'Sourcing Manager Registration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account to manage brokers and leads',
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
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: 'Company/Project',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Company/Project is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'City',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'City is required' : null,
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
