import 'package:flutter/widgets.dart';

import '../theme/story_deck_theme.dart';
import '../utils/format_age.dart';
import 'story_overlay_data.dart';

/// Default header: avatar, name, "2h" age and an optional close button.
///
/// Use it as is, wrap it, or replace it with your own via
/// `StoryDeck.headerBuilder`.
class StoryHeader extends StatelessWidget {
  /// Creates a header for [data].
  const StoryHeader({
    super.key,
    required this.data,
    this.theme = const StoryDeckTheme(),
    this.onClose,
    this.trailing = const <Widget>[],
    this.now,
  });

  /// The story shown.
  final StoryOverlayData data;

  /// Text styles and colors.
  final StoryDeckTheme theme;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  /// Extra widgets before the close button (menu, mute...).
  final List<Widget> trailing;

  /// Clock for the age label; defaults to `DateTime.now()`. Useful in tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final created = data.item.createdAt;
    final age = created == null ? null : formatStoryAge(created, now: now);
    final subtitle = data.group.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.progressTrackColor,
              image: data.group.avatar == null
                  ? null
                  : DecorationImage(
                      image: data.group.avatar!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(data.group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleStyle),
                    ),
                    if (age != null) ...[
                      const SizedBox(width: 8),
                      Text(age, style: theme.subtitleStyle),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.subtitleStyle),
              ],
            ),
          ),
          ...trailing,
          if (onClose != null)
            Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CustomPaint(painter: _CrossPainter(theme.iconColor)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    canvas.drawLine(c + const Offset(-7, -7), c + const Offset(7, 7), p);
    canvas.drawLine(c + const Offset(-7, 7), c + const Offset(7, -7), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}
