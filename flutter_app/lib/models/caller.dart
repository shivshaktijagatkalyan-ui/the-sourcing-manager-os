class Caller {
  const Caller({
    required this.id,
    required this.name,
    required this.status,
    this.city,
    this.activeLoans = 0,
  });

  final String id;
  final String name;
  final String status;
  final String? city;
  final int activeLoans;

  factory Caller.fromJson(Map<String, dynamic> json) {
    return Caller(
      id: json['id']?.toString() ?? json['linked_user_id']?.toString() ?? '',
      name: json['caller_name']?.toString() ?? json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      city: json['city']?.toString(),
      activeLoans: int.tryParse(json['active_loans']?.toString() ?? '') ?? 0,
    );
  }
}
