import 'package:flutter/material.dart';
import 'package:story_deck/story_deck.dart';

import 'art.dart';

/// Builds the synthetic demo users and their stories. Names are invented.
Future<List<StoryGroup>> buildDemoGroups({DateTime? now}) async {
  final t = now ?? DateTime.now();
  Future<StoryItem> img(String id, ArtSpec spec, String caption, Duration age,
      {Duration? duration}) async {
    return StoryItem.image(
      id: id,
      image: await renderArt(spec),
      caption: caption,
      createdAt: t.subtract(age),
      duration: duration,
      semanticLabel: caption,
    );
  }

  final mira = StoryGroup(
    id: 'mira',
    title: 'mira.okafor',
    subtitle: 'Golden hour',
    avatar:
        await renderAvatar(const Color(0xFFFF8C42), const Color(0xFFC81D77), 1),
    items: [
      await img(
          'm1',
          const ArtSpec(ArtKind.sunset, Color(0xFFFFB347), Color(0xFFC81D77),
              seed: 2),
          'Chasing the last light',
          const Duration(hours: 2)),
      await img(
          'm2',
          const ArtSpec(ArtKind.sunset, Color(0xFFFF6F91), Color(0xFF4B1D6B),
              seed: 5),
          'It only lasts a minute',
          const Duration(hours: 2)),
      StoryItem.custom(
        id: 'm3',
        createdAt: t.subtract(const Duration(hours: 1)),
        duration: const Duration(seconds: 4),
        builder: (context, playback) => const PollCard(),
      ),
    ],
  );

  final kenji = StoryGroup(
    id: 'kenji',
    title: 'kenji.aoki',
    subtitle: 'Weekend trip',
    avatar:
        await renderAvatar(const Color(0xFF36D1DC), const Color(0xFF5B86E5), 2),
    items: [
      await img(
          'k1',
          const ArtSpec(ArtKind.waves, Color(0xFF36D1DC), Color(0xFF14325C),
              seed: 1),
          'Low tide, high spirits',
          const Duration(hours: 5)),
      StoryItem.video(
        id: 'k2',
        videoSource: const Color(0xFF5B86E5),
        caption: 'Video story (simulated player, with a stall)',
        createdAt: t.subtract(const Duration(hours: 4)),
      ),
      await img(
          'k3',
          const ArtSpec(ArtKind.mountains, Color(0xFF9FB8FF), Color(0xFF1B2A55),
              seed: 7),
          'Ridge walk',
          const Duration(hours: 3)),
    ],
  );

  final zoe = StoryGroup(
    id: 'zoe',
    title: 'zoe.lindqvist',
    avatar:
        await renderAvatar(const Color(0xFFA18CD1), const Color(0xFFFBC2EB), 3),
    items: [
      await img(
          'z1',
          const ArtSpec(ArtKind.bubbles, Color(0xFFA18CD1), Color(0xFFFBC2EB),
              seed: 3),
          'Soap bubble season',
          const Duration(hours: 9)),
      await img(
          'z2',
          const ArtSpec(ArtKind.bubbles, Color(0xFF84FAB0), Color(0xFF8FD3F4),
              seed: 8),
          'Mint edition',
          const Duration(hours: 8)),
    ],
  );

  final omar = StoryGroup(
    id: 'omar',
    title: 'omar.haddad',
    subtitle: 'Studio',
    avatar:
        await renderAvatar(const Color(0xFF56AB2F), const Color(0xFFA8E063), 4),
    items: [
      await img(
          'o1',
          const ArtSpec(ArtKind.stripes, Color(0xFF56AB2F), Color(0xFFF7971E),
              seed: 4),
          'New print, day 1',
          const Duration(days: 1)),
      await img(
          'o2',
          const ArtSpec(ArtKind.stripes, Color(0xFF283C86), Color(0xFF45A247),
              seed: 6),
          'Day 2',
          const Duration(days: 1)),
    ],
  );

  return [mira, kenji, zoe, omar];
}

/// A custom (non-image) story: a poll card drawn with plain widgets.
class PollCard extends StatelessWidget {
  const PollCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, double value) => Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(children: [
            FractionallySizedBox(
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(24)),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16))),
          ]),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42275A), Color(0xFF734B6D)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tea or coffee?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            option('Tea  62%', 0.62),
            option('Coffee  38%', 0.38),
          ],
        ),
      ),
    );
  }
}
