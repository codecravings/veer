import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'challenges.dart';
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
  bool _lastDaily = false;
  Set<String> _doneSnapshot = {};
  List<String> _newly = [];

  @override
  void initState() {
    super.initState();
    game = VeerGame(widget.rec)..onDeath = _onDeath;
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
    if (_showChallenges) return _challengesPanel(pad);
    switch (game.phase) {
      case Phase.play:
        return _playHud(pad);
      case Phase.dead:
        return _deathPanel(pad);
      case Phase.ready:
        return _homePanel(pad);
    }
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
          _statChip('BEST', '${r.bestScore}'),
          const Spacer(flex: 1),
          _bigButton('PLAY', cyan, () => _start(false)),
          const SizedBox(height: 14),
          _bigButton('DAILY  ·  ${_todayBest()}', amber, () => _start(true), filled: false),
          const SizedBox(height: 14),
          _bigButton('CHALLENGES   ${r.challengesDone}/${kChallenges.length}',
              Colors.white, () => setState(() => _showChallenges = true),
              filled: false, dim: true),
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
