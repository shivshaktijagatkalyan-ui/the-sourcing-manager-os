import 'package:flutter/material.dart';

import '../../models/super_admin_snapshot.dart';
import '../../utils/premium_ui.dart';

class AttentionQueueCard extends StatelessWidget {
  final List<AdminAttentionItem> items;
  final bool Function(AdminAttentionItem item) canOpen;
  final ValueChanged<AdminAttentionItem> onOpen;

  const AttentionQueueCard({
    super.key,
    required this.items,
    required this.canOpen,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumUI.sectionShell(
      title: 'Attention Queue',
      subtitle: 'Workflow issues routed to protected modules',
      accentColor: PremiumUI.danger,
      child: items.isEmpty
          ? const Text(
              'No attention items.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Column(
              children: items
                  .map((item) => _AttentionRow(
                        item: item,
                        canOpen: canOpen(item),
                        onOpen: onOpen,
                      ))
                  .toList(),
            ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final AdminAttentionItem item;
  final bool canOpen;
  final ValueChanged<AdminAttentionItem> onOpen;

  const _AttentionRow({
    required this.item,
    required this.canOpen,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final severity = normalizedDashboardBadge(item.severity);
    final safeRef = item.safeRef.isEmpty ? item.id : item.safeRef;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? () => onOpen(item) : null,
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
                      '${redactDashboardText(safeRef)} - ${redactDashboardText(item.action)}',
                      style: const TextStyle(
                        color: PremiumUI.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpen)
                const Icon(
                  Icons.chevron_right,
                  color: PremiumUI.muted,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
