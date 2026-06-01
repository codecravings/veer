import 'package:shared_preferences/shared_preferences.dart';

/// Persistent best-records the challenge layer reads from.
class Records {
  int bestScore;
  int bestStreak;
  int bestFlips;
  int maxRank; // furthest zone rank reached: STEADY0 RAPIDS1 BLACKOUT2 STORM3
  int bestTime; // seconds survived
  int totalRuns;
  Map<String, int> daily; // dateKey -> best score

  Records({
    this.bestScore = 0,
    this.bestStreak = 0,
    this.bestFlips = 0,
    this.maxRank = 0,
    this.bestTime = 0,
    this.totalRuns = 0,
    Map<String, int>? daily,
  }) : daily = daily ?? {};

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
    await p.setStringList('daily', daily.entries.map((e) => '${e.key}=${e.value}').toList());
  }

