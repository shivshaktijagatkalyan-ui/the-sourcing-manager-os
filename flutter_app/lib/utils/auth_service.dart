import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import 'url_cleaner/url_cleaner.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final _authStateController = StreamController<AuthState>.broadcast();

  Stream<AuthState> get authStateStream => _authStateController.stream;

  static String webOAuthRedirectUrl({Uri? base}) {
    final current = base ?? Uri.base;
    return Uri(
      scheme: current.scheme,
      host: current.host,
      port: current.hasPort ? current.port : null,
      path: '/',
    ).toString();
  }

  SupabaseClient? get clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      debugPrint('AuthService: Supabase configured but not initialized');
      return null;
    }
  }

  void initialize() {
    if (!AppConfig.isSupabaseConfigured) {
      debugPrint(
          'AuthService: Supabase not configured, skipping initialization');
      return;
    }

    final client = clientOrNull;
    if (client == null) return;

    // Listen to auth state changes from Supabase
    client.auth.onAuthStateChange.listen((data) {
      debugPrint('AuthService: Auth state changed - ${data.event}');
      _authStateController.add(data);
    });

    // Check for OAuth callback
    _handleOAuthCallback();
  }

  Future<void> _handleOAuthCallback() async {
    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];

      if (error != null) {
        debugPrint('AuthService: OAuth error: $error - $errorDescription');
        _cleanOAuthUrl();
        return;
      }

      if (code != null) {
        debugPrint(
            'AuthService: OAuth callback detected with code, exchanging for session...');
        try {
          final client = clientOrNull;
          if (client == null) return;
          await client.auth.exchangeCodeForSession(code);
          debugPrint('AuthService: Code exchanged successfully');
        } catch (exchangeError) {
          debugPrint('AuthService: Error exchanging code: $exchangeError');
        }

        _cleanOAuthUrl();
      }
    } catch (e) {
      debugPrint('AuthService: Error handling OAuth callback: $e');
    }
  }

  void _cleanOAuthUrl() {
    try {
      if (kIsWeb) {
        cleanOAuthUrl();
        debugPrint('AuthService: URL cleaned via history API');
      }
    } catch (e) {
      debugPrint('AuthService: Error cleaning OAuth URL: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw Exception('Supabase not configured');
    }

    try {
      debugPrint('AuthService: Starting Google OAuth flow...');
      final client = clientOrNull;
      if (client == null) throw Exception('Supabase not initialized');

      final result = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? webOAuthRedirectUrl()
            : 'io.supabase.sourcingmanager://login-callback',
      );

      debugPrint('AuthService: OAuth launched: $result');

      if (!result && kIsWeb) {
        throw Exception(
            'Unable to launch Google login. Check browser popup settings.');
      }
    } catch (e) {
      debugPrint('AuthService: Google OAuth error: $e');
      rethrow;
    }
  }

  Future<void> signInWithPassword(String email, String password) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw Exception('Supabase not configured');
    }

    try {
      debugPrint('AuthService: Attempting password login for $email');
      final client = clientOrNull;
      if (client == null) throw Exception('Supabase not initialized');

      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      debugPrint('AuthService: Password login successful');
    } on AuthException catch (e) {
      debugPrint('AuthService: Auth error - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('AuthService: Unexpected error during login: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!AppConfig.isSupabaseConfigured) {
      return;
    }

    try {
      debugPrint('AuthService: Signing out...');
      final client = clientOrNull;
      if (client == null) return;
      await client.auth.signOut();
      debugPrint('AuthService: Sign out successful');
    } catch (e) {
      debugPrint('AuthService: Error signing out: $e');
      rethrow;
    }
  }

  Future<User?> getCurrentUser() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }

    try {
      return clientOrNull?.auth.currentUser;
    } catch (e) {
      debugPrint('AuthService: Error getting current user: $e');
      return null;
    }
  }

  Future<String?> getCurrentUserRole() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return null;

      // Get user metadata which may contain role info
      final role = user.userMetadata?['role'] as String?;
      debugPrint('AuthService: Current user role: $role');
      return role;
    } catch (e) {
      debugPrint('AuthService: Error getting user role: $e');
      return null;
    }
  }

  bool isAuthenticated() {
    if (!AppConfig.isSupabaseConfigured) {
      return AppConfig.isTrainingMode;
    }

    try {
      return clientOrNull?.auth.currentUser != null;
    } catch (e) {
      debugPrint('AuthService: Error checking authentication: $e');
      return false;
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
