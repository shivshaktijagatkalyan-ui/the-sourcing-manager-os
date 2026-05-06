class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabaseAnonKey != 'your-anon-key';

  static bool isTrainingMode = true;
  static String mockRole = 'sourcing_manager'; // Default role for field pilot (Vinod Gupta)
}
