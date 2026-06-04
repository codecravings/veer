/// Distinct colour-sequence patterns. This is what makes levels *feel*
/// different rather than just faster — each shapes how the bars arrive.
enum PatternKind {
  alternate, // strict ABAB — pure rhythm, fast even taps
  runs,      // long same-colour runs — inhibition heavy (hold the tap)
  doubles,   // pairs: AA BB AA BB — read in twos
  bursts,    // tight clusters then a breather
  random,    // every bar independent — read each one
  mixed,     // weighted blend that drifts between the above
}

/// A hand-tuned level: a pattern flavour + difficulty knobs + a finish line.
/// Beating it (reaching [distance] without crashing) earns 1–3 stars.
class Level {
  final int index;
  final String name;
  final PatternKind pattern;
  final double speedMul;
  final double spacingMul; // <1 = tighter bars
  final double gapChance;  // breathing-room gaps
  final double distance;   // finish line
  final int star2;         // score for 2nd star
  final int star3;         // score for 3rd star
  const Level(this.index, this.name, this.pattern, this.speedMul,
      this.spacingMul, this.gapChance, this.distance, this.star2, this.star3);
}

const double _seg = 4200; // one "zone" of travel

const List<Level> kLevels = [
  Level(1, 'First Steps', PatternKind.alternate, 0.80, 1.20, 0.12, _seg * 1.2, 120, 200),
  Level(2, 'Steady Beat', PatternKind.alternate, 0.92, 1.05, 0.10, _seg * 1.4, 180, 300),
  Level(3, 'Hold Back', PatternKind.runs, 0.88, 1.10, 0.10, _seg * 1.4, 200, 340),
  Level(4, 'In Twos', PatternKind.doubles, 0.95, 1.00, 0.08, _seg * 1.6, 240, 400),
  Level(5, 'Quickstep', PatternKind.alternate, 1.10, 0.90, 0.07, _seg * 1.6, 280, 460),
  Level(6, 'Read Ahead', PatternKind.runs, 1.00, 0.95, 0.07, _seg * 1.8, 320, 520),
  Level(7, 'Scatter', PatternKind.random, 0.95, 1.00, 0.09, _seg * 1.8, 340, 560),
  Level(8, 'Bursts', PatternKind.bursts, 1.05, 0.92, 0.10, _seg * 2.0, 400, 640),
];
