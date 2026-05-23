class DashboardSnapshot {
  const DashboardSnapshot({
    required this.generatedAt,
    this.openLeads = 0,
    this.activeLoans = 0,
    this.pendingVisits = 0,
    this.activeLocks = 0,
    this.riskEvents = 0,
  });

  final DateTime generatedAt;
  final int openLeads;
  final int activeLoans;
  final int pendingVisits;
  final int activeLocks;
  final int riskEvents;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      openLeads: int.tryParse(json['open_leads']?.toString() ?? '') ?? 0,
      activeLoans: int.tryParse(json['active_loans']?.toString() ?? '') ?? 0,
      pendingVisits:
          int.tryParse(json['pending_visits']?.toString() ?? '') ?? 0,
      activeLocks: int.tryParse(json['active_locks']?.toString() ?? '') ?? 0,
      riskEvents: int.tryParse(json['risk_events']?.toString() ?? '') ?? 0,
    );
  }
}
