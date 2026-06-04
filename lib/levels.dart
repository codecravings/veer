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
