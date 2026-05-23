class SiteVisit {
  const SiteVisit({
    required this.id,
    required this.status,
    this.leadId,
    this.projectId,
    this.scheduledAt,
    this.proofStatus,
  });

  final String id;
  final String status;
  final String? leadId;
  final String? projectId;
  final DateTime? scheduledAt;
  final String? proofStatus;

  factory SiteVisit.fromJson(Map<String, dynamic> json) {
    return SiteVisit(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      leadId: json['lead_id']?.toString() ?? json['source_lead_id']?.toString(),
      projectId: json['project_id']?.toString(),
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? ''),
      proofStatus: json['proof_status']?.toString(),
    );
  }
}
