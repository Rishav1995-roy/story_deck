import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/story_models.dart';
import '../theme/story_deck_theme.dart';
import '../widgets/story_overlay_data.dart';
import 'story_image_layer.dart';
import 'story_playback.dart';
import 'video_adapter.dart';

/// Shows a video item through a [StoryVideoAdapter] and keeps the story timer
/// glued to real playback.
///
/// * progress = adapter position / adapter duration (never a free-running timer)
/// * buffering stops the bar
/// * pause reasons (hold, drag, background, controller) pause the player
/// * leaving the item pauses the player; the pool disposes it
class StoryVideoLayer extends StatefulWidget {
  /// Creates the layer.
  const StoryVideoLayer({
    super.key,
    required this.item,
    required this.entry,
    required this.playback,
    required this.isActive,
    required this.theme,
    this.bufferingBuilder,
    this.errorBuilder,
  });

  /// The video item.
  final StoryItem item;

  /// Pool entry with the adapter.
  final StoryVideoEntry entry;

  /// Handle steering the timer.
  final StoryPlayback playback;

  /// Whether this page is the playing one.
  final bool isActive;

  /// Fit and colors.
  final StoryDeckTheme theme;

  /// Replaces the default buffering spinner.
  final WidgetBuilder? bufferingBuilder;

  /// Replaces the default error view.
  final StoryErrorBuilder? errorBuilder;

  @override
  State<StoryVideoLayer> createState() => _StoryVideoLayerState();
}

class _StoryVideoLayerState extends State<StoryVideoLayer> {
  bool _initialized = false;
  Object? _error;
  bool _playing = false;
  bool _buffering = false;
  bool _wired = false;
  int _generation = 0;

  StoryVideoAdapter get _adapter => widget.entry.adapter;

  @override
  void initState() {
    super.initState();
    _initialized = widget.entry.isReady;
    unawaited(_waitForInit());
    if (widget.isActive) _activate();
  }

  Future<void> _waitForInit() async {
    try {
      await widget.entry.ready;
      if (!mounted) return;
      setState(() => _initialized = true);
      if (widget.isActive) _activate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      if (widget.isActive) widget.playback.fail(e);
    }
  }

  @override
  void didUpdateWidget(StoryVideoLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.playback, widget.playback) ||
        old.isActive != widget.isActive) {
      _unwire(old.playback);
      if (old.isActive && !widget.isActive) _pause();
      if (widget.isActive) _activate();
    }
  }

  void _activate() {
    if (_wired) return;
    if (_error != null) {
      widget.playback.fail(_error!);
      return;
    }
    if (!_initialized) return;
    _wired = true;
    final gen = ++_generation;
    // A re-opened story always starts from the beginning.
    final start = _adapter.position;
    final rewind = start > const Duration(milliseconds: 200)
        ? Future<void>.sync(() => _adapter.seekTo(Duration.zero))
        : Future<void>.value();
    unawaited(rewind.then((_) {
      if (!mounted || gen != _generation || !_wired) return;
      widget.playback.markReady(duration: _capped(_adapter.duration));
      widget.playback.isPaused.addListener(_syncPlayState);
      _adapter.addListener(_onAdapter);
      _syncPlayState();
      _onAdapter();
    }));
  }

  Duration _capped(Duration d) {
    final cap = widget.item.duration;
    return cap != null && cap < d ? cap : d;
  }

  void _unwire(StoryPlayback playback) {
    _generation++;
    _wired = false;
    playback.isPaused.removeListener(_syncPlayState);
    _adapter.removeListener(_onAdapter);
  }

  void _syncPlayState() {
    if (!_wired) return;
    if (widget.playback.isPaused.value) {
      _pause();
    } else if (!_playing) {
      _playing = true;
      unawaited(Future<void>.sync(_adapter.play).catchError(_fail));
    }
  }

  void _pause() {
    if (!_playing) return;
    _playing = false;
    unawaited(Future<void>.sync(_adapter.pause).catchError((Object _) {}));
  }

  void _fail(Object e) {
    if (mounted) setState(() => _error = e);
    widget.playback.fail(e);
  }

  void _onAdapter() {
    if (!_wired || !mounted) return;
    final err = _adapter.error;
    if (err != null) {
      _fail(err);
      return;
    }
    final buffering = _adapter.isBuffering;
    if (buffering != _buffering) {
      setState(() => _buffering = buffering);
      widget.playback.setBuffering(buffering);
    }
    final total = _adapter.duration;
    final cap = _capped(total);
    if (total > Duration.zero) {
      // The bar covers the (possibly capped) length of the item.
      widget.playback.reportProgress(
          _adapter.position.inMicroseconds / cap.inMicroseconds);
    }
  }

  @override
  void dispose() {
    _unwire(widget.playback);
    // Never leave a video playing behind a story that is gone.
    _pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ??
          StoryDefaultError(color: widget.theme.iconColor);
    }
    final fit = widget.item.fit ?? widget.theme.mediaFit;
    final children = <Widget>[];
    if (widget.item.poster != null) {
      children.add(Image(
          image: widget.item.poster!,
          fit: fit,
          width: double.infinity,
          height: double.infinity));
    }
    if (_initialized) {
      final size = _adapter.videoSize;
      final view = _adapter.buildView(context);
      children.add(Positioned.fill(
        child: size == null || size.isEmpty
            ? view
            : ClipRect(
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                      width: size.width, height: size.height, child: view),
                ),
              ),
      ));
    }
    if (!_initialized || _buffering) {
      children.add(Positioned.fill(
        child: widget.bufferingBuilder?.call(context) ??
            StoryDefaultSpinner(color: widget.theme.loadingColor),
      ));
    }
    return Semantics(
      label: widget.item.semanticLabel,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }
}
