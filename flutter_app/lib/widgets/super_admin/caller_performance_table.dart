import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class CallerPerformanceTable extends StatelessWidget {
  final List<AdminPerformanceRow> rows;

  const CallerPerformanceTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text(
        'No caller performance rows.',
        style: TextStyle(color: PremiumUI.muted),
      );
    }

    return Column(
      children: rows.take(5).map((row) {
        final risk = normalizedDashboardBadge(row.riskLevel);
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
                child: Text(
                  redactDashboardText(row.label),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _metric('assigned', row),
              _metric('attempted', row),
              _metric('connected', row),
              _metric('interested', row),
              PremiumUI.statusBadge(risk, PremiumUI.statusColor(risk)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _metric(String key, AdminPerformanceRow row) {
    return SizedBox(
      width: 54,
      child: Text(
        '${row.metrics[key] ?? 0}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
