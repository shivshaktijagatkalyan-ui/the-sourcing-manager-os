import 'package:flutter/foundation.dart';
import 'utils/training_storage.dart';

class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appEnvironment =
      String.fromEnvironment('SM_OS_ENV', defaultValue: 'production');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project');

  static bool get isSupabaseMissing => !isSupabaseConfigured;

  static bool get allowsTrainingMode =>
      !kReleaseMode ||
      appEnvironment == 'local' ||
      appEnvironment == 'dev' ||
      (kIsWeb &&
          (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1'));

  static bool get isTrainingModeEnabled => isTrainingMode;

  static bool get isTrainingMode =>
      allowsTrainingMode && (_isTrainingMode || _hasBypassParameter);

  static set isTrainingMode(bool value) {
    _isTrainingMode = allowsTrainingMode && value;
    debugPrint('AppConfig: training mode set to $value');
    try {
      writeTrainingStorage('sm_os_training_mode', _isTrainingMode.toString());
    } catch (_) {}
  }

  static bool get _hasBypassParameter {
    if (!allowsTrainingMode) return false;
    final queryRole = Uri.base.queryParameters['mockRole']?.trim();
    final training = Uri.base.queryParameters['training']?.trim();
    return (queryRole != null && queryRole.isNotEmpty) || (training == 'true');
  }

  static bool _isTrainingMode = false;

  static String get mockRole => _mockRole;
  static set mockRole(String value) {
    _mockRole = value;
    try {
      writeTrainingStorage('sm_os_mock_role', value);
    } catch (_) {}
  }

  static String _mockRole = '';

  static void initialize() {
    try {
      // Force training mode to false on launch unless query parameters explicitly override it
      _isTrainingMode = false;
      _mockRole = '';
      writeTrainingStorage('sm_os_training_mode', 'false');
      writeTrainingStorage('sm_os_mock_role', '');

      if (!allowsTrainingMode) {
        return;
      }

      final queryRole = Uri.base.queryParameters['mockRole']?.trim();
      final queryTraining = Uri.base.queryParameters['training']?.trim();
      if ((queryRole != null && queryRole.isNotEmpty) ||
          queryTraining == 'true') {
        _isTrainingMode = true;
        mockRole = queryRole ?? 'sourcing_manager';
        debugPrint(
            'AppConfig: training mode enabled from URL query, role: $_mockRole');
      }
    } catch (_) {}
  }

  static String get supabaseStatus {
    if (isSupabaseConfigured) return 'configured';
    return 'not configured';
  }
}
