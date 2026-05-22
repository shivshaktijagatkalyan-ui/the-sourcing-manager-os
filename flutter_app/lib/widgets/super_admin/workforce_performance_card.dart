import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';
import 'broker_performance_table.dart';
import 'caller_performance_table.dart';
import 'sm_performance_table.dart';

class WorkforcePerformanceCard extends StatelessWidget {
  final AdminWorkforceSnapshot workforce;

  const WorkforcePerformanceCard({super.key, required this.workforce});

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Workforce Performance',
      subtitle: 'Broker, caller, and sourcing manager efficiency',
      accentColor: PremiumUI.secondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sections = [
            _section(
                'Brokers', BrokerPerformanceTable(rows: workforce.brokers)),
            _section(
                'Callers', CallerPerformanceTable(rows: workforce.callers)),
            _section(
              'Sourcing Managers',
              SmPerformanceTable(rows: workforce.sourcingManagers),
            ),
          ];

          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                for (final section in sections) ...[
                  section,
                  const SizedBox(height: 14),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sections[0]),
              const SizedBox(width: 14),
              Expanded(child: sections[1]),
              const SizedBox(width: 14),
              Expanded(child: sections[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: PremiumUI.subtitle.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
