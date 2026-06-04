import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'challenges.dart';
import 'cosmetics.dart';
import 'levels.dart';
import 'veer_game.dart';

Color hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a, h % 360, s, l).toColor();

final Color cyan = hsl(188, .9, .58);
final Color amber = hsl(34, .92, .56);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final rec = await Records.load();
  runApp(VeerApp(rec: rec));
}

class VeerApp extends StatelessWidget {
  const VeerApp({super.key, required this.rec});
  final Records rec;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VEER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05060C),
      ),
      home: RootScreen(rec: rec),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.rec});
  final Records rec;
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with SingleTickerProviderStateMixin {
  late final VeerGame game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  bool _showChallenges = false;
  bool _showShop = false;
  bool _showLevels = false;
  bool _lastDaily = false;
  Set<String> _doneSnapshot = {};
  List<String> _newly = [];

  @override
  void initState() {
    super.initState();
    game = VeerGame(widget.rec)
      ..onDeath = _onDeath
      ..onWin = _onWin;
    game.goReady();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    double dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.05) dt = 0.05;
    game.update(dt);
  }

  void _onDeath() {
    HapticFeedback.heavyImpact();
    final now = kChallenges.where((c) => c.done(widget.rec)).map((c) => c.name).toSet();
    setState(() => _newly = now.difference(_doneSnapshot).toList());
  }

  void _start(bool daily) {
    _doneSnapshot = kChallenges.where((c) => c.done(widget.rec)).map((c) => c.name).toSet();
    _newly = [];
    _lastDaily = daily;
    setState(() => _showChallenges = false);
    HapticFeedback.mediumImpact();
    game.startRun(daily: daily);
  }

  void _onWin() {
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _startLevel(Level lv) {
    setState(() {
      _showLevels = false;
      _newly = [];
    });
    HapticFeedback.mediumImpact();
    game.startLevel(lv);
  }

  void _flip() {
    if (game.phase != Phase.play) return;
    HapticFeedback.selectionClick();
    game.tap();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _flip(),
              child: CustomPaint(painter: VeerPainter(game), child: const SizedBox.expand()),
            ),
          ),
          AnimatedBuilder(
            animation: game,
            builder: (context, _) => _overlays(pad),
          ),
        ],
      ),
    );
  }

  Widget _overlays(EdgeInsets pad) {
    if (_showShop) return _shopPanel(pad);
    if (_showLevels) return _levelsPanel(pad);
    if (_showChallenges) return _challengesPanel(pad);
    switch (game.phase) {
      case Phase.play:
        return _playHud(pad);
      case Phase.dead:
        return _deathPanel(pad);
      case Phase.won:
        return _winPanel(pad);
      case Phase.ready:
        return _homePanel(pad);
    }
  }

  // ---------- LEVEL SELECT ----------
  Widget _levelsPanel(EdgeInsets pad) {
    final r = widget.rec;
    return Container(
      color: const Color(0xF2070A14),
      padding: EdgeInsets.fromLTRB(20, pad.top + 24, 20, pad.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('LEVELS',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white)),
            const Spacer(),
            Text('⭐ ${r.totalStars}/${kLevels.length * 3}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: amber)),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: kLevels.map((l) => _levelCard(l, r)).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _bigButton('BACK', Colors.white, () => setState(() => _showLevels = false),
              filled: false, dim: true),
        ],
      ),
    );
  }

  Widget _levelCard(Level lv, Records r) {
    final stars = r.levelStars[lv.index] ?? 0;
    // unlocked if it's level 1 or the previous level has at least 1 star
    final unlocked = lv.index == 1 || (r.levelStars[lv.index - 1] ?? 0) > 0;
    final col = stars > 0 ? amber : cyan;
    return GestureDetector(
      onTap: unlocked ? () => _startLevel(lv) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(unlocked ? 0.04 : 0.015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withOpacity(unlocked ? 0.3 : 0.08), width: 1.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              Icon(Icons.lock, color: Colors.white.withOpacity(0.3), size: 26)
            else
              Text('${lv.index}',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(color: col, blurRadius: 12)])),
            const SizedBox(height: 6),
            Text(unlocked ? lv.name : '———',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: Colors.white.withOpacity(unlocked ? 0.6 : 0.25))),
            const SizedBox(height: 6),
            Text(
              List.generate(3, (i) => i < stars ? '★' : '☆').join(),
              style: TextStyle(
                  fontSize: 13, color: stars > 0 ? amber : Colors.white.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- PLAY HUD ----------
  Widget _playHud(EdgeInsets pad) {
    final c = game.color == 0 ? cyan : amber;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: pad.top + 14),
        child: Column(
          children: [
            Text('${game.score.floor()}',
                style: const TextStyle(
                    fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white)),
            if (game.combo > 1)
              Text('x${game.multiplier.toStringAsFixed(2)}   ${game.combo} streak',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
            const Spacer(),
            _banner(),
            SizedBox(height: 40 + pad.bottom),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    final t = game.bannerT;
    if (t > 2.4) return const SizedBox.shrink();
    final op = t < 0.3 ? t / 0.3 : (t > 1.9 ? (2.4 - t) / 0.5 : 1.0);
    final c = game.bannerName == 'STORM'
        ? hsl(0, .8, .62)
        : game.bannerName == 'BLACKOUT'
            ? hsl(265, .7, .66)
            : cyan;
    return Opacity(
      opacity: op.clamp(0, 1),
      child: Column(
        children: [
          Text(game.bannerName,
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: c,
                  shadows: [Shadow(color: c, blurRadius: 24)])),
          Text(game.bannerSub.toUpperCase(),
              style: TextStyle(
                  fontSize: 13, letterSpacing: 3, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  // ---------- HOME ----------
  Widget _homePanel(EdgeInsets pad) {
    final r = widget.rec;
    return Container(
      color: Colors.black.withOpacity(0.28),
      padding: EdgeInsets.fromLTRB(28, pad.top + 40, 28, pad.bottom + 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _logo(),
          const SizedBox(height: 8),
          Text('P O L A R I T Y',
              style: TextStyle(
                  letterSpacing: 8, fontSize: 13, color: Colors.white.withOpacity(0.55))),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statChip('BEST', '${r.bestScore}'),
            const SizedBox(width: 44),
            _statChip('COINS', '${r.coins}'),
          ]),
          const Spacer(flex: 1),
          _bigButton('LEVELS   ⭐ ${r.totalStars}', cyan, () => setState(() => _showLevels = true)),
          const SizedBox(height: 14),
          _bigButton('ENDLESS  ·  ${r.bestScore}', cyan, () => _start(false), filled: false),
          const SizedBox(height: 14),
          _bigButton('DAILY  ·  ${_todayBest()}', amber, () => _start(true), filled: false),
          const SizedBox(height: 14),
          _bigButton('CHALLENGES   ${r.challengesDone}/${kChallenges.length}',
              Colors.white, () => setState(() => _showChallenges = true),
              filled: false, dim: true),
          const SizedBox(height: 14),
          _bigButton('SHOP   🪙 ${r.coins}', amber, () => setState(() => _showShop = true),
              filled: false),
          const Spacer(flex: 2),
          Text('tap anywhere to flip · match every bar',
              style: TextStyle(
                  fontSize: 12, letterSpacing: 1, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _logo() {
    return Text('VEER',
        style: TextStyle(
            fontSize: 82,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: Colors.white,
            shadows: [
              Shadow(color: cyan, blurRadius: 30),
              Shadow(color: amber.withOpacity(0.5), blurRadius: 50),
            ]));
  }

  String _todayBest() {
    final now = DateTime.now();
    final key =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return '${widget.rec.daily[key] ?? 0}';
  }

  // ---------- DEATH ----------
  Widget _deathPanel(EdgeInsets pad) {
    final r = widget.rec;
    final s = game.score.floor();
    final isBest = s >= r.bestScore && s > 0;
    final a = (game.deathT * 2).clamp(0.0, 1.0);
    return Opacity(
      opacity: a,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        padding: EdgeInsets.fromLTRB(28, pad.top + 40, 28, pad.bottom + 28),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text('$s',
                style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: cyan, blurRadius: 24)])),
            Text(isBest ? 'NEW BEST!' : 'BEST  ${r.bestScore}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: isBest ? amber : Colors.white.withOpacity(0.7))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _miniStat('STREAK', 'x${game.maxStreak}'),
              const SizedBox(width: 28),
              _miniStat('ZONE', kZoneOrder[game.maxRank]),
              const SizedBox(width: 28),
              _miniStat('TIME', '${game.timeAlive.floor()}s'),
            ]),
            const SizedBox(height: 14),
            Text('🪙  +${game.coinsEarned}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: amber)),
            if (_newly.isNotEmpty) ...[
              const SizedBox(height: 22),
              ..._newly.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('✓  $n',
                        style: TextStyle(
                            color: amber, fontSize: 15, fontWeight: FontWeight.w700)),
                  )),
              Text('CHALLENGE COMPLETE',
                  style: TextStyle(
                      fontSize: 11, letterSpacing: 3, color: amber.withOpacity(0.7))),
            ],
            const Spacer(flex: 2),
            _bigButton('RETRY', game.daily ? amber : cyan, () => _start(_lastDaily)),
            const SizedBox(height: 14),
            _bigButton('HOME', Colors.white, () => setState(game.goReady),
                filled: false, dim: true),
          ],
        ),
      ),
    );
  }

  // ---------- WIN ----------
  Widget _winPanel(EdgeInsets pad) {
    final lv = game.level;
    final s = game.score.floor();
    final a = (game.deathT * 2).clamp(0.0, 1.0);
    final stars = game.starsEarned;
    final nextLv = lv == null || lv.index >= kLevels.length ? null : levelByIndex(lv.index + 1);
    return Opacity(
      opacity: a,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        padding: EdgeInsets.fromLTRB(28, pad.top + 40, 28, pad.bottom + 28),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text('LEVEL ${lv?.index ?? ''}',
                style: TextStyle(
                    fontSize: 18, letterSpacing: 4, color: Colors.white.withOpacity(0.6))),
            Text('CLEARED',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: amber,
                    shadows: [Shadow(color: amber, blurRadius: 26)])),
            const SizedBox(height: 18),
            Text(
              List.generate(3, (i) => i < stars ? '★' : '☆').join(' '),
              style: TextStyle(
                  fontSize: 46,
                  color: amber,
                  shadows: [Shadow(color: amber.withOpacity(0.7), blurRadius: 18)]),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _miniStat('SCORE', '$s'),
              const SizedBox(width: 28),
              _miniStat('STREAK', 'x${game.maxStreak}'),
              const SizedBox(width: 28),
              _miniStat('COINS', '+${game.coinsEarned}'),
            ]),
            const Spacer(flex: 2),
            if (nextLv != null)
              _bigButton('NEXT  ·  ${nextLv.name}', cyan, () => _startLevel(nextLv))
            else
              _bigButton('ALL CLEAR!', amber, () => setState(() => _showLevels = true),
                  filled: false),
            const SizedBox(height: 14),
            _bigButton('LEVELS', Colors.white, () {
              setState(() {
                _showLevels = true;
                game.goReady();
              });
            }, filled: false, dim: true),
          ],
        ),
      ),
    );
  }

  // ---------- CHALLENGES ----------
  Widget _challengesPanel(EdgeInsets pad) {
    final r = widget.rec;
    return Container(
      color: const Color(0xF2070A14),
      padding: EdgeInsets.fromLTRB(20, pad.top + 24, 20, pad.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('CHALLENGES',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white)),
            const Spacer(),
            Text('${r.challengesDone}/${kChallenges.length}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cyan)),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: kChallenges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _challengeCard(kChallenges[i], r),
            ),
          ),
          const SizedBox(height: 14),
          _bigButton('BACK', Colors.white, () => setState(() => _showChallenges = false),
              filled: false, dim: true),
        ],
      ),
    );
  }

  Widget _challengeCard(Challenge c, Records r) {
    final done = c.done(r);
    final prog = c.progress(r);
    final cur = c.cur(r);
    final col = done ? amber : cyan;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(done ? 0.5 : 0.18), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(c.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            if (done)
              Icon(Icons.check_circle, color: amber, size: 22)
            else
              Text('$cur/${c.goal}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text(c.desc,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55))),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 6, color: Colors.white.withOpacity(0.07)),
              FractionallySizedBox(
                widthFactor: prog,
                child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [col.withOpacity(0.6), col]))),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------- SHOP ----------
  Widget _shopPanel(EdgeInsets pad) {
    final r = widget.rec;
    return Container(
      color: const Color(0xF2070A14),
      padding: EdgeInsets.fromLTRB(20, pad.top + 24, 20, pad.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('SHOP',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white)),
            const Spacer(),
            Text('🪙 ${r.coins}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: amber)),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: kSkins.map((s) => _skinCard(s, r)).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _bigButton('BACK', Colors.white, () => setState(() => _showShop = false),
              filled: false, dim: true),
        ],
      ),
    );
  }

  Widget _skinCard(Skin sk, Records r) {
    final owned = r.unlocked.contains(sk.id);
    final equipped = r.equipped == sk.id;
    final affordable = r.coins >= sk.cost;
    final col = equipped ? amber : cyan;
    final glyph = const ['▲', '◆', '⮝', '✦'][sk.shape] + (sk.trail ? ' ☄' : '');
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (owned) {
          setState(() => r.equipped = sk.id);
        } else if (affordable) {
          setState(() {
            r.coins -= sk.cost;
            r.unlocked.add(sk.id);
            r.equipped = sk.id;
          });
        }
        r.save();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: col.withOpacity(equipped ? 0.7 : 0.18), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(glyph,
                style: TextStyle(
                    fontSize: 34, color: cyan, shadows: [Shadow(color: cyan, blurRadius: 16)])),
            const SizedBox(height: 12),
            Text(sk.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              equipped ? 'EQUIPPED' : (owned ? 'TAP TO EQUIP' : '🪙 ${sk.cost}'),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: equipped
                      ? amber
                      : owned
                          ? Colors.white.withOpacity(0.6)
                          : (affordable ? cyan : Colors.white.withOpacity(0.35))),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- shared widgets ----------
  Widget _bigButton(String label, Color color, VoidCallback onTap,
      {bool filled = true, bool dim = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.65)])
              : null,
          color: filled ? null : Colors.white.withOpacity(dim ? 0.03 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(filled ? 0 : 0.4), width: 1.4),
          boxShadow: filled
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 24, spreadRadius: -4)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: filled ? const Color(0xFF05060C) : color)),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(children: [
      Text(label,
          style:
              TextStyle(fontSize: 12, letterSpacing: 3, color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
    ]);
  }

  Widget _miniStat(String label, String value) {
    return Column(children: [
      Text(value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label,
          style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white.withOpacity(0.5))),
    ]);
  }
}
