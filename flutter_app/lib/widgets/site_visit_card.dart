import 'package:flutter/material.dart';

import '../models/site_visit.dart';
import 'trust_badge.dart';

class SiteVisitCard extends StatelessWidget {
  const SiteVisitCard({
    super.key,
    required this.visit,
    this.onTap,
  });

  final SiteVisit visit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
            visit.projectId == null ? visit.id : 'Project ${visit.projectId}'),
        subtitle: Text(visit.scheduledAt == null
            ? 'Schedule pending'
            : 'Scheduled ${visit.scheduledAt!.toLocal()}'),
        trailing: TrustBadge(label: visit.proofStatus ?? visit.status),
      ),
    );
  }
}
