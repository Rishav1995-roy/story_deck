import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The kinds of generated artwork.
enum ArtKind { sunset, waves, mountains, bubbles, stripes }

/// Describes one generated picture. Everything is drawn in code, so the
/// example ships no photos.
class ArtSpec {
  const ArtSpec(this.kind, this.top, this.bottom, {this.seed = 1});

  final ArtKind kind;
  final Color top;
  final Color bottom;
  final int seed;
}

/// Paints [spec] into [canvas].
void paintArt(Canvas canvas, Size size, ArtSpec spec) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
          rect.topCenter, rect.bottomCenter, [spec.top, spec.bottom]),
  );
  final rnd = math.Random(spec.seed);
  final w = size.width;
  final h = size.height;
  switch (spec.kind) {
    case ArtKind.sunset:
      canvas.drawCircle(
          Offset(w * 0.5, h * 0.42),
          w * 0.26,
          Paint()
            ..shader = ui.Gradient.radial(Offset(w * 0.5, h * 0.42), w * 0.26,
                [const Color(0xFFFFF3B0), const Color(0xFFFF8C42)]));
      for (var i = 0; i < 4; i++) {
        final base = h * (0.6 + i * 0.1);
        final path = Path()..moveTo(0, h);
        path.lineTo(0, base);
        for (var x = 0.0; x <= w; x += w / 24) {
          path.lineTo(
              x, base - 40 * math.sin(x / w * 6 + i + spec.seed) - 20 * i);
        }
        path.lineTo(w, h);
        canvas.drawPath(
            path,
            Paint()
              ..color = Color.lerp(
                  spec.bottom, const Color(0xFF1B1030), 0.25 + i * 0.22)!);
      }
    case ArtKind.waves:
      for (var i = 0; i < 7; i++) {
        final base = h * (0.3 + i * 0.1);
        final path = Path()..moveTo(0, h);
        path.lineTo(0, base);
        for (var x = 0.0; x <= w; x += 8) {
          path.lineTo(x, base + 26 * math.sin(x / 60 + i * 1.3 + spec.seed));
        }
        path.lineTo(w, h);
        canvas.drawPath(
            path,
            Paint()
              ..color = Color.lerp(spec.top, spec.bottom, i / 6)!
                  .withValues(alpha: 0.75));
      }
    case ArtKind.mountains:
      for (var layer = 0; layer < 4; layer++) {
        final path = Path()..moveTo(0, h);
        var x = -40.0;
        final base = h * (0.55 + layer * 0.1);
        while (x < w + 80) {
          final peak = base - 60 - rnd.nextDouble() * 160 + layer * 20;
          path.lineTo(x, base);
          path.lineTo(x + 60 + rnd.nextDouble() * 50, peak);
          x += 130 + rnd.nextDouble() * 60;
        }
        path.lineTo(w + 100, base);
        path.lineTo(w + 100, h);
        canvas.drawPath(
            path,
            Paint()
              ..color = Color.lerp(
                  spec.top, const Color(0xFF0B132B), 0.3 + layer * 0.2)!);
      }
    case ArtKind.bubbles:
      for (var i = 0; i < 26; i++) {
        final r = 20 + rnd.nextDouble() * 80;
        canvas.drawCircle(
            Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
            r,
            Paint()
              ..color = Color.lerp(spec.top, spec.bottom, rnd.nextDouble())!
                  .withValues(alpha: 0.35 + rnd.nextDouble() * 0.4));
      }
    case ArtKind.stripes:
      canvas.save();
      canvas.rotate(-0.5);
      for (var i = -10; i < 24; i++) {
        canvas.drawRect(
            Rect.fromLTWH(i * 70.0 - 200, -300, 34, h + 800),
            Paint()
              ..color = Color.lerp(spec.top, spec.bottom, (i % 6) / 5)!
                  .withValues(alpha: 0.55));
      }
      canvas.restore();
  }
}

/// Renders [spec] to a PNG-backed [ImageProvider].
Future<ImageProvider> renderArt(ArtSpec spec,
    {Size size = const Size(540, 960)}) async {
  final recorder = ui.PictureRecorder();
  paintArt(Canvas(recorder), size, spec);
  final image = await recorder
      .endRecording()
      .toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(data!.buffer.asUint8List());
}

/// Renders a round avatar with a simple face-less glyph.
Future<ImageProvider> renderAvatar(Color a, Color b, int seed) async {
  const size = Size(160, 160);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader =
            ui.Gradient.linear(Offset.zero, const Offset(160, 160), [a, b]));
  final rnd = math.Random(seed);
  canvas.drawCircle(
      Offset(80, 64), 28, Paint()..color = const Color(0xCCFFFFFF));
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(80, 150), width: 110, height: 90),
      Paint()..color = const Color(0xCCFFFFFF));
  canvas.drawCircle(Offset(30 + rnd.nextDouble() * 100, 30), 6,
      Paint()..color = const Color(0x55FFFFFF));
  final image = await recorder.endRecording().toImage(160, 160);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(data!.buffer.asUint8List());
}
