import 'package:flutter/material.dart';
import '../utils/premium_ui.dart';

class CompleteProfileCard extends StatelessWidget {
  final String role;
  final VoidCallback onCompleteTap;
  final List<String> missingFields;

  const CompleteProfileCard({
    super.key,
    required this.role,
    required this.onCompleteTap,
    this.missingFields = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PremiumUI.accent.withValues(alpha: 0.1),
            border: Border.all(color: PremiumUI.accent.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: isCompact ? _compactContent() : _wideContent(),
        );
      },
    );
  }

  Widget _wideContent() {
    return Row(
      children: [
        _icon(),
        const SizedBox(width: 16),
        Expanded(child: _copy()),
        const SizedBox(width: 16),
        _button(),
      ],
    );
  }

  Widget _compactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _icon(),
            const SizedBox(width: 14),
            Expanded(child: _copy()),
          ],
        ),
        const SizedBox(height: 16),
        _button(),
      ],
    );
  }

  Widget _icon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.accent.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.assignment_ind_outlined,
        color: PremiumUI.accent,
      ),
    );
  }

  Widget _copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete Your Profile',
          style: PremiumUI.h1.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          _profileMessage(),
          style: PremiumUI.subtitle.copyWith(fontSize: 12, height: 1.35),
        ),
        if (role.contains('broker')) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _brokerVerificationSteps().map(_stepChip).toList(),
          ),
        ],
      ],
    );
  }

  Widget _button() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: PremiumUI.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onCompleteTap,
      child: Text(
        role.contains('broker') ? 'START REVIEW' : 'COMPLETE NOW',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _stepChip(String label) {
    final isMissing = missingFields
        .map((field) => field.toLowerCase())
        .contains(label.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: (isMissing ? PremiumUI.warning : PremiumUI.secondary)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isMissing ? PremiumUI.warning : PremiumUI.secondary)
              .withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMissing ? Icons.pending_actions : Icons.check_circle,
            color: isMissing ? PremiumUI.warning : PremiumUI.secondary,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _brokerVerificationSteps() {
    return const [
      'full name',
      'company name',
      'RERA number',
      'working area',
      'city',
      'speciality',
    ];
  }

  String _profileMessage() {
    if (role.contains('broker') && missingFields.isNotEmpty) {
      return 'Complete ${missingFields.join(', ')} to start data review and unlock the Verified Broker badge.';
    }
    if (role.contains('broker')) {
      return 'Profile data is complete. Keep trust, visits, and broker locks strong for badge review.';
    } else if (role == 'sourcing_manager') {
      return 'Add assigned projects, broker network size, and targets.';
    }
    return 'Add additional details.';
  }
}
