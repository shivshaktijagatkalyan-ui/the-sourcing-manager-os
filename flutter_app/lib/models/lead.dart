class Lead {
  const Lead({
    required this.id,
    required this.alias,
    required this.status,
    this.area,
    this.projectInterest,
    this.budgetRange,
    this.createdAt,
  });

  final String id;
  final String alias;
  final String status;
  final String? area;
  final String? projectInterest;
  final String? budgetRange;
  final DateTime? createdAt;

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id']?.toString() ?? '',
      alias: json['lead_alias']?.toString() ?? json['alias']?.toString() ?? '',
      status:
          json['lead_status']?.toString() ?? json['status']?.toString() ?? '',
      area: json['area']?.toString(),
      projectInterest: json['project_interest']?.toString(),
      budgetRange: json['budget_range']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'lead_alias': alias,
      'lead_status': status,
      if (area != null) 'area': area,
      if (projectInterest != null) 'project_interest': projectInterest,
      if (budgetRange != null) 'budget_range': budgetRange,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
