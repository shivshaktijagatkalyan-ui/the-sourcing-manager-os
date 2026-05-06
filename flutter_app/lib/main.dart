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
import 'screens/role_dashboard_container.dart';
import 'utils/connectivity_manager.dart';
import 'utils/role_resolver.dart';
import 'utils/training_mode_overlay.dart';

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
    ConnectivityManager.listen(context);
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    try {
      final role = await RoleResolver.currentRole();
      setState(() => _role = role);
    } catch (e) {
      setState(() => _role = 'unknown');
    }
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                          fontSize: 10))),
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
            SwitchListTile(
              title:
                  const Text('Training Mode', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Practice without affecting data',
                  style: TextStyle(fontSize: 10)),
              value: AppConfig.isTrainingMode,
              onChanged: (val) =>
                  setState(() => AppConfig.isTrainingMode = val),
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
            if (isBroker) ...[
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
            if (isSourcing) ...[
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
                  title: 'Today\'s Follow-ups',
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
            if (isCaller) ...[
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
            if (isAdmin) ...[
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
                  onTap: () => _select(9)),
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
              _NavTile(
                  icon: Icons.history,
                  title: 'Audit',
                  onTap: () => _select(17)),
              _NavTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'System Health',
                  onTap: () => _select(22)),
              _NavTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => _select(23)),
            ],
          ],
        ),
      ),
      body: TrainingModeOverlay(
        isTrainingMode: AppConfig.isTrainingMode,
        child: _screens[_selectedIndex],
      ),
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
