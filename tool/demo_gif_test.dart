@Tags(['demo'])
library;

// ignore_for_file: avoid_relative_lib_imports
//
// Renders the README demo frames and screenshots deterministically (no
// device needed). Run through tool/make_demo.sh, which also builds the GIF.
//
// The images and the "video" in the demo are generated in code. The video is
// SimulatedStoryVideoAdapter, not a real player, so nothing here is a device
// capture.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_deck/story_deck.dart';
import '../example/lib/data.dart';
import '../example/lib/main.dart';
import '../example/lib/settings.dart';
import '../example/lib/viewer_page.dart';

const _frameMs = 67; // ~15 fps

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('tool/fonts/Roboto-Regular.ttf'))
    ..addFont(bytes('tool/fonts/Roboto-Medium.ttf'))
    ..addFont(bytes('tool/fonts/Roboto-Bold.ttf'));
  await roboto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final l = FontLoader('MaterialIcons')..addFont(bytes(icons.path));
      await l.load();
    }
  }
}

void main() {
  final boundaryKey = GlobalKey();
  late Directory frames;
  var n = 0;

  Future<void> shot(WidgetTester tester, String path,
      {double ratio = 2}) async {
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> frame(WidgetTester tester, {int count = 1}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: _frameMs));
      final name = 'frame_${(n++).toString().padLeft(4, '0')}.png';
      await shot(tester, '${frames.path}/$name');
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<List<StoryGroup>> prepare(WidgetTester tester) async {
    await _loadFonts();
    final groups = (await tester
        .runAsync(() => buildDemoGroups(now: DateTime(2026, 10, 29, 12))))!;
    return groups;
  }

  Future<void> precache(WidgetTester tester, List<StoryGroup> groups) async {
    final ctx = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final g in groups) {
        if (g.avatar != null) await precacheImage(g.avatar!, ctx);
        for (final i in g.items) {
          if (i.image != null) await precacheImage(i.image!, ctx);
        }
      }
    });
    await tester.pump();
  }

  Widget host(Widget app) => RepaintBoundary(key: boundaryKey, child: app);

  testWidgets('demo gif frames', (tester) async {
    phone(tester);
    final groups = await prepare(tester);
    frames = Directory('build/demo_frames')..createSync(recursive: true);
    for (final f in frames.listSync()) {
      if (f is File && f.path.endsWith('.png')) f.deleteSync();
    }
    await tester.pumpWidget(
        host(StoryDeckExampleApp(groups: groups, fontFamily: 'Roboto')));
    await tester.pump();
    await precache(tester, groups);

    // Home tray.
    await frame(tester, count: 4);
    await tester.tap(find.byType(CircleAvatar).first);
    await frame(tester, count: 4); // route fades in
    await frame(tester, count: 14); // progress bars run

    // Tap through two items.
    Offset right() => const Offset(280, 300);
    await tester.tapAt(right());
    await frame(tester, count: 7);
    await tester.tapAt(right());
    await frame(tester, count: 8);
    // Tap again: last item of the first user ends -> 3D cube to next user.
    await tester.tapAt(right());
    await frame(tester, count: 12);
    await frame(tester, count: 8);

    // Swipe down to close.
    final g = await tester.startGesture(const Offset(180, 260));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 34));
      await frame(tester);
    }
    await g.up();
    await frame(tester, count: 10);
    // ignore: avoid_print
    print('frames: $n');
  });

  testWidgets('screenshots', (tester) async {
    phone(tester);
    final groups = await prepare(tester);
    Directory('doc').createSync(recursive: true);

    Future<void> open(DeckSettings s) async {
      await tester.pumpWidget(host(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: StoryViewerPage(
          groups: groups,
          startGroup: 0,
          settings: s,
          store: MemoryStoryViewStore(),
        ),
      )));
      await tester.pump();
      await precache(tester, groups);
    }

    await open(DeckSettings()..preset = ThemePreset.paper);
    await tester.pump(const Duration(milliseconds: 1200));
    await shot(tester, 'doc/screenshot_light.png');

    await open(DeckSettings());
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 160));
    await shot(tester, 'doc/screenshot_dark.png');
  });
}
