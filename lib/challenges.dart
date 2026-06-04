import 'package:shared_preferences/shared_preferences.dart';

/// Persistent best-records the challenge layer reads from.
class Records {
  int bestScore;
  int bestStreak;
  int bestFlips;
  int maxRank; // furthest zone rank reached: STEADY0 RAPIDS1 BLACKOUT2 STORM3
  int bestTime; // seconds survived
  int totalRuns;
  int coins;
  Set<String> unlocked;
  String equipped;
  Map<String, int> daily; // dateKey -> best score

  Records({
    this.bestScore = 0,
    this.bestStreak = 0,
    this.bestFlips = 0,
    this.maxRank = 0,
    this.bestTime = 0,
    this.totalRuns = 0,
    this.coins = 0,
    Set<String>? unlocked,
    this.equipped = 'classic',
    Map<String, int>? daily,
  })  : unlocked = unlocked ?? {'classic'},
        daily = daily ?? {};

  static SharedPreferences? _p;

  static Future<Records> load() async {
    final p = _p = await SharedPreferences.getInstance();
    final daily = <String, int>{};
    final raw = p.getStringList('daily') ?? [];
    for (final e in raw) {
      final i = e.indexOf('=');
      if (i > 0) daily[e.substring(0, i)] = int.tryParse(e.substring(i + 1)) ?? 0;
    }
    return Records(
      bestScore: p.getInt('bestScore') ?? 0,
      bestStreak: p.getInt('bestStreak') ?? 0,
      bestFlips: p.getInt('bestFlips') ?? 0,
      maxRank: p.getInt('maxRank') ?? 0,
      bestTime: p.getInt('bestTime') ?? 0,
      totalRuns: p.getInt('totalRuns') ?? 0,
      coins: p.getInt('coins') ?? 0,
      unlocked: (p.getStringList('unlocked') ?? ['classic']).toSet(),
      equipped: p.getString('equipped') ?? 'classic',
      daily: daily,
    );
  }

  Future<void> save() async {
    final p = _p;
    if (p == null) return;
    await p.setInt('bestScore', bestScore);
    await p.setInt('bestStreak', bestStreak);
    await p.setInt('bestFlips', bestFlips);
    await p.setInt('maxRank', maxRank);
    await p.setInt('bestTime', bestTime);
    await p.setInt('totalRuns', totalRuns);
    await p.setInt('coins', coins);
    await p.setStringList('unlocked', unlocked.toList());
    await p.setString('equipped', equipped);
    await p.setStringList('daily', daily.entries.map((e) => '${e.key}=${e.value}').toList());
  }

  int get challengesDone => kChallenges.where((c) => c.done(this)).length;
}

/// One long-term goal. `cur`/`goal` drive the progress bar; done when cur>=goal.
class Challenge {
  final String name;
  final String desc;
  final int goal;
  final int Function(Records) cur;
  const Challenge(this.name, this.desc, this.goal, this.cur);

  bool done(Records r) => cur(r) >= goal;
  double progress(Records r) => (cur(r) / goal).clamp(0.0, 1.0);
}

const List<Challenge> kChallenges = [
  Challenge('First Flight', 'Score 100 in a run', 100, _score),
  Challenge('Warming Up', 'Reach the RAPIDS zone', 1, _rank),
  Challenge('Quick Hands', 'Flip 30 times in one run', 30, _flips),
  Challenge('Reader', 'Hit a x10 streak', 10, _streak),
  Challenge('Into the Dark', 'Reach the BLACKOUT zone', 2, _rank),
  Challenge('Focused', 'Hit a x25 streak', 25, _streak),
  Challenge('Eye of the Storm', 'Reach the STORM zone', 3, _rank),
  Challenge('Marathon', 'Survive 90 seconds', 90, _time),
  Challenge('Sharpshooter', 'Score 800 in a run', 800, _score),
];

int _score(Records r) => r.bestScore;
int _streak(Records r) => r.bestStreak;
int _flips(Records r) => r.bestFlips;
int _rank(Records r) => r.maxRank;
int _time(Records r) => r.bestTime;
