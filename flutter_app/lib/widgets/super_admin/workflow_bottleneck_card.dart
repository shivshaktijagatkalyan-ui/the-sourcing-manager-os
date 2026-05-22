import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class WorkflowBottleneckCard extends StatelessWidget {
  final List<AdminOperationalRow> bottlenecks;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const WorkflowBottleneckCard({
    super.key,
    required this.bottlenecks,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Assignment + Allocation Control',
      subtitle: 'Unassigned work, overload, followups, and proof gaps',
      accentColor: PremiumUI.hot,
      child: bottlenecks.isEmpty
          ? const Text(
              'No workflow bottlenecks detected.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(
              children: bottlenecks
                  .map((item) => _BottleneckRow(item: item, onOpen: onOpen))
                  .toList(),
            ),
    );
  }
}

class _BottleneckRow extends StatelessWidget {
  final AdminOperationalRow item;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const _BottleneckRow({required this.item, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final severity = normalizedDashboardBadge(item.severity);
    final total = item.metrics.values.fold<int>(0, (sum, value) => sum + value);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen == null ? null : () => onOpen!(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PremiumUI.statusBadge(severity, PremiumUI.statusColor(severity)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      redactDashboardText(item.title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${redactDashboardText(item.safeRef)} - ${redactDashboardText(item.action)}',
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                total.toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
