import 'package:flutter/widgets.dart';

import '../models/story_models.dart';
import '../theme/story_deck_theme.dart';
import '../widgets/story_overlay_data.dart';
import 'story_playback.dart';

/// Shows an image item and reports load / failure to [playback].
///
/// The story timer starts only after the first frame of the image is ready,
/// so a slow network never eats the display time.
class StoryImageLayer extends StatefulWidget {
  /// Creates the layer.
  const StoryImageLayer({
    super.key,
    required this.item,
    required this.playback,
    required this.theme,
    this.errorBuilder,
    this.loadingBuilder,
  });

  /// The image item.
  final StoryItem item;

  /// Handle to report loading to.
  final StoryPlayback playback;

  /// Fit and colors.
  final StoryDeckTheme theme;

  /// Replaces the default error view.
  final StoryErrorBuilder? errorBuilder;

  /// Replaces the default spinner.
  final WidgetBuilder? loadingBuilder;

  @override
  State<StoryImageLayer> createState() => _StoryImageLayerState();
}

class _StoryImageLayerState extends State<StoryImageLayer> {
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  bool _loaded = false;
  Object? _error;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener(_onImage, onError: _onError);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(StoryImageLayer old) {
    super.didUpdateWidget(old);
    if (old.item.image != widget.item.image) {
      _loaded = false;
      _error = null;
      _reported = false;
      _resolve();
    } else if (!identical(old.playback, widget.playback)) {
      _reported = false;
      _report();
    }
  }

  void _resolve() {
    final stream =
        widget.item.image!.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool sync) {
    _loaded = true;
    if (!sync && mounted) setState(() {});
    _report();
  }

  void _onError(Object error, StackTrace? stack) {
    _error = error;
    if (mounted) setState(() {});
    _report();
  }

  void _report() {
    if (_reported || !widget.playback.isActive) return;
    if (_loaded) {
      _reported = true;
      widget.playback.markReady();
    } else if (_error != null) {
      _reported = true;
      widget.playback.fail(_error!);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ??
          StoryDefaultError(color: widget.theme.iconColor);
    }
    if (!_loaded) {
      return widget.loadingBuilder?.call(context) ??
          StoryDefaultSpinner(color: widget.theme.loadingColor);
    }
    return Semantics(
      image: true,
      label: widget.item.semanticLabel,
      child: Image(
        image: widget.item.image!,
        fit: widget.item.fit ?? widget.theme.mediaFit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Default error view.
class StoryDefaultError extends StatelessWidget {
  /// Creates it.
  const StoryDefaultError({super.key, required this.color});

  /// Text color.
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('Could not load this story',
            style: TextStyle(color: color, fontSize: 14)),
      );
}

/// Default loading indicator (no Material dependency).
class StoryDefaultSpinner extends StatefulWidget {
  /// Creates it.
  const StoryDefaultSpinner({super.key, required this.color});

  /// Arc color.
  final Color color;

  @override
  State<StoryDefaultSpinner> createState() => _StoryDefaultSpinnerState();
}

class _StoryDefaultSpinnerState extends State<StoryDefaultSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: RepaintBoundary(
          child: CustomPaint(
            size: const Size(32, 32),
            painter: _SpinnerPainter(_c, widget.color),
          ),
        ),
      );
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Offset.zero & size, t.value * 6.2832, 4.2, false, p);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}
