import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../theme/story_deck_theme.dart';

/// The row of segmented progress bars.
///
/// Segments before [currentIndex] are full, the one at [currentIndex] follows
/// [progress], the rest are empty. Only the current segment repaints on each
/// frame.
class StoryProgressBars extends StatelessWidget {
  /// Creates the bar row.
  const StoryProgressBars({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.progress,
    this.theme = const StoryDeckTheme(),
  });

  /// Number of segments.
  final int count;

  /// The segment being played.
  final int currentIndex;

  /// Progress of the current segment from 0 to 1.
  final ValueListenable<double> progress;

  /// Colors and sizes.
  final StoryDeckTheme theme;

  @override
  Widget build(BuildContext context) {
    final completed = theme.progressCompletedColor ?? theme.progressActiveColor;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: theme.progressSpacing),
          Expanded(
            child: _Segment(
              height: theme.progressHeight,
              radius: theme.progressRadius,
              track: theme.progressTrackColor,
              fill: i < currentIndex ? completed : theme.progressActiveColor,
              fraction: i < currentIndex ? 1 : (i == currentIndex ? null : 0),
              progress: progress,
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.height,
    required this.radius,
    required this.track,
    required this.fill,
    required this.fraction,
    required this.progress,
  });

  final double height;
  final double radius;
  final Color track;
  final Color fill;
  final double? fraction; // null = follow progress
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget bar(double f) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: f.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: borderRadius),
          ),
        );
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: borderRadius),
        child: fraction != null
            ? bar(fraction!)
            : ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, v, _) => bar(v),
              ),
      ),
    );
  }
}
