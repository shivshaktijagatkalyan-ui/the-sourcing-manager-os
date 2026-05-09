import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import 'complete_onboarding_screen.dart';
import 'role_dashboard_container.dart';
import 'access_restricted_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    setState(() => _errorMessage = null);
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email and password are required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.user != null) {
        await _navigateToNextScreen(response.user!.id);
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _errorMessage = null);
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${AppConfig.appDeepLinkScheme}://auth-callback',
      );

      if (!mounted) return;

      if (response) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _navigateToNextScreen(user.id);
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Navigate to appropriate screen based on user's profile and role status.
  Future<void> _navigateToNextScreen(String userId) async {
    try {
      // Query user's profile
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (profileResponse == null) {
        // No profile exists → show Complete Onboarding
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const CompleteOnboardingScreen(),
          ),
        );
      } else {
        final status = profileResponse['status'] as String?;

        if (status == 'active') {
          // Profile exists and active → go to role dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const RoleDashboardContainer(),
            ),
          );
        } else {
          // Profile exists but inactive/pending/suspended
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AccessRestrictedScreen(
                role: status ?? 'unknown',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to check profile. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              
              // Logo / Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B545).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hub,
                    size: 48,
                    color: Color(0xFFF5B545),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Sourcing Manager OS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Sign in to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
                    ),
                  ),
                ),
              
              if (_errorMessage != null) const SizedBox(height: 16),
              
              // Email field
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              // Password field
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              
              const SizedBox(height: 24),
              
              // Email login button
              FilledButton(
                onPressed: _isLoading ? null : _handleEmailLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B545),
                  disabledBackgroundColor: const Color(0xFFF5B545).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Google sign-in button
              OutlinedButton(
                onPressed: _isLoading ? null : _handleGoogleLogin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/google_logo.png',
                      height: 20,
                      width: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Footer text
              Center(
                child: Text(
                  'Enterprise Sales Platform',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
