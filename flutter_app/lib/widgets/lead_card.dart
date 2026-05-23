import 'package:flutter/material.dart';

import '../models/lead.dart';
import 'trust_badge.dart';

class LeadCard extends StatelessWidget {
  const LeadCard({
    super.key,
    required this.lead,
    this.onTap,
  });

  final Lead lead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(lead.alias),
        subtitle: Text(
          [lead.area, lead.projectInterest, lead.budgetRange]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' | '),
        ),
        trailing: TrustBadge(label: lead.status),
      ),
    );
  }
}
