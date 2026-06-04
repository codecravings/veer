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
