// Generates the launcher icon source images.
//
// Run with:  dart run tool/make_icon.dart
//
// The mark is a tick inside a rounded square — "you were there" — on the same
// indigo the app themes from. Kept as a script rather than a checked-in binary
// so the icon can be re-tuned without a design tool.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

const size = 1024;
final bg = ColorRgb8(15, 23, 42); // slate-900, matches the splash
final accent = ColorRgb8(99, 102, 241); // indigo-500
final tickColour = ColorRgb8(255, 255, 255);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  _write('assets/icon/icon.png', _compose(withBackground: true));
  // Adaptive icons get the background from app.json/manifest, so the
  // foreground layer must be transparent and inset into the safe zone.
  _write('assets/icon/foreground.png', _compose(withBackground: false));

  stdout.writeln('Wrote assets/icon/icon.png and foreground.png');
}

void _write(String path, Image img) =>
    File(path).writeAsBytesSync(encodePng(img));

Image _compose({required bool withBackground}) {
  final img = Image(width: size, height: size, numChannels: 4);
  fill(img, color: ColorRgba8(0, 0, 0, 0));

  if (withBackground) {
    fillRect(
      img,
      x1: 0,
      y1: 0,
      x2: size - 1,
      y2: size - 1,
      radius: size * 0.22,
      color: bg,
    );
  }

  // Adaptive foregrounds are cropped hard; keep the mark inside the middle ~66%.
  final scale = withBackground ? 1.0 : 0.66;
  final cx = size / 2;
  final cy = size / 2;

  // Accent ring, evoking the percentage dial on the subject screen.
  final ringR = size * 0.30 * scale;
  final ringWidth = size * 0.055 * scale;
  _arc(
    img,
    cx: cx,
    cy: cy,
    radius: ringR,
    thickness: ringWidth,
    startDeg: 130,
    sweepDeg: 280,
    colour: accent,
  );

  // The tick.
  final t = size * 0.075 * scale;
  _thickLine(
    img,
    x1: cx - size * 0.135 * scale,
    y1: cy + size * 0.005 * scale,
    x2: cx - size * 0.030 * scale,
    y2: cy + size * 0.105 * scale,
    thickness: t,
    colour: tickColour,
  );
  _thickLine(
    img,
    x1: cx - size * 0.030 * scale,
    y1: cy + size * 0.105 * scale,
    x2: cx + size * 0.155 * scale,
    y2: cy - size * 0.115 * scale,
    thickness: t,
    colour: tickColour,
  );

  return img;
}

/// Anti-aliased thick line via per-pixel distance to the segment.
void _thickLine(
  Image img, {
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  required double thickness,
  required Color colour,
}) {
  final r = thickness / 2;
  final minX = math.max(0, (math.min(x1, x2) - r - 2).floor());
  final maxX = math.min(size - 1, (math.max(x1, x2) + r + 2).ceil());
  final minY = math.max(0, (math.min(y1, y2) - r - 2).floor());
  final maxY = math.min(size - 1, (math.max(y1, y2) + r + 2).ceil());

  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final px = x + 0.5, py = y + 0.5;
      var t = lenSq == 0 ? 0.0 : ((px - x1) * dx + (py - y1) * dy) / lenSq;
      t = t.clamp(0.0, 1.0);
      final d = math.sqrt(
        math.pow(px - (x1 + t * dx), 2) + math.pow(py - (y1 + t * dy), 2),
      );
      final alpha = ((r - d + 0.5).clamp(0.0, 1.0) * 255).round();
      if (alpha > 0) _blend(img, x, y, colour, alpha);
    }
  }
}

/// Anti-aliased arc via distance to the circle, clipped to an angular sweep.
void _arc(
  Image img, {
  required double cx,
  required double cy,
  required double radius,
  required double thickness,
  required double startDeg,
  required double sweepDeg,
  required Color colour,
}) {
  final half = thickness / 2;
  final start = startDeg * math.pi / 180;
  final sweep = sweepDeg * math.pi / 180;

  final minX = math.max(0, (cx - radius - half - 2).floor());
  final maxX = math.min(size - 1, (cx + radius + half + 2).ceil());
  final minY = math.max(0, (cy - radius - half - 2).floor());
  final maxY = math.min(size - 1, (cy + radius + half + 2).ceil());

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final px = x + 0.5 - cx, py = y + 0.5 - cy;
      final dist = math.sqrt(px * px + py * py);
      final radial = (half - (dist - radius).abs() + 0.5).clamp(0.0, 1.0);
      if (radial <= 0) continue;

      var angle = math.atan2(py, px);
      if (angle < 0) angle += 2 * math.pi;
      var rel = angle - start;
      while (rel < 0) {
        rel += 2 * math.pi;
      }
      if (rel > sweep) continue;

      _blend(img, x, y, colour, (radial * 255).round());
    }
  }
}

void _blend(Image img, int x, int y, Color src, int alpha) {
  final dst = img.getPixel(x, y);
  final a = alpha / 255;
  final da = dst.a / 255;
  final outA = a + da * (1 - a);
  if (outA <= 0) return;

  double mix(num s, num d) => (s * a + d * da * (1 - a)) / outA;

  img.setPixelRgba(
    x,
    y,
    mix(src.r, dst.r).round(),
    mix(src.g, dst.g).round(),
    mix(src.b, dst.b).round(),
    (outA * 255).round(),
  );
}
