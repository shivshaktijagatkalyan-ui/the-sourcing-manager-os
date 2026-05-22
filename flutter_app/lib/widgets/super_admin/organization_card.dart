import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class OrganizationCard extends StatelessWidget {
  final List<AdminOrganizationRow> organizations;

  const OrganizationCard({super.key, required this.organizations});

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Organization Control',
      subtitle: 'Activation, project, workforce, and risk metadata',
      accentColor: PremiumUI.primary,
      child: organizations.isEmpty
          ? const Text(
              'No safe organization metadata available.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(
              children: organizations.map(_row).toList(),
            ),
    );
  }

  Widget _row(AdminOrganizationRow row) {
    final status = normalizedDashboardBadge(row.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  redactDashboardText(row.name),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${row.projectsCount} projects - ${row.activeUsers} active users - ${row.openRiskAlerts} risks',
                  style: const TextStyle(
                    color: PremiumUI.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PremiumUI.statusBadge(status, PremiumUI.statusColor(status)),
        ],
      ),
    );
  }
}
