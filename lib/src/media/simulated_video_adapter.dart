import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'video_adapter.dart';

/// A [StoryVideoAdapter] that plays a fake video: a moving gradient, with
/// optional buffering stalls. It needs no plugin and is deterministic under
/// `flutter_test`, so use it for widget tests and demos.
///
/// Time comes from a [Ticker], so it follows `tester.pump` and stops when the
/// widget tree is muted. Call [stall] to simulate a network stall.
class SimulatedStoryVideoAdapter extends ChangeNotifier
    implements StoryVideoAdapter {
  /// Creates a fake video of length [length].
  SimulatedStoryVideoAdapter({
    this.length = const Duration(seconds: 6),
    this.initializeDelay = Duration.zero,
    this.color = const Color(0xFF3F51B5),
    this.failToInitialize = false,
    this.stallAt,
    this.stallFor = const Duration(seconds: 1),
  });

  /// Total fake video length.
  final Duration length;

  /// Simulated open time.
  final Duration initializeDelay;

  /// Base color of the picture.
  final Color color;

  /// Make [initialize] throw.
  final bool failToInitialize;

  /// When playback reaches this position it stalls once (buffering) for
  /// [stallFor]. `null` for no stall.
  final Duration? stallAt;

  /// Length of the stall at [stallAt].
  final Duration stallFor;

  bool _stallDone = false;

  Ticker? _ticker;
  Duration _position = Duration.zero;
  Duration _last = Duration.zero;
  bool _playing = false;
  bool _stalled = false;
  bool _disposed = false;

  /// How many times [play] was called. For tests.
  int playCalls = 0;

  /// How many times [pause] was called. For tests.
  int pauseCalls = 0;

  /// Whether [dispose] ran. For tests.
  bool get isDisposed => _disposed;

  /// Whether the fake player is currently playing.
  bool get isPlaying => _playing;

  @override
  Future<void> initialize() async {
    if (initializeDelay > Duration.zero) {
      await Future<void>.delayed(initializeDelay);
    }
    if (failToInitialize) throw StateError('simulated init failure');
  }

  /// Stalls playback (buffering) for [forHowLong], or until [unstall] when
  /// `null`.
  void stall([Duration? forHowLong]) {
    _stalled = true;
    notifyListeners();
    if (forHowLong != null) {
      Timer(forHowLong, unstall);
    }
  }

  /// Ends a stall.
  void unstall() {
    if (_disposed) return;
    _stalled = false;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    if (!_playing || _stalled || _disposed) return;
    _position += dt;
    final at = stallAt;
    if (at != null && !_stallDone && _position >= at) {
      _stallDone = true;
      stall(stallFor);
    }
    if (_position >= length) {
      _position = length;
      _playing = false;
      _ticker?.stop();
    }
    notifyListeners();
  }

  @override
  Duration get duration => length;

  @override
  Duration get position => _position;

  @override
  bool get isBuffering => _stalled;

  @override
  Object? get error => null;

  @override
  Size? get videoSize => const Size(9, 16);

  @override
  Future<void> play() async {
    playCalls++;
    if (_disposed || _playing || _position >= length) return;
    _playing = true;
    _ticker ??= Ticker(_tick);
    _last = Duration.zero;
    if (!_ticker!.isActive) unawaited(_ticker!.start());
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (!_playing) return;
    _playing = false;
    _ticker?.stop();
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    notifyListeners();
  }

  @override
  Widget buildView(BuildContext context) =>
      _SimulatedFrame(adapter: this, color: color);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playing = false;
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

class _SimulatedFrame extends StatelessWidget {
  const _SimulatedFrame({required this.adapter, required this.color});

  final SimulatedStoryVideoAdapter adapter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: adapter,
      builder: (context, _) {
        final t = adapter.length.inMicroseconds == 0
            ? 0.0
            : adapter.position.inMicroseconds / adapter.length.inMicroseconds;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 - 2 * t, 1),
              colors: [
                color,
                HSLColor.fromColor(color)
                    .withHue(
                        (HSLColor.fromColor(color).hue + 120 * math.min(1, t)) %
                            360)
                    .toColor()
              ],
            ),
          ),
        );
      },
    );
  }
}
