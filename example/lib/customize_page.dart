import 'package:flutter/material.dart';
import 'package:story_deck/story_deck.dart';

import 'settings.dart';
import 'viewer_page.dart';

class CustomizePage extends StatelessWidget {
  const CustomizePage({
    super.key,
    required this.settings,
    required this.groups,
    required this.store,
  });

  final DeckSettings settings;
  final List<StoryGroup> groups;
  final StoryViewStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customize')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Transition between users'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final k in DeckSettings.transitions.keys)
                  ButtonSegment(value: k, label: Text(k)),
              ],
              selected: {settings.transitionName},
              onSelectionChanged: (v) => settings.update(() {
                settings.transitionName = v.first;
                settings.transition = DeckSettings.transitions[v.first]!;
              }),
            ),
            const SizedBox(height: 20),
            const Text('Theme'),
            const SizedBox(height: 8),
            SegmentedButton<ThemePreset>(
              segments: const [
                ButtonSegment(
                    value: ThemePreset.midnight, label: Text('Midnight')),
                ButtonSegment(
                    value: ThemePreset.paper, label: Text('Paper card')),
              ],
              selected: {settings.preset},
              onSelectionChanged: (v) =>
                  settings.update(() => settings.preset = v.first),
            ),
            const SizedBox(height: 20),
            Text(
                'Progress bar thickness: ${settings.progressHeight.toStringAsFixed(1)}'),
            Slider(
              min: 1,
              max: 8,
              value: settings.progressHeight,
              onChanged: (v) =>
                  settings.update(() => settings.progressHeight = v),
            ),
            Text(
                'Left tap zone (previous): ${(settings.tapZoneLeft * 100).round()}%'),
            Slider(
              min: 0,
              max: 0.7,
              value: settings.tapZoneLeft,
              onChanged: (v) => settings.update(() => settings.tapZoneLeft = v),
            ),
            const Text('When a user is opened again'),
            const SizedBox(height: 8),
            SegmentedButton<StoryResumeMode>(
              segments: const [
                ButtonSegment(
                    value: StoryResumeMode.restart, label: Text('Restart')),
                ButtonSegment(
                    value: StoryResumeMode.lastViewed,
                    label: Text('Last viewed')),
                ButtonSegment(
                    value: StoryResumeMode.firstUnseen,
                    label: Text('First unseen')),
              ],
              selected: {settings.resumeMode},
              onSelectionChanged: (v) =>
                  settings.update(() => settings.resumeMode = v.first),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Preview'),
              onPressed: () => openStories(context,
                  groups: groups,
                  startGroup: 0,
                  settings: settings,
                  store: store),
            ),
          ],
        ),
      ),
    );
  }
}
