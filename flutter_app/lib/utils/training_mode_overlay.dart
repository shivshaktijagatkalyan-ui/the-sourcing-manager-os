import 'package:flutter/material.dart';

class TrainingModeOverlay extends StatelessWidget {
  final Widget child;
  final bool isTrainingMode;

  const TrainingModeOverlay({
    super.key,
    required this.child,
    required this.isTrainingMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTrainingMode) return child;

    return Stack(
      children: [
        child,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 4),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.amber,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: const Center(
              child: Text(
                'TRAINING MODE - NO DATA IS SAVED',
                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
