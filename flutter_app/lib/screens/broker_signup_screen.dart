import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../app_config.dart';
import '../utils/premium_ui.dart';
import '../utils/auth_service.dart';

class BrokerSignupScreen extends StatefulWidget {
  final VoidCallback? onAuthStateChanged;

  const BrokerSignupScreen({super.key, this.onAuthStateChanged});

  @override
  State<BrokerSignupScreen> createState() => _BrokerSignupScreenState();
}

class _BrokerSignupScreenState extends State<BrokerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _autoFillTest() {
    final id = const Uuid().v4();
    setState(() {
      _fullNameController.text = "Test Broker ${id.substring(0, 4)}";
      _companyController.text = "Test Agency ${id.substring(0, 4)}";
      _areaController.text = "Panvel";
      _cityController.text = "Navi Mumbai";
      _emailController.text = "testuser+$id@example.com";
      _passwordController.text = "Test@1234";
      _confirmPasswordController.text = "Test@1234";
    });
  }

  void _showSupabaseConfigError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Supabase is not configured. Run the app with SUPABASE_URL and SUPABASE_ANON_KEY or enable training mode.',
        ),
        backgroundColor: PremiumUI.danger,
      ),
    );
  }

  Future<void> _signUpWithGoogle() async {
    if (!AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
      _showSupabaseConfigError();
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (AppConfig.isTrainingMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        AppConfig.mockRole = 'broker_owner';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Broker account created with Google (TRAINING MODE)')),
          );
          widget.onAuthStateChanged?.call();
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        return;
      }

      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthService.webOAuthRedirectUrl(),
      );

      if (!launched) {
        throw const AuthException('Unable to launch Google login');
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw const AuthException('Google login did not complete.');
      }

      final client = Supabase.instance.client;
      final onboarding =
          await client.functions.invoke('complete-onboarding', body: {
        'selected_role': 'broker_owner',
        'full_name': user.userMetadata?['full_name'] ?? user.email ?? 'Broker',
        'company_name': 'Google Registered',
        'area': 'Panvel',
        'city': 'Navi Mumbai',
        'project_interest': 'The Wadhwa Wise City, Panvel',
      });

      final data = onboarding.data;
      if (data is! Map || data['ok'] != true) {
        final reason = data is Map
            ? data['reason'] ?? 'Unknown onboarding failure'
            : 'Invalid onboarding response';
        throw AuthException(reason.toString());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Broker account created with Google! ID: ${user.id.substring(0, 8)}...'),
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onAuthStateChanged?.call();
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: PremiumUI.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google signup failed: ${e.toString()}'),
            backgroundColor: PremiumUI.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
      _showSupabaseConfigError();
      return;
    }
    debugPrint(
        'BrokerSignup: starting _signUp, isTrainingMode=${AppConfig.isTrainingMode}');
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isTrainingMode) {
        // In Training Mode, we simulate success
        await Future.delayed(const Duration(milliseconds: 800));
        AppConfig.mockRole = 'broker_owner';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Broker account created successfully. (TRAINING MODE)')),
          );
          widget.onAuthStateChanged?.call();
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        return;
      }

      final client = Supabase.instance.client;
      final response = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw const AuthException(
            'Unable to create broker account. Please try again.');
      }

      if (response.session == null && client.auth.currentSession == null) {
        await client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      final onboarding =
          await client.functions.invoke('complete-onboarding', body: {
        'selected_role': 'broker_owner',
        'full_name': _fullNameController.text.trim(),
        'company_name': _companyController.text.trim(),
        'area': _areaController.text.trim(),
        'city': _cityController.text.trim(),
        'project_interest': 'The Wadhwa Wise City, Panvel',
      });

      final data = onboarding.data;
      if (data is! Map || data['ok'] != true) {
        final reason = data is Map
            ? data['reason'] ?? 'Unknown onboarding failure'
            : 'Invalid onboarding response';
        throw AuthException(reason.toString());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broker account created successfully.')),
        );
        widget.onAuthStateChanged?.call();
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: PremiumUI.danger),
        );
      }
    } catch (e, stack) {
      debugPrint('BrokerSignup: unexpected error: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unexpected error: ${e.toString()}'),
              backgroundColor: PremiumUI.danger),
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
    _areaController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('BROKER REGISTRATION',
            style: PremiumUI.h1.copyWith(fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PremiumUI.primary.withValues(alpha: 0.1),
              PremiumUI.background,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumUI.glassCard(
                  child: Column(
                    children: [
                      const Icon(Icons.handshake_outlined,
                          size: 48, color: PremiumUI.primary),
                      const SizedBox(height: 16),
                      Text('JOIN THE NETWORK',
                          style: PremiumUI.h1.copyWith(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text('Premium channel partner registration',
                          style: PremiumUI.subtitle),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildField(
                  controller: _fullNameController,
                  label: 'FULL NAME',
                  icon: Icons.person_outline,
                  hint: 'As per RERA / Aadhaar',
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _companyController,
                  label: 'COMPANY NAME',
                  icon: Icons.business_outlined,
                  hint: 'Real estate agency name',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _areaController,
                        label: 'AREA',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField(
                        controller: _cityController,
                        label: 'CITY',
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _emailController,
                  label: 'EMAIL ADDRESS',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passwordController,
                  label: 'PASSWORD',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                        size: 18),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumUI.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      shadowColor: PremiumUI.primary.withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : const Text('CREATE ACCOUNT',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.g_mobiledata,
                          color: Colors.black, size: 20),
                    ),
                    label: const Text('Sign up with Google',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : _autoFillTest,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PremiumUI.primary, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('GENERATE TEST ACCOUNT DATA',
                      style: TextStyle(
                          color: PremiumUI.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 24),
                Text(
                  'By signing up, you agree to the Dataless Security Constitution and Platform Terms.',
                  textAlign: TextAlign.center,
                  style: PremiumUI.subtitle.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: PremiumUI.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.white38, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PremiumUI.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PremiumUI.danger),
            ),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Field required' : null,
        ),
      ],
    );
  }
}
