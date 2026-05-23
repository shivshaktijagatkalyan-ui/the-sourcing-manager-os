import 'package:flutter/material.dart';

class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    required this.label,
    this.score,
    this.color,
  });

  final String label;
  final num? score;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    final text = score == null ? label : '$label ${score!.round()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withAlpha(35),
        border: Border.all(color: resolvedColor.withAlpha(130)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
