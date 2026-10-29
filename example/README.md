# story_deck example

Runs on Android, iOS, web, macOS, Windows and Linux.

```sh
cd example
flutter run            # pick a device, or: flutter run -d chrome
```

Screens

* **Home**: a story tray. Tap an avatar to open the viewer; rings turn grey as stories are seen.
* **Viewer**: cube transition, hold to pause, swipe down to close, swipe up for an action, reply bar, resume position per user, simulated video with buffering stalls.
* **Customize**: change the transition, theme, progress bars, tap zones and resume mode live.

All images are generated in code (`lib/art.dart`); the "video" is `SimulatedStoryVideoAdapter`. See the package README for a `video_player` adapter.
