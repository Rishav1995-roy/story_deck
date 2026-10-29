import 'package:flutter/material.dart';
import 'package:story_deck/story_deck.dart';

import 'settings.dart';

/// Opens the viewer on a transparent route so the home screen shows through
/// while the deck is dragged down.
Future<void> openStories(
  BuildContext context, {
  required List<StoryGroup> groups,
  required int startGroup,
  required DeckSettings settings,
  required StoryViewStore store,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, a, b) => StoryViewerPage(
        groups: groups,
        startGroup: startGroup,
        settings: settings,
        store: store),
    transitionsBuilder: (context, a, b, child) =>
        FadeTransition(opacity: a, child: child),
  ));
}

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.groups,
    required this.startGroup,
    required this.settings,
    required this.store,
  });

  final List<StoryGroup> groups;
  final int startGroup;
  final DeckSettings settings;
  final StoryViewStore store;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late final StoryController controller =
      StoryController(initialGroup: widget.startGroup);
  String? toast;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final s = widget.settings;
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: StoryDeck(
            groups: widget.groups,
            controller: controller,
            viewStore: widget.store,
            resumeMode: s.resumeMode,
            theme: s.theme,
            transition: s.transition,
            transitionDuration: const Duration(milliseconds: 560),
            tapZoneLeftFraction: s.tapZoneLeft,
            aspectRatio: s.preset == ThemePreset.paper ? 0.5 : null,
            videoAdapterFactory: (item) => SimulatedStoryVideoAdapter(
              length: const Duration(seconds: 6),
              color: item.videoSource as Color,
              stallAt: const Duration(milliseconds: 2500),
              stallFor: const Duration(milliseconds: 1500),
            ),
            onDismiss: _close,
            onComplete: _close,
            onSwipeUp: (g, i) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Swipe up on ${g.title} / ${i.id}'))),
            swipeUpBuilder: (context, d) => const Center(
              child: Text('Swipe up for more',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6)])),
            ),
            footerBuilder: (context, d) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.item.caption != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: IgnorePointer(
                      child: Text(d.item.caption!,
                          style: s.theme.captionStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              shadows: const [Shadow(blurRadius: 8)])),
                    ),
                  ),
                if (d.isActive)
                  StoryReplyBar(
                    controller: d.controller,
                    hintText: 'Reply to ${d.group.title}...',
                    onSend: (text) => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Sent: $text'))),
                  )
                else
                  const SizedBox(height: 66),
              ],
            ),
          ),
        );
      },
    );
  }
}
