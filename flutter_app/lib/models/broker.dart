class Broker {
  const Broker({
    required this.id,
    required this.alias,
    required this.status,
    this.companyName,
    this.area,
    this.city,
    this.trustScore,
  });

  final String id;
  final String alias;
  final String status;
  final String? companyName;
  final String? area;
  final String? city;
  final num? trustScore;

  factory Broker.fromJson(Map<String, dynamic> json) {
    return Broker(
      id: json['id']?.toString() ?? '',
      alias: json['broker_alias']?.toString() ??
          json['broker_name']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      companyName: json['company_name']?.toString(),
      area: json['area']?.toString(),
      city: json['city']?.toString(),
      trustScore:
          json['trust_score'] is num ? json['trust_score'] as num : null,
    );
  }
}
