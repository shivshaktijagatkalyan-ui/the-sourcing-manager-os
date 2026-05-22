class SuperAdminDashboardSnapshot {
  final DateTime generatedAt;
  final AdminPlatformHealth platformHealth;
  final AdminHealth health;
  final Map<String, int> kpis;
  final List<AdminOrganizationRow> organizations;
  final List<AdminProjectRow> projects;
  final List<AdminAttentionItem> attentionQueue;
  final AdminWorkflowSummary workflowSummary;
  final AdminWorkforceSnapshot workforce;
  final List<AdminOperationalRow> workflowBottlenecks;
  final List<AdminOperationalRow> trustOperations;
  final List<AdminOperationalRow> riskAlerts;
  final List<AdminAuditEventRow> auditEvents;
  final List<String> allowedActions;

  const SuperAdminDashboardSnapshot({
    required this.generatedAt,
    this.platformHealth = const AdminPlatformHealth(
      status: 'unknown',
      failedFunctions: 0,
      providerFailures: 0,
      callbackFailures: 0,
      lastReleaseGate: 'unknown',
      migrationDrift: 'unknown',
      securityScanStatus: 'unknown',
      lastEvent: 'none',
    ),
    required this.health,
    required this.kpis,
    required this.organizations,
    required this.projects,
    required this.attentionQueue,
    required this.workflowSummary,
    this.workforce = const AdminWorkforceSnapshot(
      brokers: [],
      callers: [],
      sourcingManagers: [],
    ),
    this.workflowBottlenecks = const [],
    this.trustOperations = const [],
    this.riskAlerts = const [],
    required this.auditEvents,
    required this.allowedActions,
  });

  factory SuperAdminDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final platformHealthJson = _map(json['platform_health']);
    final legacyHealthJson = _map(json['health']);
    final platformHealth = AdminPlatformHealth.fromJson(
      platformHealthJson.isEmpty ? legacyHealthJson : platformHealthJson,
    );

    return SuperAdminDashboardSnapshot(
      generatedAt:
          _date(json['generated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      platformHealth: platformHealth,
      health: AdminHealth.fromPlatform(platformHealth, legacyHealthJson),
      kpis: _intMap(json['kpis']),
      organizations: _list(json['organizations'])
          .map(AdminOrganizationRow.fromJson)
          .toList(),
      projects: _list(json['projects']).map(AdminProjectRow.fromJson).toList(),
      attentionQueue: _list(json['attention_queue'])
          .map(AdminAttentionItem.fromJson)
          .toList(),
      workflowSummary:
          AdminWorkflowSummary.fromJson(_map(json['workflow_summary'])),
      workforce: AdminWorkforceSnapshot.fromJson(_map(json['workforce'])),
      workflowBottlenecks: _list(json['workflow_bottlenecks'])
          .map(AdminOperationalRow.fromJson)
          .toList(),
      trustOperations: _list(json['trust_operations'])
          .map(AdminOperationalRow.fromJson)
          .toList(),
      riskAlerts:
          _list(json['risk_alerts']).map(AdminOperationalRow.fromJson).toList(),
      auditEvents:
          _list(json['audit_events']).map(AdminAuditEventRow.fromJson).toList(),
      allowedActions: _stringList(json['allowed_actions']),
    );
  }

  int kpi(String key) => kpis[key] ?? 0;

  String toSearchableText() {
    return redactDashboardText([
      platformHealth.status,
      platformHealth.lastReleaseGate,
      platformHealth.migrationDrift,
      platformHealth.securityScanStatus,
      health.status,
      health.lastEvent,
      ...kpis.keys,
      ...organizations.expand(
        (row) => [
          row.id,
          row.name,
          normalizedDashboardBadge(row.status),
          row.billingStatus,
        ],
      ),
      ...projects.expand(
        (row) => [
          row.id,
          row.name,
          row.city,
          row.area,
          normalizedDashboardBadge(row.status),
          row.inventoryStatus,
          row.freeLeadBankStatus,
        ],
      ),
      ...attentionQueue.expand(
        (row) => [
          row.id,
          row.type,
          normalizedDashboardBadge(row.severity),
          row.title,
          row.safeRef,
          row.action,
          row.route,
        ],
      ),
      ...workforce.toSearchParts(),
      ...workflowBottlenecks.expand((row) => row.toSearchParts()),
      ...trustOperations.expand((row) => row.toSearchParts()),
      ...riskAlerts.expand((row) => row.toSearchParts()),
      ...auditEvents.expand(
        (row) => [row.id, row.eventType, row.actorRole, row.organizationId],
      ),
      ...allowedActions,
    ].join(' '));
  }
}

String redactDashboardText(String value) {
  return value
      .replaceAll(
        RegExp(
          r'(?<![A-Za-z0-9])(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}(?![A-Za-z0-9])',
        ),
        '[redacted-value]',
      )
      .replaceAll(
        RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
        '[redacted-email]',
      );
}

String normalizedDashboardBadge(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
  const allowed = {
    'active',
    'inactive',
    'pending',
    'paused',
    'blocked',
    'suspended',
    'archived',
    'verified',
    'completed',
    'approved',
    'scheduled',
    'assigned',
    'critical',
    'high',
    'medium',
    'low',
    'info',
    'healthy',
    'warning',
    'degraded',
    'incident',
    'pass',
    'fail',
    'unknown',
  };
  return allowed.contains(normalized) ? normalized : 'unknown';
}

class AdminPlatformHealth {
  final String status;
  final int failedFunctions;
  final int providerFailures;
  final int callbackFailures;
  final String lastReleaseGate;
  final String migrationDrift;
  final String securityScanStatus;
  final String lastEvent;

  const AdminPlatformHealth({
    required this.status,
    required this.failedFunctions,
    required this.providerFailures,
    required this.callbackFailures,
    required this.lastReleaseGate,
    required this.migrationDrift,
    required this.securityScanStatus,
    required this.lastEvent,
  });

  factory AdminPlatformHealth.fromJson(Map<String, dynamic> json) {
    return AdminPlatformHealth(
      status: _string(json['status'], 'unknown'),
      failedFunctions:
          _int(json['failed_functions'] ?? json['critical_failures_1h']),
      providerFailures: _int(json['provider_failures']),
      callbackFailures: _int(json['callback_failures']),
      lastReleaseGate: _string(json['last_release_gate'], 'unknown'),
      migrationDrift: _string(json['migration_drift'], 'unknown'),
      securityScanStatus: _string(json['security_scan_status'], 'unknown'),
      lastEvent: _string(json['last_event'], 'none'),
    );
  }
}

class AdminHealth {
  final String status;
  final String lastEvent;
  final int criticalFailures1h;

  const AdminHealth({
    required this.status,
    required this.lastEvent,
    required this.criticalFailures1h,
  });

  factory AdminHealth.fromPlatform(
    AdminPlatformHealth platformHealth,
    Map<String, dynamic> legacyJson,
  ) {
    return AdminHealth(
      status: _string(legacyJson['status'], platformHealth.status),
      lastEvent: _string(legacyJson['last_event'], platformHealth.lastEvent),
      criticalFailures1h: _int(
        legacyJson['critical_failures_1h'] ?? platformHealth.failedFunctions,
      ),
    );
  }
}

class AdminOrganizationRow {
  final String id;
  final String name;
  final String status;
  final int projectsCount;
  final int activeUsers;
  final int openRiskAlerts;
  final String billingStatus;
  final DateTime? createdAt;

  const AdminOrganizationRow({
    required this.id,
    required this.name,
    required this.status,
    this.projectsCount = 0,
    required this.activeUsers,
    required this.openRiskAlerts,
    this.billingStatus = 'unknown',
    required this.createdAt,
  });

  factory AdminOrganizationRow.fromJson(Map<String, dynamic> json) {
    return AdminOrganizationRow(
      id: _string(json['id'], 'unknown_org'),
      name: _string(json['name'], 'Organization'),
      status: _string(json['status'], 'unknown'),
      projectsCount: _int(json['projects_count']),
      activeUsers: _int(json['active_users']),
      openRiskAlerts: _int(json['open_risk_alerts']),
      billingStatus: _string(json['billing_status'], 'unknown'),
      createdAt: _date(json['created_at']),
    );
  }
}

class AdminProjectRow {
  final String id;
  final String name;
  final String city;
  final String area;
  final String status;
  final int activeLeads;
  final int verifiedVisits;
  final int activeBrokers;
  final int inventoryUnits;
  final int conversionRate;
  final String inventoryStatus;
  final String freeLeadBankStatus;

  const AdminProjectRow({
    required this.id,
    required this.name,
    required this.city,
    required this.area,
    required this.status,
    required this.activeLeads,
    required this.verifiedVisits,
    this.activeBrokers = 0,
    this.inventoryUnits = 0,
    this.conversionRate = 0,
    this.inventoryStatus = 'unknown',
    this.freeLeadBankStatus = 'unknown',
  });

  factory AdminProjectRow.fromJson(Map<String, dynamic> json) {
    return AdminProjectRow(
      id: _string(json['id'], 'unknown_project'),
      name: _string(json['name'], 'Project'),
      city: _string(json['city'], '-'),
      area: _string(json['area'], '-'),
      status: _string(json['status'], 'unknown'),
      activeLeads: _int(json['active_leads']),
      verifiedVisits: _int(json['verified_visits']),
      activeBrokers: _int(json['active_brokers']),
      inventoryUnits: _int(json['inventory_units']),
      conversionRate: _int(json['conversion_rate']),
      inventoryStatus: _string(json['inventory_status'], 'unknown'),
      freeLeadBankStatus: _string(json['free_lead_bank_status'], 'unknown'),
    );
  }
}

class AdminAttentionItem {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String reasonCode;
  final String organizationId;
  final String safeRef;
  final String action;
  final String route;
  final DateTime? createdAt;

  const AdminAttentionItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.reasonCode,
    required this.organizationId,
    this.safeRef = '',
    this.action = '',
    this.route = '',
    required this.createdAt,
  });

  factory AdminAttentionItem.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id'], 'unknown_attention');
    final reason = _string(json['reason_code'], _string(json['action'], ''));
    return AdminAttentionItem(
      id: id,
      type: _string(json['type'], 'unknown'),
      severity: _string(json['severity'], 'medium'),
      title: _string(json['title'], 'Attention item'),
      reasonCode: reason.isEmpty ? 'unspecified' : reason,
      organizationId: _string(json['organization_id'], ''),
      safeRef: _string(json['safe_ref'], id),
      action: _string(json['action'], reason.isEmpty ? 'review' : reason),
      route: _string(json['route'], ''),
      createdAt: _date(json['created_at']),
    );
  }
}

