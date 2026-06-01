import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'challenges.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
Color _hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a, h % 360, s, l).toColor();

const double kCyanHue = 188;
const double kAmberHue = 34;
double polarHue(int c) => c == 0 ? kCyanHue : kAmberHue;

enum Phase { ready, play, dead }

const List<String> kZoneOrder = ['STEADY', 'RAPIDS', 'BLACKOUT', 'STORM'];
int zoneRank(String n) => kZoneOrder.indexOf(n);

class Bar {
  double d;
  int color;
  bool gap;
  bool live;
  Bar(this.d, this.color, this.gap) : live = true;
}

class Particle {
  double x, y, vx, vy, life, max, r, hue;
  Particle(this.x, this.y, this.vx, this.vy, this.max, this.r, this.hue) : life = 1;
}

/// Drives gameplay. Notifies once per frame so the painter + HUD repaint.
class VeerGame extends ChangeNotifier {
  VeerGame(this.rec);

  final Records rec;
  void Function()? onDeath; // fired when a run ends (after stats committed)

  // viewport (set each build)
  double w = 400, h = 800;
  double get camY => h * 0.74;

  static const double zlen = 4200;

  Phase phase = Phase.ready;
  bool daily = false;
  String dateKey = '';
  math.Random rng = math.Random();

  // dart
  double d = 0;
  int color = 0;
  double pop = 1, flipT = 99;

  // field
  final List<Bar> bars = [];
  double spawnCursor = 0;
  int lastColor = 0, runLen = 0;

  // scoring
  double score = 0;
  int combo = 0;

  // run stats
  int flips = 0, maxStreak = 0, maxRank = 0;
  double timeAlive = 0;
  String zoneName = 'STEADY';

  // fx
  double speed = 300, shake = 0, slow = 1, flash = 0, flashHue = 190, deathT = 0, bgTint = 0;
  double bannerT = 99;
  String bannerName = '', bannerSub = '';
  final List<Particle> particles = [];

  bool get blackout => zoneName == 'BLACKOUT';

  // ---- difficulty curves ----
  double get _t => _clamp(d / (zlen * 7), 0, 1);
  int get _level => (d / zlen).floor();

  String _zoneFor(double dist) {
    final li = (dist / zlen).floor();
    if (li == 0) return 'STEADY';
    return kZoneOrder[1 + ((li - 1) % 3)];
  }

  double get _zoneSpdMult {
    switch (zoneName) {
      case 'STEADY': return 0.88;
      case 'RAPIDS': return 1.05;
      case 'BLACKOUT': return 0.96;
      case 'STORM': return 1.14;
    }
    return 1;
  }

  double get _zoneSpcMult {
    switch (zoneName) {
      case 'STEADY': return 1.16;
      case 'RAPIDS': return 0.95;
      case 'BLACKOUT': return 1.02;
      case 'STORM': return 0.8;
    }
    return 1;
  }

  double get _zoneGapMult => zoneName == 'STORM' ? 0.4 : (zoneName == 'STEADY' ? 1.2 : 1);

