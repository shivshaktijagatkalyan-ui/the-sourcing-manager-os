import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/super_admin_snapshot.dart';
import '../services/super_admin_dashboard_service.dart';
import '../utils/premium_ui.dart';
import '../widgets/super_admin/attention_queue_card.dart';
import '../widgets/super_admin/audit_timeline_card.dart';
import '../widgets/super_admin/organization_card.dart';
import '../widgets/super_admin/platform_health_card.dart';
import '../widgets/super_admin/project_health_card.dart';
import '../widgets/super_admin/quick_action_panel.dart';
import '../widgets/super_admin/risk_alert_card.dart';
import '../widgets/super_admin/trust_operations_card.dart';
import '../widgets/super_admin/workflow_bottleneck_card.dart';
import '../widgets/super_admin/workforce_performance_card.dart';
import 'abuse_monitoring_dashboard.dart';
import 'admin_diagnostics_screen.dart';
import 'broker_review_list.dart';
import 'caller_lead_queue_screen.dart';
import 'invite_user_screen.dart';
import 'organization_onboarding_wizard.dart';
import 'payout_ledger_screen.dart';
import 'role_management_screen.dart';
import 'sourcing_manager_dashboard.dart';
import 'system_health_dashboard.dart';

class SuperAdminDashboard extends StatefulWidget {
  final SuperAdminDashboardSnapshot? initialSnapshot;
  final String? initialErrorReason;