class AdminWorkflowSummary {
  final int leadIntakeToday;
  final int secureCallsToday;
  final int siteVisitsToday;
  final int proofsPending;
  final int locksCreatedToday;
  final int payoutsPendingReview;
  final int unassignedLeads;
  final int overloadedCallers;
  final int idleCallers;
  final int delayedFollowups;
  final int stuckVisits;

  const AdminWorkflowSummary({
    required this.leadIntakeToday,
    required this.secureCallsToday,
    required this.siteVisitsToday,
    required this.proofsPending,
    required this.locksCreatedToday,
    required this.payoutsPendingReview,
    this.unassignedLeads = 0,
    this.overloadedCallers = 0,
    this.idleCallers = 0,
    this.delayedFollowups = 0,
    this.stuckVisits = 0,
  });

  factory AdminWorkflowSummary.fromJson(Map<String, dynamic> json) {
    return AdminWorkflowSummary(
      leadIntakeToday: _int(json['lead_intake_today']),
      secureCallsToday: _int(json['secure_calls_today']),
      siteVisitsToday: _int(json['site_visits_today']),
      proofsPending: _int(json['proofs_pending']),
      locksCreatedToday: _int(json['locks_created_today']),
      payoutsPendingReview: _int(json['payouts_pending_review']),
      unassignedLeads: _int(json['unassigned_leads']),
      overloadedCallers: _int(json['overloaded_callers']),
      idleCallers: _int(json['idle_callers']),
      delayedFollowups: _int(json['delayed_followups']),
      stuckVisits: _int(json['stuck_visits']),
    );
  }
}

