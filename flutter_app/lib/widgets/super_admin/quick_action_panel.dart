import 'package:flutter/material.dart';

import '../../utils/premium_ui.dart';

class SuperAdminQuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final Set<String> allowedBy;
  final VoidCallback onTap;

  const SuperAdminQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.allowedBy,
    required this.onTap,
  });
}

class QuickActionPanel extends StatelessWidget {
  final List<String> allowedActions;
  final List<SuperAdminQuickAction> actions;

  const QuickActionPanel({
    super.key,
    required this.allowedActions,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = allowedActions.toSet();
    final visibleActions = actions
        .where((action) => action.allowedBy.any(allowed.contains))
        .toList();

    return PremiumUI.sectionShell(
      title: 'Quick Actions',
      subtitle: 'Protected workflow entry points only',
      child: visibleActions.isEmpty
          ? const Text(
              'No actions allowed for this session.',
              style: TextStyle(color: PremiumUI.muted),
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: visibleActions.map(_actionTile).toList(),
            ),
    );
  }

  Widget _actionTile(SuperAdminQuickAction action) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: action.onTap,
      child: Container(
        width: 206,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PremiumUI.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(action.icon, color: action.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
