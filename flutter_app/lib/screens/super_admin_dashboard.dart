import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../utils/premium_ui.dart';
import 'abuse_monitoring_dashboard.dart';
import 'admin_diagnostics_screen.dart';
import 'broker_review_list.dart';
import 'invite_user_screen.dart';
import 'organization_dashboard.dart';
import 'role_management_screen.dart';
import 'system_health_dashboard.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool _isLoading = true;
  Map<String, int> _kpis = {};
  List<Map<String, dynamic>> _riskAlerts = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      if (AppConfig.isSupabaseConfigured) {
        await _loadLive();
      } else {
        await _loadDemo();
      }
    } catch (_) {
      if (!mounted) return;
      await _loadDemo();
    }
  }

  Future<void> _loadLive() async {
    final client = Supabase.instance.client;

    Future<int> countFrom(
      String table, {
      String select = 'id',
      String? eqField,
      dynamic eqValue,
    }) async {
      try {
        dynamic query = client.from(table).select(select);
        if (eqField != null) {
          query = query.eq(eqField, eqValue);
        }
        final rows = await query;
        return (rows as List).length;
      } catch (_) {
        return 0;
      }
    }

    Future<List<Map<String, dynamic>>> selectSafe(
      String table,
      String select, {
      int limit = 5,
      String orderField = 'created_at',
      bool ascending = false,
      String? eqField,
      dynamic eqValue,
    }) async {
      try {
        dynamic query = client.from(table).select(select);
        if (eqField != null) {
          query = query.eq(eqField, eqValue);
        }
        final rows = await query.order(orderField, ascending: ascending).limit(limit);
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    final totalOrganizations = await countFrom('organizations');
    final activeProjects = await countFrom('projects', eqField: 'status', eqValue: 'active');
    final sourcingManagers =
        await countFrom('role_assignments', eqField: 'role_id', eqValue: 'sourcing_manager');
    final totalBrokers = await countFrom('brokers_public');
    final totalCallers =
        await countFrom('role_assignments', eqField: 'role_id', eqValue: 'caller');
    final totalLeads = await countFrom('leads_public');
    final callsAttempted = await countFrom('call_attempts');
    final siteVisitsScheduled =
        await countFrom('site_visits', eqField: 'status', eqValue: 'scheduled');
    final verifiedVisits = await countFrom('site_visits', eqField: 'status', eqValue: 'completed');
    final activeLocks = await countFrom('broker_locks', eqField: 'status', eqValue: 'active');
    final openDisputes = await countFrom('disputes', eqField: 'status', eqValue: 'open');
    final riskAlerts = await countFrom('abuse_events', eqField: 'status', eqValue: 'open');
    final healthIssues = await countFrom('system_health_events', eqField: 'status', eqValue: 'open');

    final organizations = await selectSafe(
      'organizations',
      'id, name, status, created_at',
      limit: 6,
    );
    final projects = await selectSafe(
      'projects',
      'id, project_name, city, area, status',
      limit: 6,
    );
    final alerts = await selectSafe(
      'abuse_events',
      'id, event_type, severity, status, created_at',
      limit: 6,
    );
    final activity = await selectSafe(
      'audit_events',
      'id, event_type, created_at',
      limit: 8,
    );

    if (!mounted) return;
    setState(() {
      _kpis = {
        'Total Organizations': totalOrganizations,
        'Active Projects': activeProjects,
        'Total Sourcing Managers': sourcingManagers,
        'Total Brokers': totalBrokers,
        'Total Callers': totalCallers,
        'Total Leads': totalLeads,
        'Calls Attempted': callsAttempted,
        'Site Visits Scheduled': siteVisitsScheduled,
        'Verified Visits': verifiedVisits,
        'Active Broker Locks': activeLocks,
        'Open Disputes': openDisputes,
        'Risk Alerts': riskAlerts,
        'System Health': healthIssues,
      };
      _riskAlerts = alerts;
      _activity = activity;
      _organizations = organizations;
      _projects = projects;
      _isLoading = false;
    });
  }

  Future<void> _loadDemo() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _kpis = {
        'Total Organizations': 4,
        'Active Projects': 8,
        'Total Sourcing Managers': 12,
        'Total Brokers': 156,
        'Total Callers': 42,
        'Total Leads': 1240,
        'Calls Attempted': 832,
        'Site Visits Scheduled': 61,
        'Verified Visits': 37,
        'Active Broker Locks': 28,
        'Open Disputes': 3,
        'Risk Alerts': 2,
        'System Health': 1,
      };
      _organizations = [
        {'name': 'Wadhwa Mumbai', 'status': 'active', 'created_at': DateTime.now().toIso8601String()},
        {'name': 'Pilot South', 'status': 'active', 'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
      ];
      _projects = [
        {'project_name': 'The Wadhwa Wise City', 'area': 'Panvel', 'city': 'Mumbai', 'status': 'active'},
        {'project_name': 'Upper Thane', 'area': 'Thane', 'city': 'Mumbai', 'status': 'active'},
      ];
      _riskAlerts = [
        {'event_type': 'paused_org_access_attempt', 'severity': 'critical', 'status': 'open'},
        {'event_type': 'gps_outside_geofence_repeated', 'severity': 'high', 'status': 'open'},
      ];
      _activity = [
        {'event_type': 'organization_created', 'created_at': DateTime.now().subtract(const Duration(minutes: 22)).toIso8601String()},
        {'event_type': 'invite_created', 'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
        {'event_type': 'user_activated', 'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Super Admin Panel',
          style: PremiumUI.h1.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: PremiumUI.statusBadge(
                (_kpis['System Health'] ?? 0) > 0 ? 'Attention' : 'Healthy',
                (_kpis['System Health'] ?? 0) > 0 ? PremiumUI.warning : PremiumUI.secondary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _topStrip(),
                  const SizedBox(height: 18),
                  _kpiGrid(),
                  const SizedBox(height: 18),
                  _quickActions(context),
                  const SizedBox(height: 18),
                  PremiumUI.sectionShell(
                    title: 'Organizations',
                    subtitle: 'Safe org metadata and activation status only',
                    accentColor: PremiumUI.primary,
                    child: _listRows(
                      _organizations,
                      (row) => row['name']?.toString() ?? 'Organization',
                      (row) => row['status']?.toString() ?? 'pending',
                    ),
                  ),
                  const SizedBox(height: 18),
                  PremiumUI.sectionShell(
                    title: 'Projects',
                    subtitle: 'Live project registry and operating areas',
                    accentColor: PremiumUI.accent,
                    child: _listRows(
                      _projects,
                      (row) => row['project_name']?.toString() ?? 'Project',
                      (row) => '${row['area'] ?? '-'}, ${row['city'] ?? '-'}',
                      trailing: (row) => PremiumUI.statusBadge(
                        (row['status'] ?? 'inactive').toString(),
                        PremiumUI.statusColor((row['status'] ?? 'inactive').toString()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PremiumUI.sectionShell(
                          title: 'Risk Alerts',
                          subtitle: 'Recent high-risk abuse events',
                          accentColor: PremiumUI.danger,
                          child: _riskTable(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PremiumUI.sectionShell(
                          title: 'Audit Events',
                          subtitle: 'Safe operational trail',
                          accentColor: PremiumUI.warning,
                          child: _auditTimeline(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _topStrip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumUI.panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PremiumUI.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Command Center', style: PremiumUI.h1.copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                const Text(
                  'Organizations, users, projects, risks, and system health in one premium control surface.',
                  style: TextStyle(color: PremiumUI.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          PremiumUI.statusBadge(
            'No PII',
            PremiumUI.secondary,
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid() {
    final entries = _kpis.entries.toList();
    final colors = <Color>[
      PremiumUI.primary,
      PremiumUI.accent,
      PremiumUI.secondary,
      PremiumUI.hot,
      PremiumUI.warning,
      PremiumUI.primary,
      PremiumUI.accent,
      PremiumUI.accent,
      PremiumUI.secondary,
      PremiumUI.hot,
      PremiumUI.warning,
      PremiumUI.danger,
      PremiumUI.secondary,
    ];
    final icons = <IconData>[
      Icons.business_outlined,
      Icons.apartment_outlined,
      Icons.person_pin_circle_outlined,
      Icons.groups_outlined,
      Icons.support_agent_outlined,
      Icons.list_alt_outlined,
      Icons.call_outlined,
      Icons.event_available_outlined,
      Icons.verified_outlined,
      Icons.lock_clock_outlined,
      Icons.gavel_outlined,
      Icons.warning_amber_outlined,
      Icons.monitor_heart_outlined,
    ];

    return GridView.builder(
      itemCount: entries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return PremiumUI.kpiCard(
          entry.key,
          entry.value.toString(),
          icons[index],
          colors[index],
        );
      },
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = <_AdminAction>[
      const _AdminAction('Create Organization', Icons.business_outlined, PremiumUI.primary, OrganizationDashboard()),
      const _AdminAction('Create Project', Icons.apartment_outlined, PremiumUI.accent, OrganizationDashboard()),
      const _AdminAction('Invite User', Icons.person_add_alt_1_outlined, PremiumUI.secondary, InviteUserScreen()),
      const _AdminAction('Assign Role', Icons.manage_accounts_outlined, PremiumUI.hot, RoleManagementScreen()),
      const _AdminAction('View Risk', Icons.policy_outlined, PremiumUI.danger, AbuseMonitoringDashboard()),
      const _AdminAction('View Health', Icons.health_and_safety_outlined, PremiumUI.warning, SystemHealthDashboard()),
      const _AdminAction('Broker Reviews', Icons.rate_review_outlined, PremiumUI.accent, BrokerReviewListScreen()),
      const _AdminAction('Diagnostics', Icons.memory_outlined, PremiumUI.secondary, AdminDiagnosticsScreen()),
    ];

    return PremiumUI.sectionShell(
      title: 'Quick Actions',
      subtitle: 'Protected admin workflows and safe diagnostics only',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions
            .map(
              (action) => InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => action.screen),
                  );
                },
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PremiumUI.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: action.color.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(action.icon, color: action.color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          action.label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _listRows(
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic>) title,
    String Function(Map<String, dynamic>) subtitle, {
    Widget Function(Map<String, dynamic>)? trailing,
  }) {
    if (rows.isEmpty) {
      return const Text('No safe metadata available.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PremiumUI.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title(row), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitle(row), style: const TextStyle(color: PremiumUI.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  trailing == null
                      ? PremiumUI.statusBadge(
                          (row['status'] ?? 'active').toString(),
                          PremiumUI.statusColor((row['status'] ?? 'active').toString()),
                        )
                      : trailing(row),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _riskTable() {
    if (_riskAlerts.isEmpty) {
      return const Text('No open alerts.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _riskAlerts
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PremiumUI.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['event_type']?.toString().replaceAll('_', ' ') ?? 'risk event',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  PremiumUI.statusBadge(
                    (row['severity'] ?? 'medium').toString(),
                    PremiumUI.statusColor((row['severity'] ?? 'medium').toString()),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _auditTimeline() {
    if (_activity.isEmpty) {
      return const Text('No recent safe audit events.', style: TextStyle(color: PremiumUI.muted));
    }

    return Column(
      children: _activity
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: PremiumUI.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['event_type']?.toString().replaceAll('_', ' ') ?? 'audit event',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatTimestamp(row['created_at']),
                          style: const TextStyle(color: PremiumUI.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatTimestamp(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return 'timestamp unavailable';
    return '${parsed.day}/${parsed.month} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}

class _AdminAction {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _AdminAction(this.label, this.icon, this.color, this.screen);
}
