import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Wraps the page of one user while the deck scrolls between users.
///
/// [offset] is the page position relative to the viewport: `0` = centred,
/// `-1` = fully off to the left, `1` = fully off to the right.
typedef StoryTransitionBuilder = Widget Function(
    BuildContext context, Widget child, double offset);

/// The animation between two users' stories.
@immutable
class StoryTransition {
  /// A custom transition.
  const StoryTransition.custom(this.builder);

  const StoryTransition._(this.builder);

  /// Builds the transformed page.
  final StoryTransitionBuilder builder;

  /// Plain horizontal slide.
  static const StoryTransition slide = StoryTransition._(_slide);

  /// The pages are faces of a rotating 3D cube.
  static const StoryTransition cube = StoryTransition._(_cube);

  /// The leaving page shrinks and dims while the next one slides over it.
  static const StoryTransition depth = StoryTransition._(_depth);

  /// Cross-fade: pages stay in place and fade into each other.
  static const StoryTransition fade = StoryTransition._(_fade);

  /// Rotation in radians of a cube face at [offset]. Positive offsets (page to
  /// the right) rotate the other way round.
  static double cubeAngle(double offset) =>
      -offset.clamp(-1.0, 1.0) * math.pi / 2;

  /// Scale of the leaving page in [depth] at [offset].
  static double depthScale(double offset) {
    final o = offset.clamp(-1.0, 1.0);
    return o < 0 ? 1 + 0.15 * o : 1;
  }

  /// Opacity in [fade] at [offset].
  static double fadeOpacity(double offset) =>
      (1 - offset.abs()).clamp(0.0, 1.0);

  static Widget _slide(BuildContext context, Widget child, double offset) =>
      child;

  static Widget _cube(BuildContext context, Widget child, double offset) {
    if (offset == 0) return child;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(cubeAngle(offset));
    return Transform(
      transform: matrix,
      alignment: offset < 0 ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color.fromRGBO(0, 0, 0, 0.45 * offset.abs().clamp(0, 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _depth(BuildContext context, Widget child, double offset) {
    final scale = depthScale(offset);
    if (scale == 1) return child;
    return Transform.scale(
      scale: scale,
      child: Opacity(opacity: 1 - 0.5 * offset.abs().clamp(0, 1), child: child),
    );
  }

  static Widget _fade(BuildContext context, Widget child, double offset) {
    if (offset == 0) return child;
    return LayoutBuilder(builder: (context, c) {
      return Transform.translate(
        offset: Offset(-offset * c.maxWidth, 0),
        child: Opacity(opacity: fadeOpacity(offset), child: child),
      );
    });
  }
}
