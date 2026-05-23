class BrokerLock {
  const BrokerLock({
    required this.id,
    required this.leadId,
    required this.brokerId,
    required this.status,
    this.expiresAt,
    this.brokerageStatus,
  });

  final String id;
  final String leadId;
  final String brokerId;
  final String status;
  final DateTime? expiresAt;
  final String? brokerageStatus;

  factory BrokerLock.fromJson(Map<String, dynamic> json) {
    return BrokerLock(
      id: json['id']?.toString() ?? '',
      leadId: json['lead_id']?.toString() ?? '',
      brokerId: json['broker_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      brokerageStatus: json['brokerage_status']?.toString(),
    );
  }
}