  const SuperAdminDashboard({
    super.key,
    this.initialSnapshot,
    this.initialErrorReason,
  });

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool _isLoading = true;
  SuperAdminDashboardSnapshot? _snapshot;
  String? _errorReason;

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _snapshot = widget.initialSnapshot;
      _isLoading = false;
    } else if (widget.initialErrorReason != null) {
      _errorReason = widget.initialErrorReason;
      _isLoading = false;
    } else {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorReason = null;
    });

    try {
      if (AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode) {
        await _loadLive();
      } else {
        await _loadDemo();
      }
    } on SuperAdminDashboardException catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _errorReason = error.reason;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _errorReason = 'dashboard_unavailable';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLive() async {
    final snapshot = await SuperAdminDashboardService().loadSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _errorReason = null;
      _isLoading = false;
    });
  }

  Future<void> _loadDemo() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _snapshot = buildDemoSuperAdminSnapshot();
      _errorReason = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final status = normalizedDashboardBadge(
      snapshot?.platformHealth.status ?? 'unknown',
    );

    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Real Estate Operations Control Room',
          style: PremiumUI.h1.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: PremiumUI.statusBadge(
                status == 'healthy' ? 'Healthy' : 'Attention',
                status == 'healthy' ? PremiumUI.secondary : PremiumUI.warning,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : snapshot == null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _topStrip(snapshot),
                      const SizedBox(height: 18),
                      PlatformHealthCard(health: snapshot.platformHealth),
                      const SizedBox(height: 18),
                      _kpiGrid(snapshot),
                      const SizedBox(height: 18),
                      QuickActionPanel(
                        allowedActions: snapshot.allowedActions,
                        actions: _quickActions(),
                      ),
                      const SizedBox(height: 18),
                      AttentionQueueCard(
                        items: snapshot.attentionQueue,
                        canOpen: (item) =>
                            _destinationForAttention(
                              item,
                              snapshot.allowedActions,
                            ) !=
                            null,
                        onOpen: (item) =>
                            _openAttention(item, snapshot.allowedActions),
                      ),
                      const SizedBox(height: 18),
                      WorkflowBottleneckCard(
                        bottlenecks: snapshot.workflowBottlenecks,
                        onOpen: (item) => _openRoute(
                          item.route,
                          item.action,
                          snapshot.allowedActions,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _workflowSummary(snapshot.workflowSummary),
                      const SizedBox(height: 18),
                      WorkforcePerformanceCard(workforce: snapshot.workforce),
                      const SizedBox(height: 18),
                      OrganizationCard(organizations: snapshot.organizations),
                      const SizedBox(height: 18),
                      ProjectHealthCard(projects: snapshot.projects),
                      const SizedBox(height: 18),
                      _trustAndRisk(snapshot),
                      const SizedBox(height: 18),
                      AuditTimelineCard(events: snapshot.auditEvents),
                    ],
                  ),
                ),
    );
  }

  Widget _errorState() {
    final reason = _errorReason ?? 'dashboard_unavailable';
    final safeReason = _safeReasonCode(reason);
    final restricted = safeReason == 'forbidden_permission_required';

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumUI.sectionShell(
            title: restricted ? 'Access Restricted' : 'Dashboard Unavailable',
            subtitle: restricted
                ? 'Platform admin or ops admin permission is required.'
                : 'The dashboard service returned a deterministic failure.',
            accentColor: restricted ? PremiumUI.warning : PremiumUI.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorLabel(safeReason),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: $safeReason',
                  style: const TextStyle(color: PremiumUI.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topStrip(SuperAdminDashboardSnapshot snapshot) {
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
                Text(
                  'FutureTrust Command Center',
                  style: PremiumUI.h1.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Generated ${_formatTimestamp(snapshot.generatedAt)}. Read, route, govern, audit.',
                  style: const TextStyle(color: PremiumUI.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          PremiumUI.statusBadge('Safe Metadata', PremiumUI.secondary),
        ],
      ),
    );
  }

  Widget _kpiGrid(SuperAdminDashboardSnapshot snapshot) {
    final kpiMeta = [
      (
        label: 'Organizations',
        key: 'organizations',
        icon: Icons.business_outlined,
        color: PremiumUI.primary
      ),
      (
        label: 'Active Projects',
        key: 'active_projects',
        icon: Icons.apartment_outlined,
        color: PremiumUI.accent
      ),
      (
        label: 'Active Brokers',
        key: 'active_brokers',
        icon: Icons.groups_outlined,
        color: PremiumUI.hot
      ),
      (
        label: 'Active Callers',
        key: 'active_callers',
        icon: Icons.support_agent_outlined,
        color: PremiumUI.secondary
      ),
      (
        label: 'Active SMs',
        key: 'active_sms',
        icon: Icons.manage_accounts_outlined,
        color: PremiumUI.secondary
      ),
      (
        label: 'Leads Today',
        key: 'leads_today',
        icon: Icons.list_alt_outlined,
        color: PremiumUI.primary
      ),
      (
        label: 'Verified Visits',
        key: 'verified_visits_today',
        icon: Icons.verified_outlined,
        color: PremiumUI.secondary
      ),
      (
        label: 'Broker Locks',
        key: 'active_broker_locks',
        icon: Icons.lock_clock_outlined,
        color: PremiumUI.hot
      ),
      (
        label: 'Open Risks',
        key: 'open_risks',
        icon: Icons.warning_amber_outlined,
        color: PremiumUI.danger
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 1
            : constraints.maxWidth < 980
                ? 2
                : 3;
        return GridView.builder(
          itemCount: kpiMeta.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 2.4 : 1.65,
          ),
          itemBuilder: (context, index) {
            final meta = kpiMeta[index];
            return PremiumUI.kpiCard(
              meta.label,
              _kpiValue(snapshot, meta.key).toString(),
              meta.icon,
              meta.color,
            );
          },
        );
      },
    );
  }

  int _kpiValue(SuperAdminDashboardSnapshot snapshot, String key) {
    final aliases = {
      'organizations': ['organizations', 'total_organizations'],
      'active_brokers': ['active_brokers', 'total_brokers'],
      'active_broker_locks': ['active_broker_locks', 'active_locks'],
      'open_risks': ['open_risks', 'open_risk_alerts'],
    };
    for (final candidate in aliases[key] ?? [key]) {
      final value = snapshot.kpi(candidate);
      if (value != 0) return value;
    }
    return 0;
  }

  Widget _workflowSummary(AdminWorkflowSummary summary) {
    final cards = [
      (
        label: 'Lead Intake Today',
        value: summary.leadIntakeToday,
        icon: Icons.input_outlined,
        color: PremiumUI.primary
      ),
      (
        label: 'Secure Calls Today',
        value: summary.secureCallsToday,
        icon: Icons.call_outlined,
        color: PremiumUI.accent
      ),
      (
        label: 'Site Visits Today',
        value: summary.siteVisitsToday,
        icon: Icons.event_available_outlined,
        color: PremiumUI.secondary
      ),
      (
        label: 'Proofs Pending',
        value: summary.proofsPending,
        icon: Icons.fact_check_outlined,
        color: PremiumUI.warning
      ),
      (
        label: 'Locks Created Today',
        value: summary.locksCreatedToday,
        icon: Icons.lock_outline,
        color: PremiumUI.hot
      ),
      (
        label: 'Payouts Pending',
        value: summary.payoutsPendingReview,
        icon: Icons.payments_outlined,
        color: PremiumUI.danger
      ),
    ];

    return PremiumUI.sectionShell(
      title: 'Workflow Summary',
      subtitle: 'Read-only counters across the sales and trust pipeline',
      accentColor: PremiumUI.accent,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map(
              (card) => SizedBox(
                width: 190,
                child: PremiumUI.kpiCard(
                  card.label,
                  card.value.toString(),
                  card.icon,
                  card.color,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _trustAndRisk(SuperAdminDashboardSnapshot snapshot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trust = TrustOperationsCard(
          rows: snapshot.trustOperations,
          onOpen: (item) => _openRoute(
            item.route,
            item.action,
            snapshot.allowedActions,
          ),
        );
        final risk = RiskAlertCard(
          alerts: snapshot.riskAlerts,
          onOpen: (item) => _openRoute(
            item.route,
            item.action,
            snapshot.allowedActions,
          ),
        );
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              trust,
              const SizedBox(height: 18),
              risk,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: trust),
            const SizedBox(width: 18),
            Expanded(child: risk),
          ],
        );
      },
    );
  }

  List<SuperAdminQuickAction> _quickActions() {
    return [
      SuperAdminQuickAction(
        label: 'Create Organization',
        icon: Icons.business_outlined,
        color: PremiumUI.primary,
        allowedBy: const {'manage_organizations', 'can_manage_org_users'},
        onTap: () => _push(const OrganizationOnboardingWizard()),
      ),
      SuperAdminQuickAction(
        label: 'Invite User',
        icon: Icons.person_add_alt_1_outlined,
        color: PremiumUI.secondary,
        allowedBy: const {'invite_users', 'can_manage_org_users'},
        onTap: () => _push(const InviteUserScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Assign Role',
        icon: Icons.manage_accounts_outlined,
        color: PremiumUI.hot,
        allowedBy: const {'assign_roles', 'can_manage_org_users'},
        onTap: () => _push(const RoleManagementScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Open Risk Dashboard',
        icon: Icons.policy_outlined,
        color: PremiumUI.danger,
        allowedBy: const {'view_risk_dashboard', 'can_view_risk_dashboard'},
        onTap: () => _push(const AbuseMonitoringDashboard()),
      ),
      SuperAdminQuickAction(
        label: 'Open Diagnostics',
        icon: Icons.memory_outlined,
        color: PremiumUI.secondary,
        allowedBy: const {'view_diagnostics'},
        onTap: () => _push(const AdminDiagnosticsScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Open Assignment Queue',
        icon: Icons.assignment_ind_outlined,
        color: PremiumUI.accent,
        allowedBy: const {'open_assignment_queue', 'view_workforce_reports'},
        onTap: () => _push(const CallerLeadQueueScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Open Broker Locks',
        icon: Icons.lock_clock_outlined,
        color: PremiumUI.primary,
        allowedBy: const {'view_broker_locks', 'can_view_payouts'},
        onTap: () => _push(const PayoutLedgerScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Open System Health',
        icon: Icons.health_and_safety_outlined,
        color: PremiumUI.warning,
        allowedBy: const {'view_system_health'},
        onTap: () => _push(const SystemHealthDashboard()),
      ),
      SuperAdminQuickAction(
        label: 'Open Release Gate Report',
        icon: Icons.verified_user_outlined,
        color: PremiumUI.secondary,
        allowedBy: const {'view_platform_health', 'view_diagnostics'},
        onTap: () => _push(const AdminDiagnosticsScreen()),
      ),
      SuperAdminQuickAction(
        label: 'Open Visit Reviews',
        icon: Icons.rate_review_outlined,
        color: PremiumUI.accent,
        allowedBy: const {'can_review_site_visits', 'broker_reviews'},
        onTap: () => _push(const BrokerReviewListScreen()),
      ),
    ];
  }

  void _openRoute(String route, String action, List<String> allowedActions) {
    final destination = _destinationFor(route, action, allowedActions);
    if (destination != null) _push(destination);
  }

  void _openAttention(
    AdminAttentionItem item,
    List<String> allowedActions,
  ) {
    final destination = _destinationForAttention(item, allowedActions);
    if (destination != null) _push(destination);
  }

  Widget? _destinationForAttention(
    AdminAttentionItem item,
    List<String> allowedActions,
  ) {
    if (item.route.isNotEmpty || item.action.isNotEmpty) {
      final routed = _destinationFor(item.route, item.action, allowedActions);
      if (routed != null) return routed;
    }

    switch (item.type) {
      case 'abuse_event':
      case 'duplicate_risk':
      case 'gps_failure':
      case 'risk_alert':
        return _destinationFor('risk_center', 'review_risk', allowedActions);
      case 'failed_callback':
      case 'held_sync_review':
      case 'stuck_visit':
        return _destinationFor(
          'diagnostics',
          'open_diagnostics',
          allowedActions,
        );
      case 'system_health':
        return _destinationFor(
          'system_health',
          'open_system_health',
          allowedActions,
        );
      default:
        return null;
    }
  }

  Widget? _destinationFor(
    String route,
    String action,
    List<String> allowedActions,
  ) {
    final allowed = allowedActions.toSet();
    bool hasAny(Set<String> actions) => actions.any(allowed.contains);

    switch (route) {
      case 'risk_center':
        return hasAny({
          'view_risk_dashboard',
          'can_view_risk_dashboard',
          'review_risk',
        })
            ? const AbuseMonitoringDashboard()
            : null;
      case 'assignment_queue':
        return hasAny({
          'open_assignment_queue',
          'view_workforce_reports',
          'reassign_caller',
          'escalate_to_sm',
        })
            ? const CallerLeadQueueScreen()
            : null;
      case 'diagnostics':
        return hasAny({'view_diagnostics', 'open_diagnostics'})
            ? const AdminDiagnosticsScreen()
            : null;
      case 'system_health':
        return hasAny({'view_system_health', 'open_system_health'})
            ? const SystemHealthDashboard()
            : null;
      case 'broker_locks':
        return hasAny({
          'view_broker_locks',
          'can_view_payouts',
          'open_broker_locks',
        })
            ? const PayoutLedgerScreen()
            : null;
      case 'organization_control':
        return hasAny({'manage_organizations', 'can_manage_org_users'})
            ? const OrganizationOnboardingWizard()
            : null;
      case 'workforce_reports':
        return hasAny({'view_workforce_reports'})
            ? const SourcingManagerDashboard()
            : null;
      default:
        if (action == 'review_risk') {
          return hasAny({'view_risk_dashboard', 'can_view_risk_dashboard'})
              ? const AbuseMonitoringDashboard()
              : null;
        }
        return null;
    }
  }

  void _push(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return 'timestamp unavailable';
    return '${value.day}/${value.month} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _safeReasonCode(String value) {
    final reason = value.trim();
    const known = {
      'unauthorized',
      'forbidden_permission_required',
      'access_blocked_operational',
      'dashboard_read_failed',
      'dashboard_unavailable',
      'invalid_response',
    };
    return known.contains(reason) ? reason : 'dashboard_error';
  }

  String _errorLabel(String reason) {
    switch (reason) {
      case 'unauthorized':
        return 'Sign in is required.';
      case 'forbidden_permission_required':
        return 'Platform admin access is required.';
      case 'access_blocked_operational':
        return 'The organization or user status is blocked.';
      case 'dashboard_read_failed':
        return 'Dashboard data could not be read.';
      case 'dashboard_unavailable':
        return 'Dashboard data is unavailable.';
      case 'dashboard_error':
        return 'Dashboard request failed.';
      default:
        return 'Dashboard request was not approved.';
    }
  }
}

SuperAdminDashboardSnapshot buildDemoSuperAdminSnapshot() {
  final now = DateTime.now();
  return SuperAdminDashboardSnapshot(
    generatedAt: now,
    platformHealth: const AdminPlatformHealth(
      status: 'warning',
      failedFunctions: 1,
      providerFailures: 0,
      callbackFailures: 2,
      lastReleaseGate: 'pass',
      migrationDrift: 'unknown',
      securityScanStatus: 'pass',
      lastEvent: 'held_sync_review',
    ),
    health: const AdminHealth(
      status: 'warning',
      lastEvent: 'held_sync_review',
      criticalFailures1h: 1,
    ),
    kpis: const {
      'organizations': 4,
      'active_projects': 8,
      'active_brokers': 156,
      'active_callers': 42,
      'active_sms': 12,
      'leads_today': 32,
      'verified_visits_today': 9,
      'active_broker_locks': 28,
      'open_risks': 2,
      'total_organizations': 4,
      'total_brokers': 156,
      'active_locks': 28,
      'open_risk_alerts': 2,
    },
    organizations: [
      AdminOrganizationRow(
        id: 'org_demo_developer',
        name: 'Demo Developer Group',
        status: 'active',
        projectsCount: 5,
        activeUsers: 18,
        openRiskAlerts: 1,
        billingStatus: 'active',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      AdminOrganizationRow(
        id: 'org_pilot_west',
        name: 'Pilot West Region',
        status: 'active',
        projectsCount: 3,
        activeUsers: 11,
        openRiskAlerts: 0,
        billingStatus: 'active',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ],
    projects: const [
      AdminProjectRow(
        id: 'project_harbor_heights',
        name: 'Harbor Heights',
        city: 'Mumbai',
        area: 'Worli',
        status: 'active',
        activeLeads: 84,
        verifiedVisits: 12,
        activeBrokers: 31,
        inventoryUnits: 120,
        conversionRate: 14,
        inventoryStatus: 'active',
        freeLeadBankStatus: 'healthy',
      ),
      AdminProjectRow(
        id: 'project_green_court',
        name: 'Green Court Residences',
        city: 'Pune',
        area: 'Baner',
        status: 'active',
        activeLeads: 57,
        verifiedVisits: 9,
        activeBrokers: 24,
        inventoryUnits: 80,
        conversionRate: 16,
        inventoryStatus: 'active',
        freeLeadBankStatus: 'warning',
      ),
    ],
    attentionQueue: [
      AdminAttentionItem(
        id: 'attention_gps_variance',
        type: 'gps_failure',
        severity: 'high',
        title: 'Repeated GPS variance',
        reasonCode: 'gps_variance_repeated',
        organizationId: 'org_demo_developer',
        safeRef: 'risk:demo-001',
        action: 'review_risk',
        route: 'risk_center',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      AdminAttentionItem(
        id: 'attention_sync_review',
        type: 'stuck_visit',
        severity: 'medium',
        title: 'Held sync review pending',
        reasonCode: 'manual_review_required',
        organizationId: 'org_pilot_west',
        safeRef: 'visit:demo-014',
        action: 'open_diagnostics',
        route: 'diagnostics',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ],
    workflowSummary: const AdminWorkflowSummary(
      leadIntakeToday: 32,
      secureCallsToday: 21,
      siteVisitsToday: 9,
      proofsPending: 6,
      locksCreatedToday: 5,
      payoutsPendingReview: 2,
      unassignedLeads: 7,
      overloadedCallers: 2,
      idleCallers: 4,
      delayedFollowups: 5,
      stuckVisits: 3,
    ),
    workforce: const AdminWorkforceSnapshot(
      brokers: [
        AdminPerformanceRow(
          id: 'broker_demo_1',
          label: 'Broker Cluster A',
          role: 'broker',
          status: 'active',
          riskLevel: 'low',
          efficiencyScore: 82,
          metrics: {
            'leads': 44,
            'visits': 12,
            'locks': 5,
            'trust': 88,
          },
        ),
      ],
      callers: [
        AdminPerformanceRow(
          id: 'caller_demo_1',
          label: 'Caller Team West',
          role: 'caller',
          status: 'active',
          riskLevel: 'medium',
          efficiencyScore: 74,
          metrics: {
            'assigned': 31,
            'attempted': 26,
            'connected': 18,
            'interested': 9,
          },
        ),
      ],
      sourcingManagers: [
        AdminPerformanceRow(
          id: 'sm_demo_1',
          label: 'SM Team Mumbai',
          role: 'sourcing_manager',
          status: 'active',
          riskLevel: 'low',
          efficiencyScore: 86,
          metrics: {
            'meetings': 8,
            'scheduled': 11,
            'verified': 7,
            'projects': 4,
          },
        ),
      ],
    ),
    workflowBottlenecks: [
      AdminOperationalRow(
        id: 'bottleneck_unassigned',
        type: 'stuck_lead',
        severity: 'high',
        title: 'Leads waiting for caller assignment',
        safeRef: 'queue:assignment',
        action: 'open_assignment_queue',
        route: 'assignment_queue',
        metrics: const {'count': 7},
        createdAt: now.subtract(const Duration(minutes: 11)),
      ),
    ],
    trustOperations: [
      AdminOperationalRow(
        id: 'trust_lock_review',
        type: 'broker_lock',
        severity: 'medium',
        title: 'Broker locks pending payout review',
        safeRef: 'locks:pending',
        action: 'open_broker_locks',
        route: 'broker_locks',
        metrics: const {'count': 2},
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ],
    riskAlerts: [
      AdminOperationalRow(
        id: 'risk_duplicate_uploads',
        type: 'duplicate_risk',
        severity: 'high',
        title: 'Duplicate upload pattern detected',
        safeRef: 'risk:duplicate',
        action: 'review_risk',
        route: 'risk_center',
        metrics: const {'count': 3},
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ],
    auditEvents: [
      AdminAuditEventRow(
        id: 'audit_org_created',
        eventType: 'organization_created',
        actorRole: 'platform_admin',
        organizationId: 'org_demo_developer',
        createdAt: now.subtract(const Duration(minutes: 22)),
      ),
      AdminAuditEventRow(
        id: 'audit_invite_created',
        eventType: 'invite_created',
        actorRole: 'platform_admin',
        organizationId: 'org_pilot_west',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ],
    allowedActions: const [
      'view_super_admin_dashboard',
      'view_platform_health',
      'view_risk_dashboard',
      'view_system_health',
      'view_diagnostics',
      'view_workforce_reports',
      'open_assignment_queue',
      'view_broker_locks',
      'manage_organizations',
      'invite_users',
      'assign_roles',
      'can_review_site_visits',
    ],
  );
}
