import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class TrustOperationsCard extends StatelessWidget {
  final List<AdminOperationalRow> rows;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const TrustOperationsCard({
    super.key,
    required this.rows,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Trust Operations',
      subtitle: 'Locks, proofs, eligibility, duplicate attempts, and disputes',
      accentColor: PremiumUI.primary,
      child: rows.isEmpty
          ? const Text(
              'No active trust operations.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(
              children: rows
                  .map((row) => _TrustRow(row: row, onOpen: onOpen))
                  .toList(),
            ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final AdminOperationalRow row;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const _TrustRow({required this.row, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final severity = normalizedDashboardBadge(row.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen == null ? null : () => onOpen!(row),
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
                      redactDashboardText(row.title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${redactDashboardText(row.safeRef)} - ${redactDashboardText(row.action)}',
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpen != null)
                const Icon(Icons.chevron_right,
                    color: PremiumUI.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
