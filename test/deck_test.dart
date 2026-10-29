import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_deck/story_deck.dart';

import 'support/harness.dart';

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('basics', () {
    testWidgets('auto-advances after the item duration and reports callbacks',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      final seen = <String>[];
      final changed = <StoryPosition>[];
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [makeGroup('a', 3)],
          controller: c,
          onItemSeen: (g, i) => seen.add(i.id),
          onItemChanged: changed.add,
        ),
      );
      expect(c.position, const StoryPosition(0, 0));
      await pumpMs(tester, 1000);
      expect(c.progress.value, closeTo(0.5, 0.06));
      await pumpMs(tester, 1100);
      expect(c.position, const StoryPosition(0, 1));
      expect(seen, ['a0', 'a1']);
      expect(changed, contains(const StoryPosition(0, 1)));
    });

    testWidgets('tap right = next, tap left = previous', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester, StoryDeck(groups: [makeGroup('a', 4)], controller: c));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(c.itemIndex, 1);
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(c.itemIndex, 2);
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      expect(c.itemIndex, 1);
    });

    testWidgets('tap zones flip in right-to-left layouts', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: StoryDeck(groups: [makeGroup('a', 4)], controller: c),
        ),
      ));
      await tester.pump();
      await tester.tapAt(const Offset(40, 400)); // physical left = next in RTL
      await tester.pump();
      expect(c.itemIndex, 1);
    });

    testWidgets('hold pauses the progress and release resumes', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester, StoryDeck(groups: [makeGroup('a', 3)], controller: c));
      await pumpMs(tester, 500);
      final gesture = await tester.startGesture(const Offset(200, 400));
      await pumpMs(tester, 300); // hold delay passes
      final frozen = c.progress.value;
      await pumpMs(tester, 3000);
      expect(c.progress.value, frozen, reason: 'paused while held');
      expect(c.itemIndex, 0);
      await gesture.up();
      await tester.pump();
      expect(c.itemIndex, 0, reason: 'a hold release is not a tap');
      await pumpMs(tester, 500);
      expect(c.progress.value, greaterThan(frozen));
    });

    testWidgets('swipe down dismisses', (tester) async {
      setPhone(tester);
      var dismissed = 0;
      await pumpDeck(tester,
          StoryDeck(groups: [makeGroup('a', 2)], onDismiss: () => dismissed++));
      await tester.fling(find.byType(StoryDeck), const Offset(0, 400), 1500);
      await pumpMs(tester, 400);
      expect(dismissed, 1);
    });

    testWidgets('short slow swipe down springs back, no dismiss',
        (tester) async {
      setPhone(tester);
      var dismissed = 0;
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(
              groups: [makeGroup('a', 2)],
              controller: c,
              onDismiss: () => dismissed++));
      final g = await tester.startGesture(const Offset(200, 300));
      await g.moveBy(const Offset(0, 40));
      await g.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      await pumpMs(tester, 400);
      expect(dismissed, 0);
      await pumpMs(tester, 500);
      expect(c.progress.value, greaterThan(0), reason: 'resumed after drag');
    });

    testWidgets('swipe up fires the action hook', (tester) async {
      setPhone(tester);
      StoryItem? got;
      await pumpDeck(tester,
          StoryDeck(groups: [makeGroup('a', 2)], onSwipeUp: (g, i) => got = i));
      await tester.fling(find.byType(StoryDeck), const Offset(0, -300), 1500);
      await pumpMs(tester, 400);
      expect(got?.id, 'a0');
    });

    testWidgets('finishing the last item of the last group calls onComplete',
        (tester) async {
      setPhone(tester);
      var done = 0;
      final completed = <int>[];
      await pumpDeck(
          tester,
          StoryDeck(
            groups: [makeGroup('a', 1, duration: const Duration(seconds: 1))],
            onComplete: () => done++,
            onGroupCompleted: (g, i) => completed.add(i),
          ));
      await pumpMs(tester, 1200);
      expect(done, 1);
      expect(completed, [0]);
    });

    testWidgets('controller pause/resume/next', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester, StoryDeck(groups: [makeGroup('a', 3)], controller: c));
      c.pause();
      expect(c.isPaused, isTrue);
      await pumpMs(tester, 2500);
      expect(c.itemIndex, 0);
      c.resume();
      c.next();
      await tester.pump();
      expect(c.itemIndex, 1);
      c.jumpTo(0, 2);
      await tester.pump();
      expect(c.position, const StoryPosition(0, 2));
    });

    testWidgets('progress bars show completed, current and upcoming segments',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester, StoryDeck(groups: [makeGroup('a', 3)], controller: c));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(find.byType(StoryProgressBars), findsOneWidget);
      final bars =
          tester.widget<StoryProgressBars>(find.byType(StoryProgressBars));
      expect(bars.count, 3);
      expect(bars.currentIndex, 1);
    });
  });

  group('users and transitions', () {
    testWidgets('finishing a group animates to the next user (cube)',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(groups: [
            makeGroup('a', 1, duration: const Duration(seconds: 1)),
            makeGroup('b', 2),
          ], controller: c));
      await pumpMs(tester, 1100);
      // mid transition: the cube transform is applied to the pages
      expect(find.byType(Transform), findsWidgets);
      await pumpMs(tester, 600);
      expect(c.position, const StoryPosition(1, 0));
      await pumpMs(tester, 500);
      expect(c.progress.value, greaterThan(0), reason: 'new user is playing');
    });

    testWidgets('swiping horizontally switches users', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(
              groups: [makeGroup('a', 2), makeGroup('b', 2)], controller: c));
      await tester.fling(find.byType(StoryDeck), const Offset(-300, 0), 1500);
      await pumpMs(tester, 800);
      expect(c.groupIndex, 1);
    });

    testWidgets('resume position per user (lastViewed)', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(
              groups: [makeGroup('a', 4), makeGroup('b', 2)], controller: c));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(c.position, const StoryPosition(0, 2));
      c.nextGroup();
      await pumpMs(tester, 900);
      expect(c.position, const StoryPosition(1, 0));
      c.previousGroup();
      await pumpMs(tester, 900);
      expect(c.position, const StoryPosition(0, 2),
          reason: 'user a resumes where it was left');
    });

    testWidgets('a fully watched user starts over', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(groups: [
            makeGroup('a', 2, duration: const Duration(seconds: 1)),
            makeGroup('b', 2),
          ], controller: c));
      await pumpMs(tester, 2300);
      await pumpMs(tester, 600);
      expect(c.groupIndex, 1);
      c.previousGroup();
      await pumpMs(tester, 900);
      expect(c.position, const StoryPosition(0, 0));
    });

    testWidgets('changing the card layout at runtime does not break the pager',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      Widget build(double? aspect) => StoryDeck(
          groups: [makeGroup('a', 2), makeGroup('b', 2)],
          controller: c,
          aspectRatio: aspect);
      await pumpDeck(tester, build(null));
      await tester.pumpWidget(harness(build(0.5)));
      await tester.pump();
      await tester.pumpWidget(harness(build(null)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      c.nextGroup();
      await pumpMs(tester, 900);
      expect(c.groupIndex, 1);
    });

    testWidgets('every transition style builds and settles', (tester) async {
      setPhone(tester);
      for (final t in [
        StoryTransition.cube,
        StoryTransition.slide,
        StoryTransition.depth,
        StoryTransition.fade,
      ]) {
        final c = StoryController();
        await pumpDeck(
            tester,
            StoryDeck(
                key: UniqueKey(),
                groups: [makeGroup('a', 1), makeGroup('b', 1)],
                controller: c,
                transition: t));
        c.nextGroup();
        await pumpMs(tester, 250);
        await pumpMs(tester, 500);
        expect(c.groupIndex, 1);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('keyboard and mouse (web / desktop)', () {
    testWidgets('arrow keys, page keys, space and escape', (tester) async {
      setPhone(tester);
      final c = StoryController();
      var dismissed = 0;
      await pumpDeck(
          tester,
          StoryDeck(
              groups: [makeGroup('a', 3), makeGroup('b', 2)],
              controller: c,
              onDismiss: () => dismissed++));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.itemIndex, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(c.itemIndex, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(c.isPaused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(c.isPaused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await pumpMs(tester, 900);
      expect(c.groupIndex, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
    });

    testWidgets('mouse click zones and press-and-hold work', (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester, StoryDeck(groups: [makeGroup('a', 3)], controller: c));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(const Offset(300, 400));
      await mouse.up();
      await tester.pump();
      expect(c.itemIndex, 1);

      await mouse.down(const Offset(200, 400));
      await pumpMs(tester, 300);
      final frozen = c.progress.value;
      await pumpMs(tester, 1000);
      expect(c.progress.value, frozen);
      await mouse.up();
      await tester.pump();
      expect(c.itemIndex, 1);
    });

    testWidgets('hover shows previous/next arrows that navigate',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(
              groups: [makeGroup('a', 3)],
              controller: c,
              showNavigationArrows: true));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(200, 400));
      await mouse.moveTo(const Offset(210, 400));
      await tester.pump();
      await tester.tapAt(const Offset(392 - 18, 400)); // right arrow
      await tester.pump();
      expect(c.itemIndex, 1);
    });

    testWidgets('typing in a text field does not trigger shortcuts',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
          tester,
          StoryDeck(
            groups: [makeGroup('a', 3)],
            controller: c,
            footerBuilder: (context, d) =>
                StoryReplyBar(controller: d.controller, onSend: (_) {}),
          ));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(c.isPaused, isTrue, reason: 'focus pauses the story');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.itemIndex, 0);
    });
  });

  group('media loading', () {
    testWidgets('the timer does not start before the image has loaded',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [
            StoryGroup(id: 'a', title: 'A', items: const [
              StoryItem.image(
                  id: 'slow',
                  image: NeverLoadingImage(),
                  duration: Duration(seconds: 1)),
              StoryItem.image(id: 'n', image: NeverLoadingImage()),
            ]),
          ],
          controller: c,
        ),
      );
      await pumpMs(tester, 6000);
      expect(c.itemIndex, 0, reason: 'still loading, no time consumed');
      expect(c.progress.value, 0);
    });

    testWidgets('an image item advances once loaded', (tester) async {
      setPhone(tester);
      final img = MemoryImage(kPng);
      await tester.pumpWidget(harness(const SizedBox()));
      await tester.runAsync(() async {
        await precacheImage(img, tester.element(find.byType(Center)));
      });
      final c = StoryController();
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.image(
                  id: 'i0', image: img, duration: const Duration(seconds: 1)),
              StoryItem.image(id: 'i1', image: img),
            ]),
          ],
          controller: c,
        ),
      );
      await pumpMs(tester, 1200);
      expect(c.itemIndex, 1);
    });

    testWidgets('a failing image reports the error and can be skipped',
        (tester) async {
      setPhone(tester);
      final errors = <Object>[];
      final c = StoryController();
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.image(
                  id: 'bad', image: MemoryImage(Uint8List.fromList([1, 2, 3]))),
              customItem('ok'),
            ]),
          ],
          controller: c,
          errorSkipDelay: const Duration(seconds: 1),
          onItemError: (g, i, e) => errors.add(e),
        ),
      );
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await pumpMs(tester, 300);
      expect(errors, isNotEmpty);
      await pumpMs(tester, 1200);
      expect(c.itemIndex, 1);
    });

    testWidgets(
        'late callbacks from a previous item cannot skip the current one',
        (tester) async {
      setPhone(tester);
      final c = StoryController();
      StoryPlayback? first;
      await pumpDeck(
        tester,
        StoryDeck(
          groups: [
            StoryGroup(id: 'a', title: 'A', items: [
              StoryItem.custom(
                  id: 'one',
                  builder: (context, p) {
                    if (p.isActive) first = p;
                    return const SizedBox.expand();
                  }),
              customItem('two'),
            ]),
          ],
          controller: c,
        ),
      );
      final stale = first!;
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(c.itemIndex, 1);
      stale.complete();
      stale.reportProgress(1);
      await pumpMs(tester, 200);
      expect(c.itemIndex, 1, reason: 'stale handle is inert');
      expect(c.progress.value, lessThan(0.2));
    });
  });
}