class AdminWorkforceSnapshot {
  final List<AdminPerformanceRow> brokers;
  final List<AdminPerformanceRow> callers;
  final List<AdminPerformanceRow> sourcingManagers;

  const AdminWorkforceSnapshot({
    required this.brokers,
    required this.callers,
    required this.sourcingManagers,
  });

  factory AdminWorkforceSnapshot.fromJson(Map<String, dynamic> json) {
    return AdminWorkforceSnapshot(
      brokers:
          _list(json['brokers']).map(AdminPerformanceRow.fromJson).toList(),
      callers:
          _list(json['callers']).map(AdminPerformanceRow.fromJson).toList(),
      sourcingManagers: _list(json['sourcing_managers'])
          .map(AdminPerformanceRow.fromJson)
          .toList(),
    );
  }

  List<String> toSearchParts() {
    return [
      ...brokers.expand((row) => row.toSearchParts()),
      ...callers.expand((row) => row.toSearchParts()),
      ...sourcingManagers.expand((row) => row.toSearchParts()),
    ];
  }
}

class AdminPerformanceRow {
  final String id;
  final String label;
  final String role;
  final String status;
  final String riskLevel;
  final int efficiencyScore;
  final Map<String, int> metrics;

  const AdminPerformanceRow({
    required this.id,
    required this.label,
    required this.role,
    required this.status,
    required this.riskLevel,
    required this.efficiencyScore,
    required this.metrics,
  });

