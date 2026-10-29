import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../models/story_models.dart';
import '../state/story_controller.dart';

/// What overlay builders (header, footer, swipe-up hint) get to know.
@immutable
class StoryOverlayData {
  /// Creates overlay data.
  const StoryOverlayData({
    required this.group,
    required this.item,
    required this.groupIndex,
    required this.itemIndex,
    required this.controller,
    required this.progress,
    required this.isActive,
  });

  /// The group on this page.
  final StoryGroup group;

  /// The item shown on this page.
  final StoryItem item;

  /// Index of [group] in the deck.
  final int groupIndex;

  /// Index of [item] in [group].
  final int itemIndex;

  /// Controller of the deck; use it to pause while a text field has focus.
  final StoryController controller;

  /// Progress of the current item, 0 to 1 (only moves on the active page).
  final ValueListenable<double> progress;

  /// Whether this is the page that is playing.
  final bool isActive;

  /// Number of items in [group].
  int get itemCount => group.items.length;
}

/// Builds an overlay for a page.
typedef StoryOverlayBuilder = Widget Function(
    BuildContext context, StoryOverlayData data);

/// Builds a custom progress bar row.
typedef StoryProgressBuilder = Widget Function(BuildContext context, int count,
    int currentIndex, ValueListenable<double> progress);

/// Builds the error state of a media item.
typedef StoryErrorBuilder = Widget Function(BuildContext context, Object error);
