import 'package:flutter/material.dart';
import 'package:story_deck/story_deck.dart';

import 'customize_page.dart';
import 'data.dart';
import 'settings.dart';
import 'viewer_page.dart';

void main() => runApp(const StoryDeckExampleApp());

/// The example app. Public so the demo-GIF tool can drive it.
class StoryDeckExampleApp extends StatelessWidget {
  const StoryDeckExampleApp({super.key, this.groups, this.fontFamily});

  /// Pre-built groups (the demo tool passes them in); built lazily otherwise.
  final List<StoryGroup>? groups;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'story_deck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFC81D77),
        fontFamily: fontFamily,
        useMaterial3: true,
      ),
      home: HomePage(groups: groups),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.groups});
  final List<StoryGroup>? groups;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DeckSettings settings = DeckSettings();
  final MemoryStoryViewStore store = MemoryStoryViewStore();
  List<StoryGroup>? _groups;

  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
    if (_groups == null) {
      buildDemoGroups().then((g) {
        if (mounted) setState(() => _groups = g);
      });
    }
  }

  @override
  void dispose() {
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: const Text('story_deck')),
      body: groups == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => _TrayAvatar(
                      group: groups[i],
                      store: store,
                      onTap: () async {
                        await openStories(context,
                            groups: groups,
                            startGroup: i,
                            settings: settings,
                            store: store);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Customize'),
                  subtitle: const Text(
                      'Transition, theme, progress bars, tap zones, resume mode'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => CustomizePage(
                              settings: settings,
                              groups: groups,
                              store: store))),
                ),
                const ListTile(
                  leading: Icon(Icons.keyboard),
                  title: Text('Keyboard (web / desktop)'),
                  subtitle: Text(
                      'Left/right = item, Page Up/Down = user, Space = pause, Esc = close, Up = swipe-up action'),
                ),
              ],
            ),
    );
  }
}

class _TrayAvatar extends StatelessWidget {
  const _TrayAvatar(
      {required this.group, required this.store, required this.onTap});

  final StoryGroup group;
  final StoryViewStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allSeen = group.items.every((i) => store.isSeen(group.id, i.id));
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: allSeen
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF8C42), Color(0xFFC81D77)]),
                color: allSeen ? Colors.grey.shade400 : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: CircleAvatar(radius: 28, backgroundImage: group.avatar),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
