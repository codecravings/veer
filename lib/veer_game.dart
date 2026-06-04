import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'challenges.dart';
import 'cosmetics.dart';
import 'levels.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
Color _hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a, h % 360, s, l).toColor();

Path _dartPath(int shape) {
  final p = Path();
  switch (shape) {
    case 1: // diamond
      p..moveTo(0, -17)..lineTo(12, 0)..lineTo(0, 17)..lineTo(-12, 0)..close();
      break;
    case 2: // chevron
      p
        ..moveTo(0, -18)..lineTo(14, 10)..lineTo(11, 16)..lineTo(0, -4)
        ..lineTo(-11, 16)..lineTo(-14, 10)..close();
      break;
    case 3: // spark
      p
        ..moveTo(0, -18)..lineTo(5, -5)..lineTo(16, 0)..lineTo(5, 5)
        ..lineTo(0, 18)..lineTo(-5, 5)..lineTo(-16, 0)..lineTo(-5, -5)..close();
      break;
    default: // 0 arrow
      p..moveTo(0, -18)..lineTo(13, 14)..lineTo(0, 7)..lineTo(-13, 14)..close();
  }
  return p;
}

const double kCyanHue = 188;
const double kAmberHue = 34;
double polarHue(int c) => c == 0 ? kCyanHue : kAmberHue;

