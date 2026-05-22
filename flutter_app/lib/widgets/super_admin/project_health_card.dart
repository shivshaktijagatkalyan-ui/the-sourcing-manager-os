import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class ProjectHealthCard extends StatelessWidget {
  final List<AdminProjectRow> projects;

  const ProjectHealthCard({super.key, required this.projects});

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Developer Project Control',
      subtitle:
          'Project-wise leads, walk-ins, broker network, and inventory state',
      accentColor: PremiumUI.accent,
      child: projects.isEmpty
          ? const Text(
              'No safe project metadata available.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(children: projects.map(_row).toList()),
    );
  }

  Widget _row(AdminProjectRow row) {
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
                  '${redactDashboardText(row.area)}, ${redactDashboardText(row.city)} - ${row.activeLeads} leads - ${row.verifiedVisits} walk-ins - ${row.activeBrokers} brokers',
                  style: const TextStyle(
                    color: PremiumUI.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PremiumUI.statusBadge(status, PremiumUI.statusColor(status)),
              const SizedBox(height: 6),
              Text(
                '${row.conversionRate}% conversion',
                style: const TextStyle(
                  color: PremiumUI.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
