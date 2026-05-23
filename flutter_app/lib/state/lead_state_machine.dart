enum LeadState {
  intake,
  assigned,
  dataLoanActive,
  callQueued,
  callCompleted,
  visitProposed,
  visitScheduled,
  visitStarted,
  gpsVerified,
  photoSubmitted,
  visitVerified,
  locked,
  lost,
  invalid,
}

class LeadStateMachine {
  const LeadStateMachine();

  static const Map<LeadState, Set<LeadState>> _transitions = {
    LeadState.intake: {LeadState.assigned, LeadState.invalid},
    LeadState.assigned: {
      LeadState.dataLoanActive,
      LeadState.visitProposed,
      LeadState.lost
    },
    LeadState.dataLoanActive: {
      LeadState.callQueued,
      LeadState.visitProposed,
      LeadState.lost
    },
    LeadState.callQueued: {LeadState.callCompleted, LeadState.lost},
    LeadState.callCompleted: {LeadState.visitProposed, LeadState.lost},
    LeadState.visitProposed: {LeadState.visitScheduled, LeadState.lost},
    LeadState.visitScheduled: {LeadState.visitStarted, LeadState.invalid},
    LeadState.visitStarted: {LeadState.gpsVerified, LeadState.invalid},
    LeadState.gpsVerified: {LeadState.photoSubmitted, LeadState.invalid},
    LeadState.photoSubmitted: {LeadState.visitVerified, LeadState.invalid},
    LeadState.visitVerified: {LeadState.locked},
    LeadState.locked: {},
    LeadState.lost: {},
    LeadState.invalid: {},
  };

  bool canTransition(LeadState from, LeadState to) {
    return _transitions[from]?.contains(to) ?? false;
  }

  LeadState transition(LeadState from, LeadState to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid lead state transition: $from -> $to');
    }
    return to;
  }
}
