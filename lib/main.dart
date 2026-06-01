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