enum Phase { ready, play, dead, won }

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
  Level? level; // non-null while playing a level
  int starsEarned = 0;
  void Function()? onWin;
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

  // active colour pattern (set by level mode; endless uses mixed)
  PatternKind pattern = PatternKind.mixed;
  int patStep = 0;

  // scoring
  double score = 0;
  int combo = 0;

  // run stats
  int flips = 0, maxStreak = 0, maxRank = 0;
  double timeAlive = 0;
  String zoneName = 'STEADY';
  bool bestBeaten = false;
  int coinsEarned = 0;

  // fx
  double speed = 300, shake = 0, slow = 1, flash = 0, flashHue = 190, deathT = 0, bgTint = 0;
  double bannerT = 99;
  String bannerName = '', bannerSub = '';
  final List<Particle> particles = [];

  bool get blackout => zoneName == 'BLACKOUT';

  // ---- difficulty curves ----
  double get _t => _clamp(d / (zlen * 8), 0, 1);
  int get _level => (d / zlen).floor();

  String _zoneFor(double dist) {
    final li = (dist / zlen).floor();
    if (dist < zlen * 1.5) return 'STEADY';
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

  double get curSpeed {
    final base = _lerp(290, 660, _t);
    final extra = _clamp((_level - 7).toDouble(), 0, 40) * 5;
    final lvMul = level?.speedMul ?? 1.0;
    return math.min((base + extra) * lvMul, 820) * (level != null ? 1.0 : _zoneSpdMult);
  }

  double get curSpacing {
    final lvMul = level?.spacingMul ?? 1.0;
    final zoneMul = level != null ? 1.0 : _zoneSpcMult;
    return math.max(_lerp(330, 165, _t) * lvMul * zoneMul, 115);
  }

  double get curGap => _lerp(0.15, 0.05, _t) * _zoneGapMult;

  // ---- lifecycle ----
  void startRun({required bool daily}) {
    this.daily = daily;
    level = null;
    if (daily) {
      final now = DateTime.now();
      dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      rng = math.Random(int.parse(dateKey));
    } else {
      dateKey = '';
      rng = math.Random();
    }
    d = 0;
    color = 0;
    pop = 1;
    flipT = 99;
    bars.clear();
    particles.clear();
    speed = 300;
    score = 0;
    combo = 0;
    flips = 0;
    maxStreak = 0;
    maxRank = 0;
    timeAlive = 0;
    shake = 0;
    slow = 1;
    flash = 0;
    deathT = 0;
    bgTint = 0;
    bannerT = 99;
    zoneName = 'STEADY';
    spawnCursor = d + 360;
    lastColor = 0;
    runLen = 0;
    bestBeaten = false;
    coinsEarned = 0;
    pattern = PatternKind.mixed;
    patStep = 0;
    _fill();
    _showBanner('STEADY', 'warm up');
    phase = Phase.play;
  }

  void startLevel(Level lv) {
    startRun(daily: false);
    level = lv;
    pattern = lv.pattern;
    patStep = 0;
    starsEarned = 0;
    _showBanner('LEVEL ${lv.index}', lv.name);
  }

  void _win() {
    if (phase != Phase.play) return;
    phase = Phase.won;
    deathT = 0;
    flash = 0.5;
    flashHue = 50;
    final lv = level!;
    final s = score.floor();
    starsEarned = 1 + (s >= lv.star2 ? 1 : 0) + (s >= lv.star3 ? 1 : 0);
    coinsEarned = (s / 12).floor() + lv.index * 10 + starsEarned * 25;
    rec.coins += coinsEarned;
    final prev = rec.levelStars[lv.index] ?? 0;
    if (starsEarned > prev) rec.levelStars[lv.index] = starsEarned;
    if (s > rec.bestScore) rec.bestScore = s;
    rec.save();
    onWin?.call();
  }

  void goReady() {
    phase = Phase.ready;
    // run an attract demo in the background
    daily = false;
    rng = math.Random();
    d = 0;
    color = 0;
    bars.clear();
    particles.clear();
    score = 0;
    combo = 0;
    speed = 300;
    zoneName = 'STEADY';
    bannerT = 99;
    spawnCursor = d + 360;
    lastColor = 0;
    runLen = 0;
    pattern = PatternKind.mixed;
    patStep = 0;
    _fill();
  }

  void tap() {
    if (phase != Phase.play) return;
    color = 1 - color;
    pop = 1.6;
    flipT = 0;
    flips++;
  }

  void _fill() {
    const look = 1700.0;
    while (spawnCursor < d + look) {
      spawnCursor += curSpacing;
      final gap = rng.nextDouble() < curGap;
      int c = lastColor;
      if (!gap) {
        c = _nextColor();
        lastColor = c;
        patStep++;
      }
      bars.add(Bar(spawnCursor, c, gap));
    }
  }

  /// Picks the next bar colour according to the active [pattern]. This is the
  /// heart of "different levels feel different".
  int _nextColor() {
    switch (pattern) {
      case PatternKind.alternate:
        return 1 - lastColor;
      case PatternKind.runs:
        // long same-colour runs, then flip — trains tap inhibition
        if (runLen >= 3 + rng.nextInt(3)) {
          runLen = 0;
          return 1 - lastColor;
        }
        runLen++;
        return lastColor;
      case PatternKind.doubles:
        // AA BB AA BB
        if (patStep.isOdd) return lastColor;
        return 1 - lastColor;
      case PatternKind.bursts:
        // tight clusters of alternation, occasional repeat to break rhythm
        return rng.nextDouble() < 0.2 ? lastColor : 1 - lastColor;
      case PatternKind.random:
        return rng.nextInt(2);
      case PatternKind.mixed:
        if (runLen >= 2) {
          runLen = 0;
          return 1 - lastColor;
        }
        if (rng.nextDouble() < 0.5) {
          runLen++;
          return lastColor;
        }
        runLen = 0;
        return 1 - lastColor;
    }
  }

  void _showBanner(String name, String sub) {
    bannerName = name;
    bannerSub = sub;
    bannerT = 0;
  }

  String _subFor(String z) {
    switch (z) {
      case 'RAPIDS': return 'pick up the pace';
      case 'BLACKOUT': return 'they vanish — read ahead';
      case 'STORM': return 'hold your focus';
    }
    return 'warm up';
  }

  void _absorb(Bar b) {
    b.live = false;
    combo++;
    if (combo > maxStreak) maxStreak = combo;
    final mult = multiplier;
    final last = flipT < 0.20 && !b.gap;
    score += (b.gap ? 4 : 10) * mult * (last ? 1.5 : 1);
    pop = math.max(pop, 1.3);
    bgTint = 0.35;
    final hue = b.gap ? 210.0 : polarHue(b.color);
    final sy = camY + (d - b.d);
    final n = b.gap ? 6 : (last ? 20 : 12);
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final sp = _lerp(40, last ? 340 : 200, rng.nextDouble());
      particles.add(Particle(w / 2, sy, math.cos(a) * sp, math.sin(a) * sp,
          _lerp(.35, .8, rng.nextDouble()), _lerp(2, last ? 5 : 4, rng.nextDouble()), hue));
    }
    if (last) {
      flash = 0.25;
      flashHue = hue;
    }
  }

  void _die(Bar b) {
    if (phase != Phase.play) return;
    phase = Phase.dead;
    deathT = 0;
    shake = 32;
    flash = 1;
    flashHue = polarHue(b.color);
    slow = 0.12;
    combo = 0;
    final sy = camY + (d - b.d);
    for (var i = 0; i < 95; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final sp = _lerp(60, 520, rng.nextDouble());
      particles.add(Particle(w / 2, sy, math.cos(a) * sp, math.sin(a) * sp,
          _lerp(.5, 1.1, rng.nextDouble()), _lerp(2, 5, rng.nextDouble()),
          polarHue(b.color) + _lerp(-20, 20, rng.nextDouble())));
    }
    _commit();
    onDeath?.call();
  }

  void _commit() {
    final s = score.floor();
    rec.totalRuns++;
    if (s > rec.bestScore) rec.bestScore = s;
    if (maxStreak > rec.bestStreak) rec.bestStreak = maxStreak;
    if (flips > rec.bestFlips) rec.bestFlips = flips;
    if (maxRank > rec.maxRank) rec.maxRank = maxRank;
    if (timeAlive.floor() > rec.bestTime) rec.bestTime = timeAlive.floor();
    if (daily) {
      final cur = rec.daily[dateKey] ?? 0;
      if (s > cur) rec.daily[dateKey] = s;
    }
    coinsEarned = (s / 12).floor() + maxRank * 8;
    rec.coins += coinsEarned;
    rec.save();
  }

  double get multiplier => 1 + math.min(combo, 60) * 0.05;

  // ---- frame ----
  void update(double dt) {
    slow = _lerp(slow, 1, 1 - math.exp(-dt * 4));
    flash = math.max(0, flash - dt * 3.2);
    shake = math.max(0, shake - dt * 60);
    bgTint = math.max(0, bgTint - dt * 1.1);
    pop = _lerp(pop, 1, 1 - math.exp(-dt * 10));
    flipT += dt;
    bannerT += dt;
    if (phase == Phase.dead) deathT += dt;

    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.96;
      p.vy *= 0.96;
      p.life -= dt / p.max;
    }
    particles.removeWhere((p) => p.life <= 0);

    if (phase == Phase.play) {
      _advance(dt, attract: false);
      if (!daily && rec.bestScore > 0 && !bestBeaten && score > rec.bestScore) {
        bestBeaten = true;
        flash = 0.4;
        flashHue = 50;
        _showBanner('NEW BEST', 'keep going');
      }
    } else if (phase == Phase.ready) {
      _advance(dt * 0.7, attract: true);
      if (d > 16000) goReady();
    }

    notifyListeners();
  }

  void _advance(double dt, {required bool attract}) {
    final sdt = dt * slow;
    speed = curSpeed;
    d += speed * sdt;
    if (!attract) timeAlive += dt;
    _fill();

    // zone change?
    final z = _zoneFor(d);
    if (z != zoneName) {
      zoneName = z;
      final r = zoneRank(z);
      if (r > maxRank) maxRank = r;
      if (!attract) {
        _showBanner(z, _subFor(z));
        flash = 0.3;
        shake = math.max(shake, 14);
      }
    }

    if (attract) {
      // autopilot: match the next color bar just before it arrives
      Bar? next;
      for (final b in bars) {
        if (b.live && !b.gap && b.d > d) {
          if (next == null || b.d < next.d) next = b;
        }
      }
      if (next != null && (next.d - d) < speed * 0.22 && color != next.color) {
        color = next.color;
        pop = 1.4;
      }
    }

    for (final b in bars) {
      if (b.live && b.d <= d) {
        if (b.gap || b.color == color) {
          _absorb(b);
        } else {
          b.live = false;
          _die(b);
        }
      }
    }
    if (bars.length > 90) bars.removeWhere((b) => b.d < d - 300);

    if (!attract && level != null && d >= level!.distance) _win();
  }
}

