import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_deck/story_deck.dart';

/// 1x1 PNG.
final Uint8List kPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

/// An image provider that never finishes loading.
class NeverLoadingImage extends ImageProvider<NeverLoadingImage> {
  const NeverLoadingImage();

  @override
  Future<NeverLoadingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<NeverLoadingImage>(this);

  @override
  ImageStreamCompleter loadImage(
          NeverLoadingImage key, ImageDecoderCallback decode) =>
      _Never();
}

class _Never extends ImageStreamCompleter {}

StoryItem customItem(String id, {Duration? duration, String? caption}) =>
    StoryItem.custom(
      id: id,
      duration: duration ?? const Duration(seconds: 2),
      caption: caption,
      builder: (context, playback) => const SizedBox.expand(),
    );

StoryGroup makeGroup(String id, int count, {Duration? duration}) => StoryGroup(
      id: id,
      title: 'User $id',
      items: [
        for (var i = 0; i < count; i++) customItem('$id$i', duration: duration)
      ],
    );

Widget harness(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Center(child: SizedBox(width: 400, height: 800, child: child)),
      ),
    );

/// Pumps [ms] milliseconds in 50 ms frames.
Future<void> pumpMs(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the deck with a first frame, letting async init finish.
Future<void> pumpDeck(WidgetTester tester, Widget deck) async {
  await tester.pumpWidget(harness(deck));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}
