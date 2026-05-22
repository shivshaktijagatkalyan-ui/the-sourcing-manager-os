import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class BrokerPerformanceTable extends StatelessWidget {
  final List<AdminPerformanceRow> rows;

  const BrokerPerformanceTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _PerformanceTable(
      rows: rows,
      emptyText: 'No broker performance rows.',
      metricLabels: const ['leads', 'visits', 'locks', 'trust'],
    );
  }
}

class _PerformanceTable extends StatelessWidget {
  final List<AdminPerformanceRow> rows;
  final String emptyText;
  final List<String> metricLabels;

  const _PerformanceTable({
    required this.rows,
    required this.emptyText,
    required this.metricLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: PremiumUI.muted));
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
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      redactDashboardText(row.label),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.efficiencyScore}% efficiency',
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ...metricLabels.map(
                (label) => SizedBox(
                  width: 58,
                  child: Text(
                    '${row.metrics[label] ?? 0}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PremiumUI.statusBadge(
                    risk,
                    PremiumUI.statusColor(risk),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
