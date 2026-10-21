/// Official combat role levels and competitive position classifications
/// for the Draft Picker.
library;

/// The five competitive Dota 2 positions based on farm priority and lane assignment.
enum DraftPosition {
  pos1('Pos 1', 'Safe Lane'),
  pos2('Pos 2', 'Mid Lane'),
  pos3('Pos 3', 'Offlane'),
  pos4('Pos 4', 'Soft Support'),
  pos5('Pos 5', 'Hard Support');

  const DraftPosition(this.label, this.laneDescription);

  final String label;
  final String laneDescription;
}

/// Official combat role levels (0..3) from Valve's hero datafeed.
///
/// Corresponds to the 9 role levels returned by `dota2.com/datafeed/herodata`:
/// [0] Carry, [1] Support, [2] Nuker, [3] Disabler, [4] Jungler,
/// [5] Durable, [6] Escape, [7] Pusher, [8] Initiator.
class HeroRoleLevels {
  const HeroRoleLevels({
    this.carry = 0,
    this.support = 0,
    this.nuker = 0,
    this.disabler = 0,
    this.jungler = 0,
    this.durable = 0,
    this.escape = 0,
    this.pusher = 0,
    this.initiator = 0,
  });

  factory HeroRoleLevels.fromList(List<int> levels) {
    if (levels.length < 9) {
      throw FormatException(
        'role_levels must contain at least 9 elements, got ${levels.length}',
      );
    }
    return HeroRoleLevels(
      carry: levels[0],
      support: levels[1],
      nuker: levels[2],
      disabler: levels[3],
      jungler: levels[4],
      durable: levels[5],
      escape: levels[6],
      pusher: levels[7],
      initiator: levels[8],
    );
  }

  final int carry;
  final int support;
  final int nuker;
  final int disabler;
  final int jungler;
  final int durable;
  final int escape;
  final int pusher;
  final int initiator;

  /// Returns whether this hero is suitable for [position] based on official role levels.
  bool isSuitableForPosition(DraftPosition position) {
    return switch (position) {
      DraftPosition.pos1 => carry >= 2,
      DraftPosition.pos2 => nuker >= 2 || (carry >= 2 && nuker >= 1),
      DraftPosition.pos3 => durable >= 2 || initiator >= 2,
      DraftPosition.pos4 =>
        support >= 1 &&
            (disabler >= 1 || initiator >= 1 || nuker >= 1) &&
            carry <= 1,
      DraftPosition.pos5 => support >= 2 && carry == 0,
    };
  }
}

/// Diagnostic score and status for one vital combat archetype.
class RoleDiagnostic {
  const RoleDiagnostic({
    required this.label,
    required this.points,
    required this.threshold,
    required this.alert,
  });

  final String label;
  final int points;
  final int threshold;
  final String alert;

  bool get fulfilled => points >= threshold;
}

/// Real-time evaluation of drafted team balance across the 4 essential combat archetypes:
/// Disabler (lockdown), Durable (frontline), Initiator, and Support.
class CompositionDiagnostics {
  const CompositionDiagnostics({
    required this.disablerPoints,
    required this.durablePoints,
    required this.initiatorPoints,
    required this.supportPoints,
    required this.alerts,
  });

  factory CompositionDiagnostics.fromRoles(List<HeroRoleLevels> alliedRoles) {
    var disablerPoints = 0;
    var durablePoints = 0;
    var initiatorPoints = 0;
    var supportPoints = 0;

    for (final role in alliedRoles) {
      disablerPoints += role.disabler;
      durablePoints += role.durable;
      initiatorPoints += role.initiator;
      supportPoints += role.support;
    }

    final alerts = <String>[];
    if (disablerPoints < disablerThreshold) alerts.add(disablerAlert);
    if (durablePoints < durableThreshold) alerts.add(durableAlert);
    if (initiatorPoints < initiatorThreshold) alerts.add(initiatorAlert);
    if (supportPoints < supportThreshold) alerts.add(supportAlert);

    return CompositionDiagnostics(
      disablerPoints: disablerPoints,
      durablePoints: durablePoints,
      initiatorPoints: initiatorPoints,
      supportPoints: supportPoints,
      alerts: List.unmodifiable(alerts),
    );
  }

  static const int disablerThreshold = 3;
  static const int durableThreshold = 3;
  static const int initiatorThreshold = 2;
  static const int supportThreshold = 3;

  static const String disablerAlert = 'Draft lacks reliable stuns/disable';
  static const String durableAlert = 'Draft lacks durable frontline';
  static const String initiatorAlert = 'Draft lacks initiation';
  static const String supportAlert = 'Draft lacks sufficient support';

  final int disablerPoints;
  final int durablePoints;
  final int initiatorPoints;
  final int supportPoints;
  final List<String> alerts;

  bool get hasDisabler => disablerPoints >= disablerThreshold;
  bool get hasDurable => durablePoints >= durableThreshold;
  bool get hasInitiator => initiatorPoints >= initiatorThreshold;
  bool get hasSupport => supportPoints >= supportThreshold;

  /// Bundled archetype diagnostics.
  List<RoleDiagnostic> get archetypes => [
    RoleDiagnostic(
      label: 'Disabler',
      points: disablerPoints,
      threshold: disablerThreshold,
      alert: disablerAlert,
    ),
    RoleDiagnostic(
      label: 'Durable',
      points: durablePoints,
      threshold: durableThreshold,
      alert: durableAlert,
    ),
    RoleDiagnostic(
      label: 'Initiator',
      points: initiatorPoints,
      threshold: initiatorThreshold,
      alert: initiatorAlert,
    ),
    RoleDiagnostic(
      label: 'Support',
      points: supportPoints,
      threshold: supportThreshold,
      alert: supportAlert,
    ),
  ];

  /// True when all four essential combat role thresholds are met.
  bool get isBalanced => alerts.isEmpty;
}