/// Renders the game field (background, bars, dart, particles). HUD/menus are widgets.
class VeerPainter extends CustomPainter {
  VeerPainter(this.g) : super(repaint: g);
  final VeerGame g;

  @override
  void paint(Canvas canvas, Size size) {
    g.w = size.width;
    g.h = size.height;
    final w = size.width, h = size.height;
    final camY = g.camY;

    canvas.save();
    if (g.shake > 0.1) {
      canvas.translate((g.rng.nextDouble() * 2 - 1) * g.shake * 0.4,
          (g.rng.nextDouble() * 2 - 1) * g.shake * 0.4);
    }

    // background
    final bg = Paint()
      ..shader = ui.Gradient.linear(
          Offset(0, 0), Offset(0, h), [const Color(0xFF070912), const Color(0xFF0A0E1C)]);
    canvas.drawRect(Rect.fromLTWH(-20, -20, w + 40, h + 40), bg);

    // colour wash from the dart
    final wash = Paint()
      ..shader = ui.Gradient.radial(Offset(w / 2, camY), h * 0.9, [
        _hsl(polarHue(g.color), 0.9, 0.55, 0.10 + g.bgTint * 0.12),
        const Color(0x00000000),
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wash);

    _drawBars(canvas, w, h, camY);
    if (g.phase != Phase.dead || g.deathT < 0.22) _drawDart(canvas, w, camY);
    _drawParticles(canvas);

    canvas.restore();

    if (g.flash > 0.001) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = _hsl(g.flashHue, 0.9, 0.7, g.flash * 0.5));
    }
    // vignette
    final vg = Paint()
      ..shader = ui.Gradient.radial(Offset(w / 2, h / 2), h * 0.78, [
        const Color(0x00000000),
        const Color(0x8C000000),
      ], [0.42, 1.0]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vg);
  }

  void _drawBars(Canvas canvas, double w, double h, double camY) {
    for (final b in g.bars) {
      if (!b.live) continue;
      final sy = camY + (g.d - b.d);
      if (sy < -40 || sy > h + 40) continue;
      final ahead = _clamp((b.d - g.d) / 1400, 0, 1);
      var fade = 1 - ahead * 0.55;
      if (g.blackout) {
        final near = _clamp((camY - sy) / 220, 0, 1); // 0 at dart, 1 far up
        fade *= _lerp(0.05, 1, near);
      }
      if (b.gap) {
        final p = Paint()
          ..color = _hsl(210, 0.4, 0.7, 0.22 * fade)
          ..strokeWidth = 3;
        _dashed(canvas, sy, w, p);
        continue;
      }
      final hue = polarHue(b.color);
      final th = _lerp(9, 16, 1 - ahead);
      final glow = Paint()
        ..color = _hsl(hue, 0.92, 0.6, fade)
        ..strokeWidth = th
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * fade);
      canvas.drawLine(Offset(0, sy), Offset(w, sy), glow);
      final core = Paint()
        ..color = _hsl(hue, 0.92, 0.6, fade)
        ..strokeWidth = th;
      canvas.drawLine(Offset(0, sy), Offset(w, sy), core);
      final hot = Paint()
        ..color = _hsl(hue, 1, 0.85, 0.7 * fade)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, sy), Offset(w, sy), hot);
    }
  }

  void _dashed(Canvas canvas, double sy, double w, Paint p) {
    const dash = 6.0, gap = 16.0;
    double x = 0;
    while (x < w) {
      canvas.drawLine(Offset(x, sy), Offset(math.min(x + dash, w), sy), p);
      x += dash + gap;
    }
  }

  void _drawDart(Canvas canvas, double w, double camY) {
    final hue = polarHue(g.color);
    final s = g.pop;
    canvas.save();
    canvas.translate(w / 2, camY);
    canvas.scale(s, s);
    final skin = skinById(g.rec.equipped);
    final path = _dartPath(skin.shape);
    canvas.drawPath(
        path,
        Paint()
          ..color = _hsl(hue, 0.95, 0.64)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawPath(path, Paint()..color = _hsl(hue, 0.95, 0.64));
    canvas.drawCircle(const Offset(0, -3), 3.4, Paint()..color = Colors.white);
    canvas.restore();
    canvas.drawCircle(
        Offset(w / 2, camY),
        26 * s,
        Paint()
          ..color = _hsl(hue, 0.9, 0.6, 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (skin.trail) {
      final t = _hsl(hue, 0.95, 0.6);
      canvas.drawRect(
        Rect.fromLTWH(w / 2 - 7, camY + 6, 14, 120),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, camY + 6), Offset(0, camY + 126),
              [t.withOpacity(0.45), t.withOpacity(0.0)])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in g.particles) {
      final a = _clamp(p.life, 0, 1);
      canvas.drawCircle(Offset(p.x, p.y), p.r * p.life, Paint()..color = _hsl(p.hue, 0.9, 0.65, a));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
