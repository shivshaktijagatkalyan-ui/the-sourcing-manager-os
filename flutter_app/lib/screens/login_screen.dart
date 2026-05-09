import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'choose_role_screen.dart';
import '../app_config.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;

  const LoginScreen({super.key, this.onAuthStateChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful!')),
        );
        widget.onAuthStateChanged?.call();
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 80, color: Color(0xFFF5B545)),
              const SizedBox(height: 32),
              Text(
                'Sourcing Manager OS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your credentials to access the secure CRM',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
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
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
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
                    : const Text('Sign In',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ChooseRoleScreen(
                              onAuthStateChanged: widget.onAuthStateChanged,
                            )),
                  );
                },
                child: const Text('Create Account',
                    style: TextStyle(color: Color(0xFFF5B545))),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Access Request Sent to Admin Queue')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Request Access',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Training Mode',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 8),
                  Switch(
                    value: AppConfig.isTrainingMode,
                    onChanged: (val) {
                      setState(() {
                        AppConfig.isTrainingMode = val;
                        if (val) {
                          AppConfig.mockRole = 'sourcing_manager';
                        } else {
                          AppConfig.mockRole = '';
                        }
                      });
                      widget.onAuthStateChanged?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(val
                                ? 'Training Mode ON: Sourcing Manager Demo'
                                : 'Training Mode OFF')),
                      );
                    },
                    activeThumbColor: const Color(0xFFF5B545),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
