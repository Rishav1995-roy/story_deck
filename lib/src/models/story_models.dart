import 'package:flutter/widgets.dart';

import '../media/story_playback.dart';

/// The kind of media a [StoryItem] shows.
enum StoryMediaType {
  /// A still image shown for a fixed duration.
  image,

  /// A video played through a `StoryVideoAdapter`; progress follows playback.
  video,

  /// Any widget built by [StoryItem.builder].
  custom,
}

/// Builds the content of a [StoryItem.custom] item.
///
/// Use the [playback] handle to tell the deck when the content is ready,
/// buffering, finished or failed.
typedef StoryItemBuilder = Widget Function(
    BuildContext context, StoryPlayback playback);

/// One story: a single image, video or custom widget.
@immutable
class StoryItem {
  /// Creates an item. Prefer the [StoryItem.image], [StoryItem.video] and
  /// [StoryItem.custom] constructors.
  const StoryItem({
    required this.id,
    required this.type,
    this.duration,
    this.image,
    this.videoSource,
    this.poster,
    this.builder,
    this.caption,
    this.createdAt,
    this.fit,
    this.semanticLabel,
    this.data,
  })  : assert(type != StoryMediaType.image || image != null,
            'An image item needs an image'),
        assert(type != StoryMediaType.custom || builder != null,
            'A custom item needs a builder');

  /// An image item. The timer starts only after the image has loaded.
  const StoryItem.image({
    required String id,
    required ImageProvider image,
    Duration? duration,
    String? caption,
    DateTime? createdAt,
    BoxFit? fit,
    String? semanticLabel,
    Object? data,
  }) : this(
          id: id,
          type: StoryMediaType.image,
          image: image,
          duration: duration,
          caption: caption,
          createdAt: createdAt,
          fit: fit,
          semanticLabel: semanticLabel,
          data: data,
        );

  /// A video item. [videoSource] is passed to your adapter factory (for
  /// example a URL). [duration] is an optional cap; by default the real video
  /// duration is used.
  const StoryItem.video({
    required String id,
    required Object videoSource,
    ImageProvider? poster,
    Duration? duration,
    String? caption,
    DateTime? createdAt,
    BoxFit? fit,
    String? semanticLabel,
    Object? data,
  }) : this(
          id: id,
          type: StoryMediaType.video,
          videoSource: videoSource,
          poster: poster,
          duration: duration,
          caption: caption,
          createdAt: createdAt,
          fit: fit,
          semanticLabel: semanticLabel,
          data: data,
        );

  /// An item that shows any widget.
  const StoryItem.custom({
    required String id,
    required StoryItemBuilder builder,
    Duration? duration,
    String? caption,
    DateTime? createdAt,
    String? semanticLabel,
    Object? data,
  }) : this(
          id: id,
          type: StoryMediaType.custom,
          builder: builder,
          duration: duration,
          caption: caption,
          createdAt: createdAt,
          semanticLabel: semanticLabel,
          data: data,
        );

  /// Identifier, unique inside its [StoryGroup].
  final String id;

  /// The media kind.
  final StoryMediaType type;

  /// How long the item is shown. `null` uses `StoryDeck.defaultDuration`
  /// (images, custom) or the real video length (videos).
  final Duration? duration;

  /// Image to show for [StoryMediaType.image].
  final ImageProvider? image;

  /// Source handed to the video adapter factory for [StoryMediaType.video].
  final Object? videoSource;

  /// Optional poster shown while a video loads.
  final ImageProvider? poster;

  /// Builder for [StoryMediaType.custom].
  final StoryItemBuilder? builder;

  /// Optional caption text for overlays.
  final String? caption;

  /// When the story was posted, used for the "2h" label in the header.
  final DateTime? createdAt;

  /// Overrides how the media is fitted.
  final BoxFit? fit;

  /// Accessibility description of the media.
  final String? semanticLabel;

  /// Any app data you want back in callbacks and builders.
  final Object? data;
}

/// All stories of one user (or channel), shown as one segment bar.
@immutable
class StoryGroup {
  /// Creates a group. [items] must not be empty.
  const StoryGroup({
    required this.id,
    required this.title,
    required this.items,
    this.subtitle,
    this.avatar,
    this.data,
  }) : assert(items.length > 0, 'A story group needs at least one item');

  /// Identifier, unique inside the deck. Used to remember resume positions.
  final String id;

  /// Display name shown in the header.
  final String title;

  /// Optional second line in the header.
  final String? subtitle;

  /// Avatar image for the header.
  final ImageProvider? avatar;

  /// The stories, in order.
  final List<StoryItem> items;

  /// Any app data you want back in callbacks and builders.
  final Object? data;
}

/// A position in the deck: which group and which item inside it.
@immutable
class StoryPosition {
  /// Creates a position.
  const StoryPosition(this.group, this.item);

  /// Index of the group.
  final int group;

  /// Index of the item inside the group.
  final int item;

  @override
  bool operator ==(Object other) =>
      other is StoryPosition && other.group == group && other.item == item;

  @override
  int get hashCode => Object.hash(group, item);

  @override
  String toString() => 'StoryPosition($group, $item)';
}
