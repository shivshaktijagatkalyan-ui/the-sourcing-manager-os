import 'package:flutter/material.dart';
import '../utils/premium_ui.dart';
import '../utils/role_resolver.dart';
import '../screens/role_dashboard_container.dart';
import '../screens/broker_crm_list.dart';
import '../screens/add_broker_screen.dart';
import '../screens/broker_followup_queue.dart';
import '../screens/activation_pipeline_board.dart';
import '../screens/add_lead_from_broker.dart';
import '../screens/site_visit_list.dart';
import '../screens/broker_leaderboard_screen.dart';
import '../screens/payout_ledger_screen.dart';
import '../screens/caller_lead_queue_screen.dart';
import '../screens/invite_user_screen.dart';
import '../screens/role_management_screen.dart';
import '../screens/system_health_dashboard.dart';
import '../screens/abuse_monitoring_dashboard.dart';
import '../screens/organization_dashboard.dart';

class GlobalDrawer extends StatefulWidget {
  const GlobalDrawer({super.key});

  @override
  State<GlobalDrawer> createState() => _GlobalDrawerState();
}

class _GlobalDrawerState extends State<GlobalDrawer> {
  String _role = 'loading';

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    final role = await RoleResolver.currentRole();
    if (mounted) setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PremiumUI.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildMenuItems(context),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: PremiumUI.primary.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: PremiumUI.primary.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PremiumUI.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text('SM OS', style: PremiumUI.h1.copyWith(fontSize: 18)),
          Text(_role.toUpperCase(), style: PremiumUI.subtitle.copyWith(color: PremiumUI.primary)),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    if (_role == 'loading') return [const Center(child: CircularProgressIndicator())];

    switch (_role) {
      case 'sourcing_manager':
        return [
          _drawerItem(context, 'My Dashboard', Icons.dashboard, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const RoleDashboardContainer()))),
          _drawerItem(context, 'Broker CRM', Icons.people, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BrokerCrmListScreen()))),
          _drawerItem(context, 'Add Broker', Icons.person_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddBrokerScreen()))),
          _drawerItem(context, 'Follow-up Queue', Icons.assignment, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BrokerFollowupQueueScreen()))),
          _drawerItem(context, 'Activation Pipeline', Icons.view_kanban, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ActivationPipelineBoard()))),
          _drawerItem(context, 'Add Lead', Icons.post_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddLeadFromBrokerScreen()))),
          _drawerItem(context, 'Site Visits', Icons.location_on, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SiteVisitListScreen()))),
          _drawerItem(context, 'Performance', Icons.analytics, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BrokerLeaderboardScreen()))),
        ];
      case 'broker_owner':
      case 'broker_agent':
      case 'broker':
        return [
          _drawerItem(context, 'My Dashboard', Icons.dashboard, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const RoleDashboardContainer()))),
          _drawerItem(context, 'My Leads', Icons.list_alt, () {}),
          _drawerItem(context, 'Site Visits', Icons.location_on, () {}),
          _drawerItem(context, 'Payouts', Icons.account_balance_wallet, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PayoutLedgerScreen()))),
        ];
      case 'caller':
        return [
          _drawerItem(context, 'My Dashboard', Icons.dashboard, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const RoleDashboardContainer()))),
          _drawerItem(context, 'Assigned Calls', Icons.call, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CallerLeadQueueScreen()))),
        ];
      case 'platform_admin':
      case 'admin':
      case 'developer_admin':
        return [
          _drawerItem(context, 'My Dashboard', Icons.dashboard, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const RoleDashboardContainer()))),
          _drawerItem(context, 'Organizations', Icons.business, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OrganizationDashboard()))),
          _drawerItem(context, 'User Roles', Icons.admin_panel_settings, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RoleManagementScreen()))),
          _drawerItem(context, 'Abuse Monitoring', Icons.security, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AbuseMonitoringDashboard()))),
          _drawerItem(context, 'System Health', Icons.speed, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SystemHealthDashboard()))),
          _drawerItem(context, 'Invite Users', Icons.person_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const InviteUserScreen()))),
        ];
      default:
        return [
          _drawerItem(context, 'Access Restricted', Icons.lock, () {}),
        ];
    }
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.logout, color: PremiumUI.danger, size: 20),
          const SizedBox(width: 12),
          Text('LOGOUT', style: PremiumUI.subtitle.copyWith(color: PremiumUI.danger)),
        ],
      ),
    );
  }
}
