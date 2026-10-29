import 'package:flutter_test/flutter_test.dart';
import 'package:story_deck/story_deck.dart';

import 'support/harness.dart';

void main() {
  group('StoryProgressModel', () {
    test('does not advance until ready', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2));
      m.advance(const Duration(seconds: 1));
      expect(m.progress.value, 0);
      m.markReady();
      m.advance(const Duration(seconds: 1));
      expect(m.progress.value, 0.5);
    });

    test('any pause reason stops the timer and removal resumes it', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2))
        ..markReady();
      m.addReason(StoryPauseReason.hold);
      m.addReason(StoryPauseReason.drag);
      m.advance(const Duration(seconds: 1));
      expect(m.progress.value, 0);
      m.removeReason(StoryPauseReason.hold);
      m.advance(const Duration(seconds: 1));
      expect(m.progress.value, 0, reason: 'drag still active');
      m.removeReason(StoryPauseReason.drag);
      m.advance(const Duration(seconds: 1));
      expect(m.progress.value, 0.5);
    });

    test('completes at the end exactly once', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 1))
        ..markReady();
      var calls = 0;
      m.addListener(() {
        if (m.isCompleted) calls++;
      });
      m.advance(const Duration(milliseconds: 1500));
      expect(m.isCompleted, isTrue);
      expect(m.progress.value, 1);
      m.advance(const Duration(seconds: 1));
      expect(calls, 1);
    });

    test('player-driven progress ignores the timer', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 10))
        ..markReady();
      m.setFraction(0.3);
      m.advance(const Duration(seconds: 5));
      expect(m.progress.value, 0.3);
      expect(m.isTicking, isFalse);
      m.setFraction(1);
      expect(m.isCompleted, isTrue);
    });

    test('buffering is a pause reason but does not hold the player', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2))
        ..markReady();
      m.addReason(StoryPauseReason.buffering);
      expect(m.isPaused, isTrue);
      expect(m.shouldHold, isFalse);
      expect(m.isBuffering, isTrue);
    });

    test('failed items never tick', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2))
        ..markReady()
        ..fail('boom');
      m.advance(const Duration(seconds: 3));
      expect(m.progress.value, 0);
      expect(m.hasFailed, isTrue);
    });
  });

  group('resolveStartIndex', () {
    final g = makeGroup('a', 4);
    test('restart', () {
      final s = MemoryStoryViewStore()..setLastIndex('a', 2);
      expect(resolveStartIndex(g, s, StoryResumeMode.restart), 0);
    });
    test('lastViewed clamps and defaults to 0', () {
      final s = MemoryStoryViewStore();
      expect(resolveStartIndex(g, s, StoryResumeMode.lastViewed), 0);
      s.setLastIndex('a', 9);
      expect(resolveStartIndex(g, s, StoryResumeMode.lastViewed), 3);
    });
    test('firstUnseen skips seen items and wraps when all seen', () {
      final s = MemoryStoryViewStore()
        ..markSeen('a', 'a0')
        ..markSeen('a', 'a1');
      expect(resolveStartIndex(g, s, StoryResumeMode.firstUnseen), 2);
      s
        ..markSeen('a', 'a2')
        ..markSeen('a', 'a3');
      expect(resolveStartIndex(g, s, StoryResumeMode.firstUnseen), 0);
    });
    test('store round-trips through json', () {
      final s = MemoryStoryViewStore()
        ..setLastIndex('a', 2)
        ..markSeen('a', 'a0');
      final r = MemoryStoryViewStore(s.toJson());
      expect(r.lastIndex('a'), 2);
      expect(r.isSeen('a', 'a0'), isTrue);
      expect(r.isSeen('a', 'a1'), isFalse);
    });
  });

  test('formatStoryAge', () {
    final now = DateTime(2026, 1, 10, 12);
    expect(formatStoryAge(now, now: now), 'now');
    expect(formatStoryAge(now.subtract(const Duration(minutes: 5)), now: now),
        '5m');
    expect(
        formatStoryAge(now.subtract(const Duration(hours: 3)), now: now), '3h');
    expect(
        formatStoryAge(now.subtract(const Duration(days: 2)), now: now), '2d');
    expect(
        formatStoryAge(now.subtract(const Duration(days: 15)), now: now), '2w');
  });

  test('transition maths', () {
    expect(StoryTransition.cubeAngle(0), 0);
    expect(StoryTransition.cubeAngle(1).abs(), closeTo(1.5707963, 1e-6));
    expect(StoryTransition.cubeAngle(-1), -StoryTransition.cubeAngle(1));
    expect(StoryTransition.cubeAngle(5).abs(), closeTo(1.5707963, 1e-6));
    expect(StoryTransition.depthScale(-1), closeTo(0.85, 1e-9));
    expect(StoryTransition.depthScale(1), 1);
    expect(StoryTransition.fadeOpacity(0.25), 0.75);
  });

  group('ModelStoryPlayback', () {
    test('calls from a disposed handle are ignored (stale item bug)', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2));
      final p = ModelStoryPlayback(m);
      p.dispose();
      p.markReady();
      p.reportProgress(1);
      p.complete();
      p.setBuffering(true);
      expect(m.isReady, isFalse);
      expect(m.isCompleted, isFalse);
      expect(m.isBuffering, isFalse);
      expect(p.isActive, isFalse);
    });

    test('isPaused follows hold reasons but not buffering', () {
      final m = StoryProgressModel(duration: const Duration(seconds: 2));
      final p = ModelStoryPlayback(m);
      expect(p.isPaused.value, isFalse);
      p.setBuffering(true);
      expect(p.isPaused.value, isFalse);
      m.addReason(StoryPauseReason.hold);
      expect(p.isPaused.value, isTrue);
    });
  });

  group('StoryVideoPool', () {
    StoryItem video(String id) => StoryItem.video(id: id, videoSource: 'v/$id');

    test('creates one adapter per key and disposes the ones out of range',
        () async {
      final made = <SimulatedStoryVideoAdapter>[];
      final pool = StoryVideoPool((item) {
        final a = SimulatedStoryVideoAdapter();
        made.add(a);
        return a;
      });
      final a = pool.acquire('g/1', video('1'));
      final again = pool.acquire('g/1', video('1'));
      pool.acquire('g/2', video('2'));
      expect(identical(a, again), isTrue);
      expect(made, hasLength(2));
      await a.ready;
      pool.retainOnly({'g/2'});
      await Future<void>.delayed(Duration.zero);
      expect(made[0].isDisposed, isTrue);
      expect(made[1].isDisposed, isFalse);
      pool.disposeAll();
      await Future<void>.delayed(Duration.zero);
      expect(made[1].isDisposed, isTrue);
    });

    test('failed initialize is captured without an unhandled error', () async {
      final pool = StoryVideoPool(
          (_) => SimulatedStoryVideoAdapter(failToInitialize: true));
      final e = pool.acquire('g/1', video('1'));
      await expectLater(e.ready, throwsStateError);
      expect(e.failure, isA<StateError>());
    });
  });

  test('StoryItem asserts', () {
    expect(() => StoryItem(id: 'x', type: StoryMediaType.image),
        throwsAssertionError);
    expect(() => StoryGroup(id: 'g', title: 't', items: const []),
        throwsAssertionError);
    expect(const StoryPosition(1, 2), const StoryPosition(1, 2));
    expect(const StoryItem.image(id: 'i', image: NeverLoadingImage()).type,
        StoryMediaType.image);
  });
}
