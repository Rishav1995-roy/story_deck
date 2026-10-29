import 'package:flutter/widgets.dart';

/// Visual settings of a `StoryDeck`.
@immutable
class StoryDeckTheme {
  /// Creates a theme. Every value has a sensible default.
  const StoryDeckTheme({
    this.backgroundColor = const Color(0xFF000000),
    this.backdropColor = const Color(0xFF000000),
    this.cardBorderRadius = BorderRadius.zero,
    this.mediaFit = BoxFit.cover,
    this.progressHeight = 2.5,
    this.progressSpacing = 4,
    this.progressRadius = 2,
    this.progressPadding = const EdgeInsets.fromLTRB(8, 8, 8, 0),
    this.progressActiveColor = const Color(0xFFFFFFFF),
    this.progressTrackColor = const Color(0x55FFFFFF),
    this.progressCompletedColor,
    this.loadingColor = const Color(0xFFFFFFFF),
    this.topScrim = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x99000000), Color(0x00000000)],
    ),
    this.bottomScrim = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0x99000000), Color(0x00000000)],
    ),
    this.titleStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    this.subtitleStyle = const TextStyle(
      color: Color(0xCCFFFFFF),
      fontSize: 12,
    ),
    this.captionStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 16,
      height: 1.3,
    ),
    this.iconColor = const Color(0xFFFFFFFF),
  });

  /// Behind the media inside a card.
  final Color backgroundColor;

  /// Around the card (when `aspectRatio` is set) and behind it while
  /// dismissing.
  final Color backdropColor;

  /// Corner radius of the story card.
  final BorderRadius cardBorderRadius;

  /// Default fit of images and videos.
  final BoxFit mediaFit;

  /// Thickness of a progress segment.
  final double progressHeight;

  /// Gap between progress segments.
  final double progressSpacing;

  /// Corner radius of a progress segment.
  final double progressRadius;

  /// Padding around the progress bar row (the safe area is added on top).
  final EdgeInsets progressPadding;

  /// Fill of the segment being played (and completed ones by default).
  final Color progressActiveColor;

  /// Background of segments.
  final Color progressTrackColor;

  /// Fill of already completed segments. Defaults to [progressActiveColor].
  final Color? progressCompletedColor;

  /// Color of the default loading and buffering spinner.
  final Color loadingColor;

  /// Gradient behind the header. `null` for none.
  final Gradient? topScrim;

  /// Gradient behind the footer. `null` for none.
  final Gradient? bottomScrim;

  /// Header name style.
  final TextStyle titleStyle;

  /// Header second line style.
  final TextStyle subtitleStyle;

  /// Caption style.
  final TextStyle captionStyle;

  /// Color of the default close button and arrows.
  final Color iconColor;

  /// Copy with replaced values.
  StoryDeckTheme copyWith({
    Color? backgroundColor,
    Color? backdropColor,
    BorderRadius? cardBorderRadius,
    BoxFit? mediaFit,
    double? progressHeight,
    double? progressSpacing,
    double? progressRadius,
    EdgeInsets? progressPadding,
    Color? progressActiveColor,
    Color? progressTrackColor,
    Color? progressCompletedColor,
    Color? loadingColor,
    Gradient? topScrim,
    Gradient? bottomScrim,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? captionStyle,
    Color? iconColor,
  }) {
    return StoryDeckTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backdropColor: backdropColor ?? this.backdropColor,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      mediaFit: mediaFit ?? this.mediaFit,
      progressHeight: progressHeight ?? this.progressHeight,
      progressSpacing: progressSpacing ?? this.progressSpacing,
      progressRadius: progressRadius ?? this.progressRadius,
      progressPadding: progressPadding ?? this.progressPadding,
      progressActiveColor: progressActiveColor ?? this.progressActiveColor,
      progressTrackColor: progressTrackColor ?? this.progressTrackColor,
      progressCompletedColor:
          progressCompletedColor ?? this.progressCompletedColor,
      loadingColor: loadingColor ?? this.loadingColor,
      topScrim: topScrim ?? this.topScrim,
      bottomScrim: bottomScrim ?? this.bottomScrim,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}
