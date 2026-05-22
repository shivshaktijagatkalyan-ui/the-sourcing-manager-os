import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'screens/abuse_monitoring_dashboard.dart';
import 'screens/admin_diagnostics_screen.dart';
import 'screens/broker_leaderboard_screen.dart';
import 'screens/broker_review_list.dart';
import 'screens/broker_upload.dart';
import 'screens/compliance_report_screen.dart';
import 'screens/developer_roi_dashboard.dart';
import 'screens/invite_user_screen.dart';
import 'screens/lead_queue.dart';
import 'screens/lead_routing_config_screen.dart';
import 'screens/onboarding_audit_timeline.dart';
import 'screens/organization_dashboard.dart';
import 'screens/organization_onboarding_wizard.dart';
import 'screens/payout_ledger_screen.dart';
import 'screens/pending_invites_screen.dart';
import 'screens/permission_template_editor.dart';
import 'screens/risk_notifications_view.dart';
import 'screens/role_management_screen.dart';
import 'screens/site_visit_list.dart';
import 'screens/suspended_users_screen.dart';
import 'screens/system_health_dashboard.dart';
import 'screens/trust_score_history_screen.dart';
import 'screens/user_activation_checklist.dart';
import 'screens/add_broker_screen.dart';
import 'screens/broker_crm_list.dart';
import 'screens/broker_followup_queue.dart';
import 'screens/activation_pipeline_board.dart';
import 'screens/add_lead_from_broker.dart';
import 'screens/sourcing_manager_dashboard.dart';
import 'screens/broker_sourced_site_visits.dart';
import 'screens/caller_dashboard_screen.dart';
import 'screens/caller_lead_queue_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_dashboard_container.dart';
import 'screens/super_admin_dashboard.dart';
import 'screens/choose_role_screen.dart';
import 'services/sync_service.dart';
import 'utils/connectivity_manager.dart';
import 'utils/role_resolver.dart';
import 'utils/training_mode_overlay.dart';
import 'utils/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget built for: ${details.exceptionAsString()}');
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Application failed to render.\nCheck browser console for details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  await _initializeApp();
  runApp(const SourcingManagerOS());
}

