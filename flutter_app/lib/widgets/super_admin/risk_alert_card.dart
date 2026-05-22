import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class RiskAlertCard extends StatelessWidget {
  final List<AdminOperationalRow> alerts;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const RiskAlertCard({
    super.key,
    required this.alerts,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Risk + Abuse Center',
      subtitle: 'Duplicate, proof, permission, and callback risk metadata',
      accentColor: PremiumUI.danger,
      child: alerts.isEmpty
          ? const Text(
              'No active risk alerts.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(
              children: alerts
                  .map((alert) => _RiskRow(alert: alert, onOpen: onOpen))
                  .toList(),
            ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final AdminOperationalRow alert;
  final ValueChanged<AdminOperationalRow>? onOpen;

  const _RiskRow({required this.alert, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final severity = normalizedDashboardBadge(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen == null ? null : () => onOpen!(alert),
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
                      redactDashboardText(alert.title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${redactDashboardText(alert.safeRef)} - ${redactDashboardText(alert.action)}',
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
