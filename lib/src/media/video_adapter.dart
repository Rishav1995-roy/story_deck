import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/story_models.dart';

/// The bridge between the deck and your video player.
///
/// `story_deck` has no video dependency. Implement this interface on top of
/// `video_player`, `media_kit` or anything else, and give the deck a
/// [StoryVideoAdapterFactory]. The deck then
///
/// * calls [initialize] early (preloading) and shows the first frame,
/// * calls [play] / [pause] as the user holds, drags, leaves the app or moves
///   to another story,
/// * drives the progress bar from [position] / [duration], so the bar is
///   exactly where the picture is,
/// * stops the bar while [isBuffering] is `true`,
/// * calls [dispose] when the item is no longer needed.
///
/// Notify listeners whenever [position], [isBuffering] or [error] change.
abstract interface class StoryVideoAdapter implements Listenable {
  /// Opens the source. Called once, possibly long before the item is shown.
  Future<void> initialize();

  /// Total length. Valid after [initialize] completed.
  Duration get duration;

  /// Current playback position.
  Duration get position;

  /// Whether the player is stalled waiting for data.
  bool get isBuffering;

  /// A playback error, or `null`.
  Object? get error;

  /// Native size of the video, used to fit it. May be `null`.
  Size? get videoSize;

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Jumps to [position].
  Future<void> seekTo(Duration position);

  /// Builds the video surface (for example `VideoPlayer(controller)`).
  Widget buildView(BuildContext context);

  /// Releases the player.
  Future<void> dispose();
}

/// Creates an adapter for a video [item]. Read `item.videoSource`.
typedef StoryVideoAdapterFactory = StoryVideoAdapter Function(StoryItem item);

/// Owns the adapters of the videos that are on screen or about to be.
///
/// Public for testing. The deck calls [retainOnly] whenever the position
/// changes so videos leave memory (and stop playing) as soon as they are out
/// of range.
class StoryVideoPool {
  /// Creates a pool that builds adapters with [factory].
  StoryVideoPool(this.factory);

  /// Builds adapters.
  final StoryVideoAdapterFactory factory;

  final Map<String, StoryVideoEntry> _entries = <String, StoryVideoEntry>{};

  /// Keys currently held.
  Iterable<String> get keys => _entries.keys;

  /// Returns the entry for [key], creating the adapter and starting
  /// [StoryVideoAdapter.initialize] on first use.
  StoryVideoEntry acquire(String key, StoryItem item) {
    return _entries.putIfAbsent(key, () {
      final adapter = factory(item);
      final entry = StoryVideoEntry._(adapter);
      entry.ready = Future<void>.sync(adapter.initialize).then<void>((_) {
        entry.isReady = true;
      }, onError: (Object e, StackTrace s) {
        entry.failure = e;
        throw e;
      });
      // Avoid an unhandled error when nobody listens (preloaded, failed).
      entry.ready.ignore();
      return entry;
    });
  }

  /// Disposes every adapter whose key is not in [keys].
  void retainOnly(Set<String> keys) {
    final gone = _entries.keys.where((k) => !keys.contains(k)).toList();
    for (final k in gone) {
      _entries.remove(k)!._dispose();
    }
  }

  /// Disposes everything.
  void disposeAll() => retainOnly(const <String>{});
}

/// An adapter plus its initialization state.
class StoryVideoEntry {
  StoryVideoEntry._(this.adapter);

  /// The player bridge.
  final StoryVideoAdapter adapter;

  /// Completes when [StoryVideoAdapter.initialize] did (or throws).
  late final Future<void> ready;

  /// Whether initialization finished successfully.
  bool isReady = false;

  /// The initialization error, if any.
  Object? failure;

  void _dispose() {
    unawaited(Future<void>.sync(adapter.pause).catchError((Object _) {}));
    unawaited(Future<void>.sync(adapter.dispose).catchError((Object _) {}));
  }
}
