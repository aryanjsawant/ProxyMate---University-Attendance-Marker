// Generates the Play Store listing graphics.
//
//   dart run tool/make_store_graphics.dart
//
// Play requires a 512x512 icon and a 1024x500 feature graphic, neither of
// which the app itself needs. Generating them keeps the store listing in step
// with the app icon instead of drifting into a stale export from a design tool.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

final bg = ColorRgb8(15, 23, 42); // slate-900, same as the icon
final accent = ColorRgb8(99, 102, 241); // indigo-500
final white = ColorRgb8(255, 255, 255);
final muted = ColorRgb8(148, 163, 184);
final green = ColorRgb8(16, 185, 129);

void main() {
  Directory('docs/store').createSync(recursive: true);

  final icon = decodePng(File('assets/icon/icon.png').readAsBytesSync());
  if (icon == null) {
    stderr.writeln('Run tool/make_icon.dart first.');
    exit(1);
  }

  // 512x512 listing icon — a straight resample of the launcher icon.
  File('docs/store/icon-512.png').writeAsBytesSync(
    encodePng(copyResize(icon, width: 512, height: 512, interpolation: Interpolation.cubic)),
  );

  File('docs/store/feature-graphic.png')
      .writeAsBytesSync(encodePng(_featureGraphic(icon)));

  stdout.writeln('Wrote docs/store/icon-512.png and feature-graphic.png');
}

/// 1024x500. This is the banner at the top of the listing, and it is often
/// shown with text overlaid or cropped on small screens, so the important
/// content stays well inside the middle.
Image _featureGraphic(Image icon) {
  const w = 1024, h = 500;
  final img = Image(width: w, height: h, numChannels: 4);
  fill(img, color: bg);

  // A soft indigo wash from the left so the flat background has some depth.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final t = math.max(0.0, 1 - (x / (w * 0.75)));
      if (t <= 0) continue;
      final p = img.getPixel(x, y);
      img.setPixelRgb(
        x,
        y,
        (p.r + (accent.r - p.r) * t * 0.16).round(),
        (p.g + (accent.g - p.g) * t * 0.16).round(),
        (p.b + (accent.b - p.b) * t * 0.16).round(),
      );
    }
  }

  // App mark, left.
  final mark = copyResize(icon, width: 190, height: 190,
      interpolation: Interpolation.cubic);
  compositeImage(img, mark, dstX: 78, dstY: (h - 190) ~/ 2);

  // A miniature of the P/A/C row, right — the one idea worth showing.
  _pacRow(img, x: 560, y: 196);

  // Underline accent beneath the row.
  fillRect(img, x1: 560, y1: 300, x2: 560 + 300, y2: 304,
      radius: 2, color: accent);

  return img;
}

/// Draws three rounded chips: P selected in green, A and C inactive.
void _pacRow(Image img, {required int x, required int y}) {
  const chipW = 96, chipH = 72, gap = 14;

  fillRect(
    img,
    x1: x - 14,
    y1: y - 16,
    x2: x + chipW * 3 + gap * 2 + 14,
    y2: y + chipH + 16,
    radius: 20,
    color: ColorRgb8(30, 41, 59),
  );

  for (var i = 0; i < 3; i++) {
    final left = x + i * (chipW + gap);
    fillRect(
      img,
      x1: left,
      y1: y,
      x2: left + chipW,
      y2: y + chipH,
      radius: 14,
      color: i == 0 ? green : ColorRgb8(51, 65, 85),
    );
    _glyph(img, i, left + chipW ~/ 2, y + chipH ~/ 2, i == 0 ? white : muted);
  }
}

/// P, A and C drawn as strokes. Three letters is not worth a font dependency.
void _glyph(Image img, int which, int cx, int cy, Color colour) {
  const t = 7.0;
  final hh = 17.0, hw = 13.0;

  switch (which) {
    case 0: // P
      _line(img, cx - hw, cy - hh, cx - hw, cy + hh, t, colour);
      _line(img, cx - hw, cy - hh, cx + hw * 0.7, cy - hh, t, colour);
      _line(img, cx + hw * 0.7, cy - hh, cx + hw * 0.7, cy, t, colour);
      _line(img, cx + hw * 0.7, cy, cx - hw, cy, t, colour);
    case 1: // A
      _line(img, cx - hw, cy + hh, cx, cy - hh, t, colour);
      _line(img, cx, cy - hh, cx + hw, cy + hh, t, colour);
      _line(img, cx - hw * 0.55, cy + hh * 0.25, cx + hw * 0.55, cy + hh * 0.25,
          t, colour);
    case 2: // C
      _arcStroke(img, cx, cy, hw, hh, t, colour);
  }
}

void _line(Image img, num x1, num y1, num x2, num y2, double thickness,
    Color colour) {
  final r = thickness / 2;
  final minX = (math.min(x1, x2) - r - 1).floor();
  final maxX = (math.max(x1, x2) + r + 1).ceil();
  final minY = (math.min(y1, y2) - r - 1).floor();
  final maxY = (math.max(y1, y2) + r + 1).ceil();
  final dx = x2 - x1, dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      final px = x + 0.5, py = y + 0.5;
      var s = lenSq == 0 ? 0.0 : ((px - x1) * dx + (py - y1) * dy) / lenSq;
      s = s.clamp(0.0, 1.0);
      final d = math.sqrt(math.pow(px - (x1 + s * dx), 2) +
          math.pow(py - (y1 + s * dy), 2));
      final a = ((r - d + 0.5).clamp(0.0, 1.0) * 255).round();
      if (a > 0) _blend(img, x, y, colour, a);
    }
  }
}

/// The open side of the C faces right, so it reads as a letter not a ring.
void _arcStroke(Image img, int cx, int cy, double rx, double ry,
    double thickness, Color colour) {
  final half = thickness / 2;
  for (var y = (cy - ry - half - 1).floor();
      y <= (cy + ry + half + 1).ceil();
      y++) {
    for (var x = (cx - rx - half - 1).floor();
        x <= (cx + rx + half + 1).ceil();
        x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      final px = (x + 0.5 - cx) / rx, py = (y + 0.5 - cy) / ry;
      final dist = math.sqrt(px * px + py * py);
      final scale = (rx + ry) / 2;
      final a = ((half - (dist - 1).abs() * scale + 0.5).clamp(0.0, 1.0) * 255)
          .round();
      if (a <= 0) continue;
      var angle = math.atan2(py, px);
      if (angle < 0) angle += 2 * math.pi;
      // Leave a gap between roughly -50 and +50 degrees.
      if (angle < 0.9 || angle > 2 * math.pi - 0.9) continue;
      _blend(img, x, y, colour, a);
    }
  }
}

void _blend(Image img, int x, int y, Color src, int alpha) {
  final dst = img.getPixel(x, y);
  final a = alpha / 255;
  img.setPixelRgb(
    x,
    y,
    (src.r * a + dst.r * (1 - a)).round(),
    (src.g * a + dst.g * (1 - a)).round(),
    (src.b * a + dst.b * (1 - a)).round(),
  );
}
