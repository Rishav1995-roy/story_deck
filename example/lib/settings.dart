import 'package:flutter/material.dart';
import 'package:story_deck/story_deck.dart';

enum ThemePreset { midnight, paper }

/// Live-editable options used by the viewer and the customize screen.
class DeckSettings extends ChangeNotifier {
  StoryTransition transition = StoryTransition.cube;
  String transitionName = 'cube';
  ThemePreset preset = ThemePreset.midnight;
  double progressHeight = 2.5;
  double tapZoneLeft = 0.3;
  StoryResumeMode resumeMode = StoryResumeMode.lastViewed;
  bool card = false;

  static final Map<String, StoryTransition> transitions = {
    'cube': StoryTransition.cube,
    'depth': StoryTransition.depth,
    'slide': StoryTransition.slide,
    'fade': StoryTransition.fade,
  };

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  StoryDeckTheme get theme {
    final base = switch (preset) {
      ThemePreset.midnight => const StoryDeckTheme(),
      ThemePreset.paper => const StoryDeckTheme(
          backgroundColor: Color(0xFFF4EFE6),
          backdropColor: Color(0xFFF4EFE6),
          cardBorderRadius: BorderRadius.all(Radius.circular(22)),
          progressActiveColor: Color(0xFFC81D77),
          progressTrackColor: Color(0x55FFFFFF),
          progressCompletedColor: Color(0xFFFFFFFF),
        ),
    };
    return base.copyWith(progressHeight: progressHeight);
  }
}
