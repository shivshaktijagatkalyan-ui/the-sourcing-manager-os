import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class AuditTimelineCard extends StatelessWidget {
  final List<AdminAuditEventRow> events;

  const AuditTimelineCard({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Audit Timeline',
      subtitle: 'Safe admin and workflow events only',
      accentColor: PremiumUI.warning,
      child: events.isEmpty
          ? const Text(
              'No recent safe audit events.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(children: events.map(_row).toList()),
    );
  }

  Widget _row(AdminAuditEventRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: PremiumUI.primary, size: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  redactDashboardText(row.eventType.replaceAll('_', ' ')),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${redactDashboardText(row.actorRole)} - ${_formatTimestamp(row.createdAt)}',
                  style: const TextStyle(
                    color: PremiumUI.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return 'timestamp unavailable';
    return '${value.day}/${value.month} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
