import 'package:flutter/foundation.dart';

import '../models/story_models.dart';

/// Implemented by the deck state; lets [StoryController] steer it.
/// Not part of the public API surface you need to touch.
abstract interface class StoryControllerDelegate {
  /// Goes to the next item or user.
  void next();

  /// Goes to the previous item or user.
  void previous();

  /// Goes to the next user.
  void nextGroup();

  /// Goes to the previous user.
  void previousGroup();

  /// Jumps to a position.
  void jumpTo(int group, [int item = 0]);
}

/// Controls a `StoryDeck` from outside and tells you where it is.
///
/// Create it in your state, pass it to the deck and dispose it yourself.
class StoryController extends ChangeNotifier {
  /// Creates a controller. [initialGroup] / [initialItem] choose where the
  /// deck opens (the item defaults to the resume position of the group).
  StoryController({this.initialGroup = 0, this.initialItem});

  /// Group the deck opens at.
  final int initialGroup;

  /// Item the deck opens at, or `null` to use the resume position.
  final int? initialItem;

  StoryControllerDelegate? _delegate;
  bool _paused = false;
  StoryPosition _position = const StoryPosition(0, 0);

  /// Progress of the current item, 0 to 1. Updated every frame while playing.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Whether the deck is attached.
  bool get isAttached => _delegate != null;

  /// Whether [pause] was called and not yet undone by [resume].
  bool get isPaused => _paused;

  /// Where the deck is now.
  StoryPosition get position => _position;

  /// Index of the current group.
  int get groupIndex => _position.group;

  /// Index of the current item.
  int get itemIndex => _position.item;

  /// Called by the deck when it attaches. Do not call yourself.
  void attachDeck(StoryControllerDelegate delegate) => _delegate = delegate;

  /// Called by the deck when it detaches. Do not call yourself.
  void detachDeck(StoryControllerDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }

  /// Called by the deck on position changes. Do not call yourself.
  void updatePosition(StoryPosition position) {
    if (_position == position) return;
    _position = position;
    notifyListeners();
  }

  /// Called by the deck when the external pause was cleared. Do not call.
  void updatePaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    notifyListeners();
  }

  /// Goes to the next item (or user after the last item).
  void next() => _delegate?.next();

  /// Goes to the previous item (or user before the first item).
  void previous() => _delegate?.previous();

  /// Goes to the next user.
  void nextGroup() => _delegate?.nextGroup();

  /// Goes to the previous user.
  void previousGroup() => _delegate?.previousGroup();

  /// Jumps to [group] / [item].
  void jumpTo(int group, [int item = 0]) => _delegate?.jumpTo(group, item);

  /// Pauses the story timer and any video until [resume].
  void pause() {
    if (_paused) return;
    _paused = true;
    pauseHook?.call(true);
    notifyListeners();
  }

  /// Resumes after [pause].
  void resume() {
    if (!_paused) return;
    _paused = false;
    pauseHook?.call(false);
    notifyListeners();
  }

  /// Set by the deck to apply [pause] / [resume]. Do not set yourself.
  void Function(bool paused)? pauseHook;

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }
}