Future<void> _initializeApp() async {
  debugPrint('main: startup begin');
  debugPrint('main: supabase status=${AppConfig.supabaseStatus}');
  debugPrint('main: training mode enabled=${AppConfig.isTrainingModeEnabled}');

  if (!AppConfig.isSupabaseConfigured) {
    debugPrint(
        'main: Supabase not configured or missing keys, skipping initialization.');
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('main: Supabase.initialize timed out after 12 seconds.');
        throw TimeoutException('Supabase initialization timed out');
      },
    );
    debugPrint('main: Supabase.initialize completed successfully.');
    await SyncService.instance.initialize();
    SyncService.instance.startBackgroundSync();
    debugPrint('main: offline sync service initialized.');
  } catch (error, stack) {
    debugPrint('main: Supabase.initialize failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}

class SourcingManagerOS extends StatefulWidget {
  const SourcingManagerOS({super.key});

  @override
  State<SourcingManagerOS> createState() => _SourcingManagerOSState();
}

class _SourcingManagerOSState extends State<SourcingManagerOS> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('SourcingManagerOS: first frame rendered');
      if (AppConfig.isSupabaseConfigured) {
        AuthService().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Sourcing Manager OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFF5B545),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5B545),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF18212F),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return TrainingModeOverlay(
          isTrainingMode: AppConfig.isTrainingMode,
          child: child ?? const SizedBox.shrink(),
        );
      },
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
  String _role = 'loading';
  StreamSubscription<AuthState>? _authSubscription;

  final List<Widget> _screens = [
    const RoleDashboardContainer(),
    const LeadQueueScreen(),
    const SiteVisitListScreen(),
    const BrokerReviewListScreen(),
    const AbuseMonitoringDashboard(),
    const BrokerLeaderboardScreen(),
    const PayoutLedgerScreen(),
    const ComplianceReportScreen(),
    const DeveloperRoiDashboard(),
    const OrganizationDashboard(),
    const OrganizationOnboardingWizard(),
    const InviteUserScreen(),
    const RoleManagementScreen(),
    const PendingInvitesScreen(),
    const PermissionTemplateEditor(),
    const UserActivationChecklist(),
    const SuspendedUsersScreen(),
    const OnboardingAuditTimeline(),
    const LeadRoutingConfigScreen(),
    const BrokerUploadScreen(),
    const RiskNotificationsView(),
    const TrustScoreHistoryScreen(),
    const SystemHealthDashboard(),
    const AdminDiagnosticsScreen(),
    const BrokerCrmListScreen(),
    const AddBrokerScreen(),
    const BrokerFollowupQueueScreen(),
    const ActivationPipelineBoard(),
    const AddLeadFromBrokerScreen(),
    const SourcingManagerDashboard(),
    const BrokerSourcedSiteVisitsScreen(),
    const CallerDashboardScreen(),
    const CallerLeadQueueScreen(),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('MainNavigation: initState');
    ConnectivityManager.listen(context);
    if (!AppConfig.isSupabaseConfigured &&
        !AppConfig.isTrainingMode &&
        AppConfig.allowsTrainingMode &&
        kDebugMode) {
      AppConfig.isTrainingMode = true;
    }
    _fetchRole();

    if (AppConfig.isSupabaseConfigured) {
      final client = AuthService().clientOrNull;
      _authSubscription = client?.auth.onAuthStateChange.listen((data) {
        debugPrint('MainNavigation: Auth state changed - ${data.event}');
        if (mounted) _fetchRole();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchRole() async {
    debugPrint('MainNavigation: _fetchRole started');
    try {
      // Add a timeout to prevent hanging on the loading screen
      final role = await RoleResolver.currentRole().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
              'MainNavigation: Role fetching timed out, falling back to anonymous');
          return 'anonymous';
        },
      );
      debugPrint('MainNavigation: role fetched="$role"');
      if (mounted) {
        setState(() {
          _role = role;
        });
      }
    } catch (e) {
      debugPrint('MainNavigation: Error fetching role: $e');
      if (mounted) {
        setState(() {
          _role = 'anonymous';
        });
      }
    }
  }

  Future<void> _logout() async {
    if (AppConfig.isSupabaseConfigured) {
      await AuthService().signOut();
    }
    AppConfig.isTrainingMode = false;
    AppConfig.mockRole = '';
    if (mounted) {
      _fetchRole();
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  void _pushFromDrawer(Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _enableTrainingMode() {
    setState(() {
      AppConfig.isTrainingMode = true;
    });
    _fetchRole();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (!AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
      content = _buildConfigurationScreen();
    } else if (_role == 'loading') {
      content = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (_role == 'anonymous') {
      content = LoginScreen(onAuthStateChanged: _fetchRole);
    } else if (_role == 'suspended' || _role == 'pending') {
      content = _buildAccessBlockedScreen(_role);
    } else if (_role == 'unknown') {
      content = ChooseRoleScreen(onAuthStateChanged: _fetchRole);
    } else {
      content = _buildDashboard();
    }

    return TrainingModeOverlay(
      key: ValueKey('${AppConfig.isTrainingMode}_$_role'),
      isTrainingMode: AppConfig.isTrainingMode,
      child: content,
    );
  }

  Widget _buildAccessBlockedScreen(String status) {
    final isSuspended = status == 'suspended';
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuspended ? Icons.block : Icons.hourglass_top_rounded,
                size: 72,
                color: isSuspended ? Colors.red : Colors.amber,
              ),
              const SizedBox(height: 20),
              Text(
                isSuspended ? 'Account Suspended' : 'Access Pending Approval',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                isSuspended
                    ? 'Your account has been suspended. Please contact your organization administrator.'
                    : 'Your account is awaiting activation. You will be notified once approved.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  _fetchRole();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Required')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 72, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                'Supabase is not configured. The app cannot access authentication or onboarding until you provide your Supabase project settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.allowsTrainingMode
                    ? 'To run locally, restart with the SUPABASE_URL and SUPABASE_ANON_KEY values, or open the app with ?training=true for local testing.'
                    : 'This build cannot enter training mode. Restart with valid Supabase project settings.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 32),
              if (AppConfig.allowsTrainingMode)
                ElevatedButton(
                  onPressed: _enableTrainingMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B545),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CONTINUE IN TRAINING MODE',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final isAdmin = RoleResolver.isAdminRole(_role);
    final isSourcing = RoleResolver.isSourcingRole(_role);
    final isCaller = RoleResolver.isCallerRole(_role);
    final isBroker = RoleResolver.isBrokerRole(_role);
    final hasKnownRole = isAdmin || isSourcing || isCaller || isBroker;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SM OS'),
        elevation: 0,
        actions: [
          if (AppConfig.isTrainingMode)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text('TRAINING',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF6366F1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sourcing Manager OS',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Spacer(),
                  Text('Role: ${_role.replaceAll('_', ' ').toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  Text('Version: 0.7.0-enterprise',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            if (AppConfig.allowsTrainingMode)
              SwitchListTile(
                title:
                    const Text('Training Mode', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Practice without affecting data',
                    style: TextStyle(fontSize: 10)),
                value: AppConfig.isTrainingMode,
                onChanged: (val) {
                  setState(() {
                    AppConfig.isTrainingMode = val;
                    AppConfig.mockRole = val ? 'sourcing_manager' : '';
                  });
                  _fetchRole();
                },
                secondary: const Icon(Icons.school_outlined),
              ),
            const Divider(),
            if (hasKnownRole)
              _NavTile(
                  icon: Icons.dashboard_outlined,
                  title: 'My Dashboard',
                  onTap: () => _select(0))
            else
              _NavTile(
                  icon: Icons.lock_outline,
                  title: 'Access Restricted',
                  onTap: () => _select(0)),
            if (isBroker) _buildBrokerMenu(),
            if (isSourcing) _buildSourcingMenu(),
            if (isCaller) _buildCallerMenu(),
            if (isAdmin) _buildAdminMenu(),
            const Divider(),
            if (_role != 'anonymous')
              _NavTile(
                icon: Icons.logout,
                title: 'Logout',
                onTap: _logout,
              ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildBrokerMenu() {
    return Column(
      children: [
        const Divider(),
        const ListTile(
            title: Text('BROKER OPERATIONS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54))),
        _NavTile(
            icon: Icons.assignment_outlined,
            title: 'Submit Lead',
            onTap: () => _select(19)),
        _NavTile(
            icon: Icons.table_rows_outlined,
            title: 'My Leads',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.location_on_outlined,
            title: 'My Site Visits',
            onTap: () => _select(30)),
        _NavTile(
            icon: Icons.shield_outlined,
            title: 'My Data Loans',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.lock_clock_outlined,
            title: 'My Broker Locks',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.workspace_premium_outlined,
            title: 'My Performance',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payouts',
            onTap: () => _select(6)),
      ],
    );
  }

  Widget _buildSourcingMenu() {
    return Column(
      children: [
        const Divider(),
        const ListTile(
            title: Text('SOURCING OPERATIONS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54))),
        _NavTile(
            icon: Icons.analytics_outlined,
            title: 'Sourcing Dashboard',
            onTap: () => _select(29)),
        _NavTile(
            icon: Icons.people_outline,
            title: 'Broker CRM',
            onTap: () => _select(24)),
        _NavTile(
            icon: Icons.view_column_outlined,
            title: 'Activation Pipeline',
            onTap: () => _select(27)),
        _NavTile(
            icon: Icons.today_outlined,
            title: "Today's Follow-ups",
            onTap: () => _select(26)),
        _NavTile(
            icon: Icons.person_add_alt_outlined,
            title: 'Add Lead From Broker',
            onTap: () => _select(28)),
        _NavTile(
            icon: Icons.location_on_outlined,
            title: 'Site Visit Tracker',
            onTap: () => _select(30)),
        _NavTile(
            icon: Icons.person_add_outlined,
            title: 'Add Broker',
            onTap: () => _select(25)),
        _NavTile(
            icon: Icons.leaderboard_outlined,
            title: 'Performance',
            onTap: () => _select(29)),
      ],
    );
  }

  Widget _buildCallerMenu() {
    return Column(
      children: [
        const Divider(),
        const ListTile(
            title: Text('CALL CENTER',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54))),
        _NavTile(
            icon: Icons.call_to_action_outlined,
            title: 'Caller Dashboard',
            onTap: () => _select(31)),
        _NavTile(
            icon: Icons.contact_phone_outlined,
            title: 'Assigned Calls',
            onTap: () => _select(32)),
        _NavTile(
            icon: Icons.schedule_outlined,
            title: 'Follow-ups',
            onTap: () => _select(31)),
        _NavTile(
            icon: Icons.fact_check_outlined,
            title: 'Outcomes',
            onTap: () => _select(32)),
      ],
    );
  }

  Widget _buildAdminMenu() {
    return Column(
      children: [
        const Divider(),
        const ListTile(
            title: Text('SUPER ADMIN',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54))),
        _NavTile(
            icon: Icons.dashboard_outlined,
            title: 'My Dashboard',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.business_outlined,
            title: 'Organizations',
            onTap: () => _pushFromDrawer(
                  _role == 'platform_admin'
                      ? const SuperAdminDashboard()
                      : const OrganizationDashboard(),
                )),
        _NavTile(
            icon: Icons.apartment_outlined,
            title: 'Projects',
            onTap: () => _select(8)),
        _NavTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Users & Roles',
            onTap: () => _select(12)),
        _NavTile(
            icon: Icons.people_outline,
            title: 'Brokers',
            onTap: () => _select(24)),
        _NavTile(
            icon: Icons.view_list_outlined,
            title: 'Leads Overview',
            onTap: () => _select(1)),
        _NavTile(
            icon: Icons.location_on_outlined,
            title: 'Site Visits',
            onTap: () => _select(2)),
        _NavTile(
            icon: Icons.lock_clock_outlined,
            title: 'Locks',
            onTap: () => _select(0)),
        _NavTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Risk Alerts',
            onTap: () => _select(4)),
        _NavTile(icon: Icons.history, title: 'Audit', onTap: () => _select(17)),
        _NavTile(
            icon: Icons.health_and_safety_outlined,
            title: 'System Health',
            onTap: () => _select(22)),
        _NavTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => _select(23)),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NavTile(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
