import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_deck/story_deck.dart';

import 'support/harness.dart';

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class Rig {
  final made = <String, SimulatedStoryVideoAdapter>{};
  final controller = StoryController();

  StoryVideoAdapter create(StoryItem item, {Duration? initDelay}) {
    return made[item.id] = SimulatedStoryVideoAdapter(
      length: const Duration(seconds: 4),
      initializeDelay: initDelay ?? Duration.zero,
    );
  }

  Widget deck({
    List<StoryGroup>? groups,
    Duration? initDelay,
    Duration? cap,
  }) {
    return StoryDeck(
      groups: groups ??
          [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.video(id: 'v0', videoSource: 'x', duration: cap),
              customItem('c1'),
              StoryItem.video(id: 'v2', videoSource: 'y'),
            ]),
          ],
      controller: controller,
      videoAdapterFactory: (item) => create(item, initDelay: initDelay),
    );
  }
}

void main() {
  group('video sync (story_view #87-style bugs)', () {
    testWidgets('progress follows the real video position, not a timer',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 1000);
      final a = rig.made['v0']!;
      expect(a.isPlaying, isTrue);
      expect(rig.controller.progress.value,
          closeTo(a.position.inMicroseconds / a.length.inMicroseconds, 0.02));
      // A free-running 5 s default timer would say 0.2 here; the 4 s video says 0.25.
      expect(rig.controller.progress.value, closeTo(0.25, 0.02));
    });

    testWidgets('buffering stops the progress bar until data flows again',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 1000);
      final a = rig.made['v0']!;
      a.stall();
      await tester.pump();
      final frozen = rig.controller.progress.value;
      final frozenPos = a.position;
      await pumpMs(tester, 3000);
      expect(rig.controller.progress.value, frozen);
      expect(a.position, frozenPos);
      expect(rig.controller.itemIndex, 0,
          reason: 'did not advance while stalled');
      a.unstall();
      await pumpMs(tester, 1000);
      expect(rig.controller.progress.value, greaterThan(frozen + 0.15));
    });

    testWidgets('setBuffering(true) on any item stops its timer',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      StoryPlayback? pb;
      await pumpDeck(
        tester,
        StoryDeck(
          controller: c,
          groups: [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.custom(
                id: 'x',
                duration: const Duration(seconds: 2),
                builder: (context, p) {
                  if (p.isActive) pb = p;
                  return const SizedBox.expand();
                },
              ),
              customItem('y'),
            ]),
          ],
        ),
      );
      await pumpMs(tester, 500);
      pb!.setBuffering(true);
      final frozen = c.progress.value;
      await pumpMs(tester, 5000);
      expect(c.progress.value, frozen);
      expect(c.itemIndex, 0);
      pb!.setBuffering(false);
      await pumpMs(tester, 500);
      expect(c.progress.value, greaterThan(frozen));
    });

    testWidgets('the item ends when the video ends and the next one starts',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 4300);
      expect(rig.controller.itemIndex, 1);
    });

    testWidgets('the bar does not run while the video is still opening',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck(initDelay: const Duration(seconds: 2)));
      await pumpMs(tester, 1500);
      expect(rig.controller.progress.value, 0);
      await pumpMs(tester, 1500);
      expect(rig.controller.progress.value, greaterThan(0));
      expect(rig.controller.itemIndex, 0);
    });

    testWidgets('an item duration caps a longer video', (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck(cap: const Duration(seconds: 2)));
      await pumpMs(tester, 1000);
      expect(rig.controller.progress.value, closeTo(0.5, 0.06));
      await pumpMs(tester, 1200);
      expect(rig.controller.itemIndex, 1);
    });
  });

  group('no video keeps playing in the background', () {
    testWidgets('moving to the next story pauses and disposes the video',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 500);
      final a = rig.made['v0']!;
      expect(a.isPlaying, isTrue);
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(a.isPlaying, isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(a.isDisposed, isTrue);
    });

    testWidgets('removing the deck (dismiss / route pop) stops the video',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 500);
      final a = rig.made['v0']!;
      await tester.pumpWidget(harness(const SizedBox()));
      await tester.pump();
      expect(a.isPlaying, isFalse);
      expect(a.isDisposed, isTrue);
    });

    testWidgets('app in the background pauses the video, resume continues',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 500);
      final a = rig.made['v0']!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(a.isPlaying, isFalse);
      final pos = a.position;
      await pumpMs(tester, 2000);
      expect(a.position, pos);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpMs(tester, 500);
      expect(a.isPlaying, isTrue);
      expect(a.position, greaterThan(pos));
    });

    testWidgets('holding the screen pauses the video, release resumes it',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(tester, rig.deck());
      await pumpMs(tester, 500);
      final a = rig.made['v0']!;
      final g = await tester.startGesture(const Offset(200, 400));
      await pumpMs(tester, 400);
      expect(a.isPlaying, isFalse);
      await g.up();
      await pumpMs(tester, 100);
      expect(a.isPlaying, isTrue);
      expect(rig.controller.itemIndex, 0);
    });

    testWidgets('switching to another user stops the previous user\'s video',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(
        tester,
        rig.deck(groups: [
          StoryGroup(id: 'a', title: 'A', items: [
            StoryItem.video(id: 'va', videoSource: 'x'),
          ]),
          StoryGroup(id: 'b', title: 'B', items: [
            StoryItem.video(id: 'vb', videoSource: 'y'),
          ]),
        ]),
      );
      await pumpMs(tester, 500);
      final a = rig.made['va']!;
      final b = rig.made['vb']!;
      expect(a.isPlaying, isTrue);
      expect(b.isPlaying, isFalse,
          reason: 'neighbour is preloaded, not playing');
      rig.controller.nextGroup();
      await pumpMs(tester, 1000);
      expect(rig.controller.groupIndex, 1);
      expect(a.isPlaying, isFalse);
      expect(b.isPlaying, isTrue);
    });
  });

  group('preloading', () {
    testWidgets('the next video is initialized before it is shown',
        (tester) async {
      setPhone(tester);
      final rig = Rig();
      await pumpDeck(
        tester,
        rig.deck(groups: [
          StoryGroup(id: 'a', title: 'A', items: [
            customItem('c0'),
            StoryItem.video(id: 'v1', videoSource: 'x'),
          ]),
        ]),
      );
      await pumpMs(tester, 100);
      expect(rig.made.containsKey('v1'), isTrue);
      expect(rig.made['v1']!.isPlaying, isFalse);
    });

    testWidgets('a video item without an adapter factory fails gracefully',
        (tester) async {
      setPhone(tester);
      final errors = <Object>[];
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.video(id: 'v', videoSource: 'x'),
            ]),
          ],
          onItemError: (g, i, e) => errors.add(e),
        ),
      );
      await pumpMs(tester, 100);
      expect(find.text('Could not load this story'), findsOneWidget);
      expect(errors, hasLength(1));
    });
  });
}
