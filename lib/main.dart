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
