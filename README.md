# story_deck

[![pub version](https://img.shields.io/pub/v/story_deck.svg)](https://pub.dev/packages/story_deck)
[![pub points](https://img.shields.io/pub/points/story_deck)](https://pub.dev/packages/story_deck/score)
[![likes](https://img.shields.io/pub/likes/story_deck)](https://pub.dev/packages/story_deck)
[![popularity](https://img.shields.io/pub/popularity/story_deck)](https://pub.dev/packages/story_deck)
[![CI](https://github.com/Rishav1995-roy/story_deck/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/story_deck/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

An Instagram-style stories viewer for Flutter, as one focused widget: several users' stories, a 3D cube transition between them, segmented progress bars, tap zones, hold to pause, swipe down to close, swipe up for an action. Video goes through a tiny adapter you implement on top of `video_player` or `media_kit`, so the progress bar follows the real picture and buffering stops the timer. Pure Dart, no dependencies beyond Flutter, runs on every platform including web and desktop.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/story_deck/main/doc/demo.gif)

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/story_deck/main/doc/screenshot_light.png" width="260" alt="Paper card theme with header, caption and reply bar">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/story_deck/main/doc/screenshot_dark.png" width="260" alt="Midnight theme in the middle of the cube transition">
</p>

_The images in the demo are generated in code and the "video" is the bundled `SimulatedStoryVideoAdapter`; the GIF is rendered by a Flutter test, not captured on a device. See [tool/make_demo.sh](tool/make_demo.sh)._

## Why this package

The most used stories package, [`story_view`](https://pub.dev/packages/story_view), is a fine start for a single story strip, and this package exists because of the problems people keep reporting there (checked October 2026):

| | `story_view` | `story_deck` |
|---|---|---|
| Video keeps playing after the story is left ([#87](https://github.com/blackmann/story_view/issues/87)) | open issue | Player is paused the moment the story is left or the app goes to the background, and disposed right after. Tested. |
| Progress vs. real video position, buffering | Progress is driven by its own loaders | Progress is `position / duration` of your player, and buffering stops the bar. Tested. |
| Video on iOS / "Media failed to load" ([#86](https://github.com/blackmann/story_view/issues/86), [#103](https://github.com/blackmann/story_view/issues/103)) | open issues | No video code inside the package: you bring your player through `StoryVideoAdapter`, so a player bug is never ours. Failures reach `onItemError` / `errorBuilder`. |
| Web / desktop | No web support | Web, Windows, macOS and Linux: keyboard, mouse click zones, press-and-hold, hover arrows, card layout |
| Several users with a transition | One story strip | Multi-user deck with cube, depth, slide, fade or your own transition |
| Resume where the user was | Not built in | Per-user resume (`lastViewed`, `firstUnseen`, `restart`), persistable store |
| Media | Built-in loaders | Any `ImageProvider`, any widget, any video player |
| Timer while media loads | not checked | Never starts before the media is on screen. Tested. |
| Stale callbacks after navigation | not checked | Each item gets its own `StoryPlayback` handle; late calls from an old item are ignored. Tested. |
| Theming and overlays | Basic options | `StoryDeckTheme`, header / footer / swipe-up hint / progress builders |

What it is not: a story tray or an editor, and it does not record or upload anything. If you only need a single timed strip with built-in video and image loaders and you are happy with it, `story_view` is simpler to drop in.

## Features

- Multi-user deck, 3D cube (also depth, slide, fade, custom) between users, horizontal swipe or animated
- Segmented progress bars, per-item duration, default duration
- Tap left/right, hold to pause, swipe down to dismiss (card follows the finger), swipe up action hook
- Video through `StoryVideoAdapter`: progress follows playback, buffering pauses the bar, pause on hold/drag/background, preloading of the next video (first frame ready before it is shown)
- Images are pre-cached ahead; the timer waits for the first frame
- Resume position per user and seen callbacks (`StoryViewStore`)
- Keyboard (arrows, page up/down, space, escape), mouse and trackpad drag, hover arrows, optional `aspectRatio` card for wide screens, RTL aware tap zones
- Theming and builders: header (avatar, name, "2h"), footer / reply bar, swipe-up hint, progress bars, error / loading / buffering views
- `StoryController`: next, previous, jump, pause, observe position and progress
- Text-field friendly: the default reply bar pauses the story while you type and shortcuts are ignored while a text field has focus

## Installation

```sh
flutter pub add story_deck
```

Requires Dart `^3.6.0` and Flutter `>=3.27.0`. Tested on Flutter 3.27 and the latest stable (3.47 at release). No native code, so nothing extra to configure for Swift Package Manager or CocoaPods.

## Quick start

```dart
import 'package:story_deck/story_deck.dart';

final groups = [
  StoryGroup(
    id: 'mira',
    title: 'mira.okafor',
    avatar: const NetworkImage('https://example.com/mira.jpg'),
    items: [
      StoryItem.image(id: '1', image: const NetworkImage('https://example.com/1.jpg'), caption: 'Hello'),
      StoryItem.image(id: '2', image: const NetworkImage('https://example.com/2.jpg'), duration: const Duration(seconds: 8)),
    ],
  ),
  // more users...
];

Navigator.of(context).push(PageRouteBuilder<void>(
  opaque: false,
  pageBuilder: (context, _, __) => Scaffold(
    backgroundColor: Colors.transparent,
    body: StoryDeck(
      groups: groups,
      onDismiss: () => Navigator.of(context).pop(),
      onComplete: () => Navigator.of(context).pop(),
    ),
  ),
));
```

`StoryDeck` fills the space it is given. It does not push routes itself, so you decide how it opens and closes. A complete example with a tray, reply bar and customization screen is in [example/](example).

## Video

`story_deck` has no video dependency. Implement `StoryVideoAdapter` once for your player and pass a factory. The deck then initializes the next video early, plays and pauses it for you, reads `position` / `duration` to draw the bar, stops the bar while `isBuffering`, and disposes it when it is out of range.

### With `video_player`

```dart
class VideoPlayerStoryAdapter extends ChangeNotifier implements StoryVideoAdapter {
  VideoPlayerStoryAdapter(String url)
      : _c = VideoPlayerController.networkUrl(Uri.parse(url)) {
    _c.addListener(notifyListeners);
  }
  final VideoPlayerController _c;

  @override
  Future<void> initialize() => _c.initialize();
  @override
  Duration get duration => _c.value.duration;
  @override
  Duration get position => _c.value.position;
  @override
  bool get isBuffering => _c.value.isBuffering;
  @override
  Object? get error => _c.value.hasError ? _c.value.errorDescription : null;
  @override
  Size? get videoSize => _c.value.isInitialized ? _c.value.size : null;
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);
  @override
  Widget buildView(BuildContext context) => VideoPlayer(_c);
  @override
  Future<void> dispose() async {
    _c.removeListener(notifyListeners);
    await _c.dispose();
    super.dispose();
  }
}

StoryDeck(
  groups: groups,
  videoAdapterFactory: (item) => VideoPlayerStoryAdapter(item.videoSource! as String),
)
```

Items: `StoryItem.video(id: 'v', videoSource: 'https://example.com/clip.mp4')`. `media_kit` works the same way: wrap its `Player` / `VideoController`, map `player.stream.buffering` and `position` to `notifyListeners`.

For tests and demos use `SimulatedStoryVideoAdapter` (no plugin, deterministic, can simulate buffering).

### Your own media

```dart
StoryItem.custom(
  id: 'poll',
  duration: const Duration(seconds: 6),
  builder: (context, playback) => MyPollCard(),
)
```

For anything that loads (a Lottie file, a web view) call `playback.markReady()` when it is on screen, `playback.setBuffering(true/false)` for stalls and `playback.complete()` or `playback.reportProgress(0..1)` if it knows its own length. Or replace the media of every item with `StoryDeck.mediaBuilder` (return `null` to keep the default). Custom items start their timer immediately; content from `mediaBuilder` must call `markReady()`.

## Customization

```dart
StoryDeck(
  groups: groups,
  transition: StoryTransition.cube,           // depth, slide, fade, or StoryTransition.custom(...)
  theme: const StoryDeckTheme(
    progressHeight: 3,
    progressActiveColor: Color(0xFFFFD166),
    cardBorderRadius: BorderRadius.all(Radius.circular(24)),
  ),
  aspectRatio: 9 / 16,                        // centred card on wide screens
  resumeMode: StoryResumeMode.firstUnseen,
  tapZoneLeftFraction: 0.25,
  headerBuilder: (context, d) => StoryHeader(
    data: d,
    onClose: () => Navigator.of(context).pop(),
    trailing: [IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {})],
  ),
  footerBuilder: (context, d) => StoryReplyBar(controller: d.controller, onSend: send),
  onSwipeUp: (group, item) => openLink(item.data),
  swipeUpBuilder: (context, d) => const Text('Swipe up'),
)
```

Overlay builders get a `StoryOverlayData` with the group, item, indexes, the `StoryController` and the live `progress`. Your overlay sits above the tap layer, so buttons in it work and the transparent parts of it still pass taps through. To keep the story from running while the user interacts with your widgets, call `d.controller.pause()` / `resume()` (the default `StoryReplyBar` does this on focus).

Persist what was seen and where each user stopped:

```dart
final store = MemoryStoryViewStore(savedJson); // implement StoryViewStore for a database
StoryDeck(groups: groups, viewStore: store);
// later: save(store.toJson());
```

## Parameters

### StoryDeck

| Parameter | Type | Default | Description |
|---|---|---|---|
| `groups` | `List<StoryGroup>` | required | Users' stories. |
| `controller` | `StoryController?` | none | Navigate, pause, observe. |
| `viewStore` | `StoryViewStore?` | in-memory | Seen items and resume positions. |
| `resumeMode` | `StoryResumeMode` | `lastViewed` | `restart`, `lastViewed`, `firstUnseen`. |
| `videoAdapterFactory` | `StoryVideoAdapterFactory?` | none | Needed for video items. |
| `mediaBuilder` | `StoryMediaBuilder?` | none | Custom media for all items; return `null` for the default. |
| `headerBuilder` / `footerBuilder` / `swipeUpBuilder` | `StoryOverlayBuilder?` | default header / caption / none | Overlays. |
| `progressBuilder` | `StoryProgressBuilder?` | `StoryProgressBars` | Custom progress row. |
| `errorBuilder` / `loadingBuilder` / `bufferingBuilder` | builders | simple defaults | Media states. |
| `theme` | `StoryDeckTheme` | defaults | Colors, sizes, text styles. |
| `transition` | `StoryTransition` | `cube` | Between users. |
| `transitionDuration` / `transitionCurve` | | 420 ms / `easeOutCubic` | Animated user switch. |
| `defaultDuration` | `Duration` | 5 s | For items without their own duration. |
| `holdDelay` | `Duration` | 180 ms | Press length that counts as hold. |
| `tapZoneLeftFraction` | `double` | 0.3 | Width share of the "previous" zone (flips in RTL). |
| `preloadItems` | `int` | 2 | Items ahead to pre-cache / initialize. |
| `enableSwipeBetweenGroups` | `bool` | true | Horizontal swipe switches users. |
| `dismissOnSwipeDown` | `bool` | true | Swipe down calls `onDismiss`. |
| `enableKeyboard` | `bool` | true | Keyboard shortcuts. |
| `showNavigationArrows` | `bool?` | auto (web / desktop) | Hover arrows. |
| `showHeader` | `bool` | true | Default header. |
| `aspectRatio` | `double?` | none (fill) | Card layout, e.g. `9 / 16`. |
| `errorSkipDelay` | `Duration?` | none | Auto-skip failed items. |
| `onDismiss` / `onComplete` | `VoidCallback?` | | Close / all finished. |
| `onSwipeUp` | `void Function(StoryGroup, StoryItem)?` | | Swipe up or up arrow. |
| `onItemChanged` | `ValueChanged<StoryPosition>?` | | Position changed. |
| `onItemSeen` | `void Function(StoryGroup, StoryItem)?` | | First time on screen. |
| `onGroupCompleted` | `void Function(StoryGroup, int)?` | | A user's last item ended. |
| `onItemError` | `void Function(StoryGroup, StoryItem, Object)?` | | Media failed. |

### Models

| Type | Members |
|---|---|
| `StoryGroup` | `id`, `title`, `subtitle`, `avatar`, `items`, `data` |
| `StoryItem.image` | `id`, `image`, `duration`, `caption`, `createdAt`, `fit`, `semanticLabel`, `data` |
| `StoryItem.video` | `id`, `videoSource`, `poster`, `duration` (cap), `caption`, `createdAt`, `fit`, `semanticLabel`, `data` |
| `StoryItem.custom` | `id`, `builder(context, playback)`, `duration`, `caption`, `createdAt`, `semanticLabel`, `data` |

### StoryController

`next()`, `previous()`, `nextGroup()`, `previousGroup()`, `jumpTo(group, [item])`, `pause()`, `resume()`, `isPaused`, `position`, `groupIndex`, `itemIndex`, `progress` (`ValueNotifier<double>`). It is a `ChangeNotifier`; dispose it yourself.

### StoryDeckTheme

`backgroundColor`, `backdropColor`, `cardBorderRadius`, `mediaFit`, `progressHeight`, `progressSpacing`, `progressRadius`, `progressPadding`, `progressActiveColor`, `progressTrackColor`, `progressCompletedColor`, `loadingColor`, `topScrim`, `bottomScrim`, `titleStyle`, `subtitleStyle`, `captionStyle`, `iconColor`, plus `copyWith`.

### StoryVideoAdapter

`initialize()`, `duration`, `position`, `isBuffering`, `error`, `videoSize`, `play()`, `pause()`, `seekTo()`, `buildView()`, `dispose()`, and `Listenable` (notify on position, buffering, error changes).

### StoryPlayback (handed to custom media)

`isActive`, `isPaused`, `markReady({duration})`, `setBuffering(bool)`, `reportProgress(0..1)`, `complete()`, `fail(error)`.

## Gestures and keys

| Input | Action |
|---|---|
| Tap / click left zone, right zone | Previous / next item |
| Press and hold | Pause, release to continue |
| Swipe left / right (or drag with a mouse) | Previous / next user |
| Swipe down | Dismiss (`onDismiss`) |
| Swipe up | `onSwipeUp` |
| Left / right arrow | Previous / next item |
| Page up / page down | Previous / next user |
| Space | Pause / resume |
| Escape | `onDismiss` |
| Up arrow | `onSwipeUp` |

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | Yes |

The package is pure Dart/Flutter with no plugins. Video support depends on the player you plug in.

## Coming from `story_view`

| `story_view` | `story_deck` |
|---|---|
| `StoryView(storyItems: [...])` | `StoryDeck(groups: [StoryGroup(items: [...])])` |
| `StoryItem.pageImage(url: ..., controller: ...)` | `StoryItem.image(id: ..., image: NetworkImage(url))` (no controller per item) |
| `StoryItem.pageVideo(url, controller: ...)` | `StoryItem.video(id: ..., videoSource: url)` + a `StoryVideoAdapter` |
| `StoryController` (play / pause / next / previous) | `StoryController` (`pause`, `resume`, `next`, `previous`, `jumpTo`) |
| `onComplete`, `onVerticalSwipeComplete` | `onComplete`, `onDismiss`, `onSwipeUp` |
| `progressPosition`, `indicatorColor` | `StoryDeckTheme` and `progressBuilder` |

Check the exact `story_view` API of the version you use; this table is a guide, not a promise of a drop-in swap.

## FAQ

**Does it include the round story tray?** No. It is the viewer. The example shows a simple tray using `StoryViewStore.isSeen` for the ring state.

**Why not bundle `video_player`?** Players differ per app (`video_player`, `media_kit`, `better_player`...), versions fight each other, and bugs in a player should not become bugs in a stories package. The adapter is about 25 lines.

**Stories stay on the loading spinner.** The timer starts when the media reports ready. For custom media call `playback.markReady()`.

**Can I use it inside a bottom sheet or a dialog?** Yes, it fills whatever size it gets. Use `aspectRatio` for a card.

**How do I keep the keyboard from covering the reply bar?** The footer is lifted by the keyboard inset; make sure the surrounding `Scaffold` has `resizeToAvoidBottomInset: false`, as in the example.

## Contributing

Issues and pull requests are welcome. Run `flutter analyze --fatal-infos` and `flutter test` before submitting. Regenerate the demo with `FLUTTER=flutter sh tool/make_demo.sh` (needs `ffmpeg`).

## License

MIT, see [LICENSE](LICENSE). The demo tool bundles Roboto (Apache 2.0) under `tool/fonts/`; it is not part of the published package.
