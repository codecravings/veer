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

