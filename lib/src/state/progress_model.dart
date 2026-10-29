import 'package:flutter/foundation.dart';

/// Why the progress of the current story is not advancing.
enum StoryPauseReason {
  /// The user is pressing and holding the screen.
  hold,

  /// The user is dragging (dismiss, swipe up).
  drag,

  /// The deck is scrolling between two users.
  transition,

  /// The app is in the background.
  lifecycle,

  /// Paused by `StoryController.pause` (for example while typing a reply).
  external,

  /// The media is buffering. Does not pause the player itself.
  buffering,
}

/// Pure state machine behind the progress bar of one story item.
///
/// Time only advances while the item [isReady], is not paused for any reason,
/// has not failed and is not completed. Items driven by a player (video)
/// report the real position with [setFraction] instead of using the timer, so
/// the bar can never run ahead of the picture.
class StoryProgressModel extends ChangeNotifier {
  /// Creates a model for an item that lasts [duration].
  StoryProgressModel({required this.duration});

  /// Total time of the item. Updated by [markReady].
  Duration duration;

  /// Progress from 0 to 1. Listen to this for painting; the model itself only
  /// notifies on state changes.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  final Set<StoryPauseReason> _reasons = <StoryPauseReason>{};
  bool _ready = false;
  bool _external = false;
  bool _completed = false;
  Object? _error;

  /// Whether the media is loaded and showing.
  bool get isReady => _ready;

  /// Whether the item reached the end.
  bool get isCompleted => _completed;

  /// Whether the media failed to load.
  bool get hasFailed => _error != null;

  /// The failure, if any.
  Object? get error => _error;

  /// Whether progress is driven by a player instead of the timer.
  bool get isExternallyDriven => _external;

  /// Whether any pause reason is active.
  bool get isPaused => _reasons.isNotEmpty;

  /// Whether a player should be paused: any reason except buffering.
  bool get shouldHold => _reasons.any((r) => r != StoryPauseReason.buffering);

  /// Whether buffering is the (only or one) reason for the stall.
  bool get isBuffering => _reasons.contains(StoryPauseReason.buffering);

  /// The active pause reasons.
  Set<StoryPauseReason> get reasons => Set.unmodifiable(_reasons);

  /// Whether the timer should be ticking right now.
  bool get isTicking =>
      _ready && !_external && !_completed && _error == null && _reasons.isEmpty;

  /// Marks the media as loaded. A [duration] replaces the planned one.
  void markReady({Duration? duration}) {
    if (_ready || _completed) return;
    if (duration != null && duration > Duration.zero) this.duration = duration;
    _ready = true;
    notifyListeners();
  }

  /// Adds a pause [reason]. Returns whether it changed anything.
  bool addReason(StoryPauseReason reason) {
    if (_completed || !_reasons.add(reason)) return false;
    notifyListeners();
    return true;
  }

  /// Removes a pause [reason].
  bool removeReason(StoryPauseReason reason) {
    if (!_reasons.remove(reason)) return false;
    notifyListeners();
    return true;
  }

  /// Advances the timer by [delta]. Does nothing unless [isTicking].
  void advance(Duration delta) {
    if (!isTicking || duration <= Duration.zero) return;
    final next =
        progress.value + delta.inMicroseconds / duration.inMicroseconds;
    _set(next);
  }

  /// Reports the real position of a player as a fraction. Switches the item
  /// to player-driven progress; the timer no longer runs.
  void setFraction(double fraction) {
    if (!_ready || _completed || _error != null) return;
    _external = true;
    _set(fraction);
  }

  /// Ends the item immediately.
  void complete() {
    if (_completed) return;
    _set(1);
  }

  /// Marks the media as failed. The timer does not run for a failed item.
  void fail(Object error) {
    if (_completed || _error != null) return;
    _error = error;
    notifyListeners();
  }

  void _set(double value) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    if (v >= 0.995 && _external || v >= 1) {
      progress.value = 1;
      _completed = true;
      notifyListeners();
    } else {
      progress.value = v;
    }
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }
}
