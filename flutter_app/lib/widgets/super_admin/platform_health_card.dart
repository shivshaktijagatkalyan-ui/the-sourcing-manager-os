import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class PlatformHealthCard extends StatelessWidget {
  final AdminPlatformHealth health;

  const PlatformHealthCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final status = normalizedDashboardBadge(health.status);
    return PremiumUI.sectionShell(
      title: 'Platform Health',
      subtitle: 'Reliability, release, migration, and security signal',
      accentColor: _healthColor(status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumUI.statusBadge(status, _healthColor(status)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  redactDashboardText(health.lastEvent),
                  style: const TextStyle(
                    color: PremiumUI.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(label: 'Failed Functions', value: health.failedFunctions),
              _Metric(
                  label: 'Provider Failures', value: health.providerFailures),
              _Metric(
                  label: 'Callback Failures', value: health.callbackFailures),
              _StatusMetric(
                  label: 'Release Gate', value: health.lastReleaseGate),
              _StatusMetric(
                  label: 'Migration Drift', value: health.migrationDrift),
              _StatusMetric(
                  label: 'Security Scan', value: health.securityScanStatus),
            ],
          ),
        ],
      ),
    );
  }

  Color _healthColor(String status) {
    switch (status) {
      case 'healthy':
      case 'pass':
        return PremiumUI.secondary;
      case 'warning':
      case 'degraded':
        return PremiumUI.warning;
      case 'critical':
      case 'incident':
      case 'fail':
        return PremiumUI.danger;
      default:
        return PremiumUI.muted;
    }
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: PremiumUI.kpiCard(
        label,
        value.toString(),
        Icons.monitor_heart_outlined,
        value > 0 ? PremiumUI.warning : PremiumUI.secondary,
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  final String label;
  final String value;

  const _StatusMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final status = normalizedDashboardBadge(value);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PremiumUI.statusColor(status).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: PremiumUI.subtitle.copyWith(fontSize: 9),
          ),
          const SizedBox(height: 8),
          PremiumUI.statusBadge(status, PremiumUI.statusColor(status)),
        ],
      ),
    );
  }
}
