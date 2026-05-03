import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_config.dart';
import 'screens/lead_queue.dart';
import 'screens/broker_upload.dart';
import 'screens/site_visit_list.dart';
import 'screens/broker_review_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const SourcingManagerOS());
}

class SourcingManagerOS extends StatelessWidget {
  const SourcingManagerOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Sourcing Manager OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const LeadQueueScreen(),
    const SiteVisitListScreen(),
    const BrokerReviewListScreen(),
    const BrokerUploadScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), label: 'Visits'),
          NavigationDestination(icon: Icon(Icons.rate_review_outlined), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Upload'),
        ],
      ),
    );
  }
}
