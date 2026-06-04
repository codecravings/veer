/// Cosmetic dart skins unlocked with coins. The dart colour always reflects
/// the current polarity (that's gameplay-critical); skins only change the
/// dart's shape and whether it leaves a comet trail.
class Skin {
  final String id;
  final String name;
  final int cost;
  final int shape; // 0 arrow, 1 diamond, 2 chevron, 3 spark
  final bool trail;
  const Skin(this.id, this.name, this.cost, this.shape, {this.trail = false});
}

const List<Skin> kSkins = [
  Skin('classic', 'Classic', 0, 0),
  Skin('diamond', 'Diamond', 120, 1),
  Skin('chevron', 'Chevron', 280, 2),
  Skin('spark', 'Spark', 450, 3),
  Skin('comet', 'Comet', 800, 0, trail: true),
  Skin('nova', 'Nova', 1400, 3, trail: true),
];

Skin skinById(String id) =>
    kSkins.firstWhere((s) => s.id == id, orElse: () => kSkins.first);
