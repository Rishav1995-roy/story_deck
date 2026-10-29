## 0.0.1

Initial release.

* `StoryDeck`: multi-user stories viewer with segmented progress bars, tap zones, hold to pause, swipe down to dismiss and a swipe-up action hook.
* Transitions between users: 3D cube, depth, slide, fade and custom builders.
* Video through the `StoryVideoAdapter` interface (no video dependency): progress follows real playback, buffering stops the bar, the player is paused and disposed as soon as the story is left.
* Preloading of the next items (images are pre-cached, videos are initialized).
* Resume position per user (`StoryViewStore`, `StoryResumeMode`) and seen-state callbacks.
* Web and desktop: keyboard shortcuts, mouse click zones and press-and-hold, hover arrows, optional card layout.
* Theming (`StoryDeckTheme`) and overlay builders (header, footer, swipe-up hint, progress bars) with a default `StoryHeader` and `StoryReplyBar` (pauses the story while typing).
* `StoryController` for navigation, pause and observing progress.
* `SimulatedStoryVideoAdapter` for tests and demos.
