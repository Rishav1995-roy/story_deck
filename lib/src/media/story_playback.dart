import 'package:flutter/foundation.dart';

import '../state/progress_model.dart';

/// Handle given to media widgets so they can steer the story timer.
///
/// A handle belongs to exactly one story item. Once the deck moves on, every
/// call on the old handle is ignored, so a late image load or a video event
/// from a previous item can never advance, pause or skip the current one.
abstract interface class StoryPlayback {
  /// Whether this item is the one currently playing (not a neighbour page
  /// that is only visible during a transition).
  bool get isActive;

  /// `true` while the item should hold still (user holding, dragging,
  /// app in background, `StoryController.pause`). Buffering is not included.
  ValueListenable<bool> get isPaused;

  /// The media is on screen: start the timer. A [duration] (for example the
  /// real video length) replaces the planned one.
  void markReady({Duration? duration});

  /// The media is stalled (`true`) or flowing again (`false`). The timer
  /// stops while buffering.
  void setBuffering(bool buffering);

  /// Reports real playback progress from 0 to 1. After the first call the
  /// timer is ignored and the bar follows this value.
  void reportProgress(double fraction);

  /// The item is done; move to the next one.
  void complete();

  /// The media could not be shown.
  void fail(Object error, [StackTrace? stackTrace]);
}

/// A [StoryPlayback] that does nothing, handed to non-active pages.
class InactiveStoryPlayback implements StoryPlayback {
  /// Creates the no-op handle.
  const InactiveStoryPlayback();

  @override
  bool get isActive => false;

  @override
  ValueListenable<bool> get isPaused => _alwaysPaused;

  @override
  void markReady({Duration? duration}) {}

  @override
  void setBuffering(bool buffering) {}

  @override
  void reportProgress(double fraction) {}

  @override
  void complete() {}

  @override
  void fail(Object error, [StackTrace? stackTrace]) {}
}

final ValueNotifier<bool> _alwaysPaused = ValueNotifier<bool>(true);

/// Playback handle bound to one [StoryProgressModel]. Internal to the deck
/// but public so it can be unit tested.
class ModelStoryPlayback implements StoryPlayback {
  /// Creates a handle for [model]. [onFail] is called once on failure.
  ModelStoryPlayback(this.model, {this.onFail}) {
    model.addListener(_sync);
    _sync();
  }

  /// The model this handle steers.
  final StoryProgressModel model;

  /// Called when the media fails.
  final void Function(Object error, StackTrace? stackTrace)? onFail;

  final ValueNotifier<bool> _paused = ValueNotifier<bool>(false);
  bool _disposed = false;

  void _sync() {
    if (!_disposed) _paused.value = model.shouldHold;
  }

  @override
  bool get isActive => !_disposed;

  @override
  ValueListenable<bool> get isPaused => _paused;

  @override
  void markReady({Duration? duration}) {
    if (_disposed) return;
    model.markReady(duration: duration);
  }

  @override
  void setBuffering(bool buffering) {
    if (_disposed) return;
    if (buffering) {
      model.addReason(StoryPauseReason.buffering);
    } else {
      model.removeReason(StoryPauseReason.buffering);
    }
  }

  @override
  void reportProgress(double fraction) {
    if (_disposed) return;
    model.setFraction(fraction);
  }

  @override
  void complete() {
    if (_disposed) return;
    model.complete();
  }

  @override
  void fail(Object error, [StackTrace? stackTrace]) {
    if (_disposed || model.hasFailed) return;
    model.fail(error);
    onFail?.call(error, stackTrace);
  }

  /// Detaches the handle; later calls are ignored.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    model.removeListener(_sync);
    _paused.value = true;
  }
}