  factory AdminPerformanceRow.fromJson(Map<String, dynamic> json) {
    return AdminPerformanceRow(
      id: _string(json['id'], 'unknown_row'),
      label: _string(json['label'], 'Operator'),
      role: _string(json['role'], 'unknown'),
      status: _string(json['status'], 'unknown'),
      riskLevel: _string(json['risk_level'], 'low'),
      efficiencyScore: _int(json['efficiency_score']),
      metrics: _intMap(json['metrics']),
    );
  }

  List<String> toSearchParts() {
    return [
      id,
      label,
      role,
      normalizedDashboardBadge(status),
      normalizedDashboardBadge(riskLevel),
      ...metrics.keys,
    ];
  }
}

class AdminOperationalRow {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String safeRef;
  final String action;
  final String route;
  final Map<String, int> metrics;
  final DateTime? createdAt;

  const AdminOperationalRow({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.safeRef,
    required this.action,
    required this.route,
    required this.metrics,
    required this.createdAt,
  });

  factory AdminOperationalRow.fromJson(Map<String, dynamic> json) {
    return AdminOperationalRow(
      id: _string(json['id'], 'unknown_operation'),
      type: _string(json['type'], 'operation'),
      severity: _string(json['severity'], 'low'),
      title: _string(json['title'], 'Operational item'),
      safeRef: _string(json['safe_ref'], ''),
      action: _string(json['action'], 'review'),
      route: _string(json['route'], ''),
      metrics: _intMap(json['metrics']),
      createdAt: _date(json['created_at']),
    );
  }

  List<String> toSearchParts() {
    return [
      id,
      type,
      normalizedDashboardBadge(severity),
      title,
      safeRef,
      action,
      route,
      ...metrics.keys,
    ];
  }
}

class AdminAuditEventRow {
  final String id;
  final String eventType;
  final String actorRole;
  final String organizationId;
  final DateTime? createdAt;

  const AdminAuditEventRow({
    required this.id,
    required this.eventType,
    required this.actorRole,
    required this.organizationId,
    required this.createdAt,
  });

  factory AdminAuditEventRow.fromJson(Map<String, dynamic> json) {
    return AdminAuditEventRow(
      id: _string(json['id'], 'unknown_audit'),
      eventType: _string(json['event_type'], 'audit_event'),
      actorRole: _string(json['actor_role'], 'unknown_role'),
      organizationId: _string(json['organization_id'], ''),
      createdAt: _date(json['created_at']),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value.map(_map).toList();
}

Map<String, int> _intMap(dynamic value) {
  final map = _map(value);
  return {for (final entry in map.entries) entry.key: _int(entry.value)};
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => _string(item, ''))
      .where((item) => item.isNotEmpty)
      .toList();
}

String _string(dynamic value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

DateTime? _date(dynamic value) {
  return DateTime.tryParse('${value ?? ''}');
}
