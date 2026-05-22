import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class SmPerformanceTable extends StatelessWidget {
  final List<AdminPerformanceRow> rows;

  const SmPerformanceTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text(
        'No sourcing manager performance rows.',
        style: TextStyle(color: PremiumUI.muted),
      );
    }

    return Column(
      children: rows.take(5).map((row) {
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
                      redactDashboardText(row.label),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.metrics['meetings'] ?? 0} meetings - ${row.metrics['scheduled'] ?? 0} scheduled - ${row.metrics['verified'] ?? 0} verified',
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${row.efficiencyScore}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              PremiumUI.statusBadge(status, PremiumUI.statusColor(status)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
