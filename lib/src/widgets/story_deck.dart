import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../media/story_image_layer.dart';
import '../media/story_playback.dart';
import '../media/story_video_layer.dart';
import '../media/video_adapter.dart';
import '../models/story_models.dart';
import '../state/progress_model.dart';
import '../state/story_controller.dart';
import '../state/view_store.dart';
import '../theme/story_deck_theme.dart';
import '../transitions/story_transition.dart';
import 'story_header.dart';
import 'story_overlay_data.dart';
import 'story_progress_bars.dart';

/// Builds your own media for an item. Return `null` to use the built-in
/// image / video / custom handling. Content you return must call
/// [StoryPlayback.markReady] when it is showing, otherwise the timer never
/// starts.
typedef StoryMediaBuilder = Widget? Function(
    BuildContext context, StoryItem item, StoryPlayback playback);

/// An Instagram-style stories viewer: several users' story groups with a 3D
/// cube (or other) transition between users, segmented progress bars, tap
/// zones, hold to pause, swipe down to dismiss and swipe up for an action.
///
/// Images are built in. Videos go through a [StoryVideoAdapter] that you
/// implement on top of your player of choice, so the progress bar follows real
/// playback and buffering pauses the timer.
class StoryDeck extends StatefulWidget {
  /// Creates the deck.
  const StoryDeck({
    super.key,
    required this.groups,
    this.controller,
    this.viewStore,
    this.resumeMode = StoryResumeMode.lastViewed,
    this.videoAdapterFactory,
    this.mediaBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.swipeUpBuilder,
    this.progressBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.bufferingBuilder,
    this.theme = const StoryDeckTheme(),
    this.transition = StoryTransition.cube,
    this.transitionDuration = const Duration(milliseconds: 420),
    this.transitionCurve = Curves.easeOutCubic,
    this.defaultDuration = const Duration(seconds: 5),
    this.holdDelay = const Duration(milliseconds: 180),
    this.tapZoneLeftFraction = 0.3,
    this.preloadItems = 2,
    this.enableSwipeBetweenGroups = true,
    this.dismissOnSwipeDown = true,
    this.enableKeyboard = true,
    this.showNavigationArrows,
    this.showHeader = true,
    this.aspectRatio,
    this.errorSkipDelay,
    this.onDismiss,
    this.onComplete,
    this.onSwipeUp,
    this.onItemChanged,
    this.onItemSeen,
    this.onGroupCompleted,
    this.onItemError,
  })  : assert(tapZoneLeftFraction >= 0 && tapZoneLeftFraction <= 0.9),
        assert(preloadItems >= 0);

  /// The users' stories, in order.
  final List<StoryGroup> groups;

  /// Optional controller to navigate, pause and observe the deck.
  final StoryController? controller;

  /// Remembers seen items and resume positions. Defaults to an in-memory one.
  final StoryViewStore? viewStore;

  /// Where a user's stories start when she is opened again.
  final StoryResumeMode resumeMode;

  /// Creates the adapter for a video item. Required when any item is a video.
  final StoryVideoAdapterFactory? videoAdapterFactory;

  /// Builds custom media; see [StoryMediaBuilder].
  final StoryMediaBuilder? mediaBuilder;

  /// Replaces the default [StoryHeader].
  final StoryOverlayBuilder? headerBuilder;

  /// Bottom overlay (caption, reply bar). Defaults to the item caption.
  final StoryOverlayBuilder? footerBuilder;

  /// Hint shown at the bottom while the user drags up. Only used when
  /// [onSwipeUp] is set.
  final StoryOverlayBuilder? swipeUpBuilder;

  /// Replaces the default [StoryProgressBars].
  final StoryProgressBuilder? progressBuilder;

  /// Replaces the default error view of failed media.
  final StoryErrorBuilder? errorBuilder;

  /// Replaces the default image loading spinner.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the default video buffering spinner.
  final WidgetBuilder? bufferingBuilder;

  /// Colors, sizes and text styles.
  final StoryDeckTheme theme;

  /// Animation between users.
  final StoryTransition transition;

  /// Length of the animated switch to another user.
  final Duration transitionDuration;

  /// Curve of the animated switch to another user.
  final Curve transitionCurve;

  /// Display time of images and custom items without their own duration.
  final Duration defaultDuration;

  /// How long a press must last to count as a hold (pause) instead of a tap.
  final Duration holdDelay;

  /// Fraction of the width (from the leading edge) that goes to the previous
  /// item; the rest goes to the next one.
  final double tapZoneLeftFraction;

  /// How many items ahead are preloaded (images are pre-cached, videos are
  /// initialized).
  final int preloadItems;

  /// Whether a horizontal swipe switches users.
  final bool enableSwipeBetweenGroups;

  /// Whether a downward swipe calls [onDismiss].
  final bool dismissOnSwipeDown;

  /// Whether keyboard shortcuts work: left/right = previous/next item,
  /// page up/down = previous/next user, space = pause, escape = dismiss,
  /// up = swipe-up action.
  final bool enableKeyboard;

  /// Shows previous/next arrows on mouse hover. Defaults to `true` on web and
  /// desktop platforms.
  final bool? showNavigationArrows;

  /// Whether the default header is shown (ignored when [headerBuilder] set).
  final bool showHeader;

  /// Lays the deck out as a centred card of this width / height ratio (for
  /// example `9 / 16`) on a wide screen. `null` fills the available space.
  final double? aspectRatio;

  /// When set, a failed item is skipped automatically after this delay.
  final Duration? errorSkipDelay;

  /// Called when the user dismisses the deck (swipe down, close button,
  /// escape). You pop the route.
  final VoidCallback? onDismiss;

  /// Called when the last item of the last user finished.
  final VoidCallback? onComplete;

  /// Called when the user swipes up (or presses the up arrow).
  final void Function(StoryGroup group, StoryItem item)? onSwipeUp;

  /// Called whenever the current item changes.
  final ValueChanged<StoryPosition>? onItemChanged;

  /// Called when an item is on screen for the first time.
  final void Function(StoryGroup group, StoryItem item)? onItemSeen;

  /// Called when the last item of a group finished.
  final void Function(StoryGroup group, int groupIndex)? onGroupCompleted;

  /// Called when media fails to load or play.
  final void Function(StoryGroup group, StoryItem item, Object error)?
      onItemError;

  @override
  State<StoryDeck> createState() => _StoryDeckState();
}

class _StoryDeckState extends State<StoryDeck>
    with TickerProviderStateMixin, WidgetsBindingObserver
    implements StoryControllerDelegate {
  late StoryController _controller;
  bool _ownsController = false;
  late StoryViewStore _store;
  late PageController _pages;
  StoryVideoPool? _pool;
  final FocusNode _focus = FocusNode(debugLabel: 'StoryDeck');
  // Keeps the page view alive when the card layout changes at runtime.
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'StoryDeckCard');

  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  late StoryProgressModel _model;
  late ModelStoryPlayback _playback;
  bool _modelHandled = false;
  bool _seenMarked = false;
  Timer? _errorTimer;

  int _group = 0;
  int _item = 0;

  // pause reasons that outlive an item
  final Set<StoryPauseReason> _sticky = <StoryPauseReason>{};

  // pointer / gestures
  int? _pointer;
  Offset _downPosition = Offset.zero;
  bool _moved = false;
  bool _held = false;
  Timer? _holdTimer;
  bool _hovering = false;
  bool _animatingGroup = false;

  final ValueNotifier<double> _dragDy = ValueNotifier<double>(0);
  late AnimationController _settle;
  double _settleFrom = 0;
  double _settleTo = 0;
  bool _dismissing = false;

  static final ValueNotifier<double> _zero = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = widget.viewStore ?? MemoryStoryViewStore();
    _initController();
    _group = _controller.initialGroup.clamp(0, widget.groups.length - 1);
    _item = (_controller.initialItem ?? _startIndex(_group))
        .clamp(0, widget.groups[_group].items.length - 1);
    _pages = PageController(initialPage: _group);
    _pool = widget.videoAdapterFactory == null
        ? null
        : StoryVideoPool(widget.videoAdapterFactory!);
    _ticker = createTicker(_onTick);
    _settle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        _dragDy.value = _settleFrom +
            (_settleTo - _settleFrom) *
                Curves.easeOutCubic.transform(_settle.value);
      })
      ..addStatusListener(_onSettleStatus);
    _beginItem(notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onItemChanged?.call(StoryPosition(_group, _item));
    });
  }

  void _initController() {
    _controller = widget.controller ?? StoryController();
    _ownsController = widget.controller == null;
    _controller.attachDeck(this);
    _controller.pauseHook = (p) => _setReason(StoryPauseReason.external, p);
  }

  @override
  void didUpdateWidget(StoryDeck old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _controller.detachDeck(this);
      _controller.pauseHook = null;
      if (_ownsController) _controller.dispose();
      _initController();
    }
    if (old.videoAdapterFactory != widget.videoAdapterFactory) {
      _pool?.disposeAll();
      _pool = widget.videoAdapterFactory == null
          ? null
          : StoryVideoPool(widget.videoAdapterFactory!);
    }
    if (old.groups != widget.groups) {
      final g = _group.clamp(0, widget.groups.length - 1);
      final sameGroup = g == _group &&
          old.groups.length > g &&
          old.groups[g].id == widget.groups[g].id;
      if (!sameGroup) {
        _group = g;
        _item = _startIndex(g);
        if (_pages.hasClients) _pages.jumpToPage(g);
        _beginItem();
      } else if (_item >= widget.groups[g].items.length) {
        _item = widget.groups[g].items.length - 1;
        _beginItem();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _errorTimer?.cancel();
    _ticker.dispose();
    _settle.dispose();
    _dragDy.dispose();
    _playback.dispose();
    _model.removeListener(_onModel);
    _model.dispose();
    _pool?.disposeAll();
    _controller.detachDeck(this);
    _controller.pauseHook = null;
    if (_ownsController) _controller.dispose();
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- state

  StoryGroup get _currentGroup => widget.groups[_group];
  StoryItem get _currentItem => _currentGroup.items[_item];

  int _startIndex(int group) =>
      resolveStartIndex(widget.groups[group], _store, widget.resumeMode);

  /// Starts the item at `_group` / `_item` with a fresh model and handle.
  void _beginItem({bool notify = true}) {
    if (notify) {
      _playback.dispose();
      _model.removeListener(_onModel);
      _model.progress.removeListener(_onProgress);
      _model.dispose();
    }
    _errorTimer?.cancel();
    final item = _currentItem;
    _model =
        StoryProgressModel(duration: item.duration ?? widget.defaultDuration)
          ..addListener(_onModel);
    _model.progress.addListener(_onProgress);
    _modelHandled = false;
    _seenMarked = false;
    _playback = ModelStoryPlayback(_model, onFail: _onItemFailed);
    for (final r in _sticky) {
      _model.addReason(r);
    }
    if (_held) _model.addReason(StoryPauseReason.hold);
    if (item.type == StoryMediaType.custom) _model.markReady();

    _store.setLastIndex(_currentGroup.id, _item);
    _controller.progress.value = 0;
    _controller.updatePosition(StoryPosition(_group, _item));
    _syncPool();
    _syncTicker();
    if (notify) {
      widget.onItemChanged?.call(StoryPosition(_group, _item));
      if (mounted) setState(() {});
    }
  }

  void _onProgress() => _controller.progress.value = _model.progress.value;

  void _onModel() {
    _syncTicker();
    if (_model.isReady && !_seenMarked) {
      _seenMarked = true;
      _store.markSeen(_currentGroup.id, _currentItem.id);
      widget.onItemSeen?.call(_currentGroup, _currentItem);
    }
    if (_model.isCompleted && !_modelHandled) {
      _modelHandled = true;
      scheduleMicrotask(() {
        if (mounted) _advance();
      });
    }
  }

  void _onItemFailed(Object error, StackTrace? stack) {
    widget.onItemError?.call(_currentGroup, _currentItem, error);
    final delay = widget.errorSkipDelay;
    if (delay != null) {
      final model = _model;
      _errorTimer?.cancel();
      _errorTimer = Timer(delay, () {
        if (mounted && identical(model, _model)) _advance();
      });
    }
  }

  void _setReason(StoryPauseReason reason, bool on) {
    if (on) {
      _sticky.add(reason);
      _model.addReason(reason);
    } else {
      _sticky.remove(reason);
      _model.removeReason(reason);
    }
    if (reason == StoryPauseReason.external) _controller.updatePaused(on);
  }

  // -------------------------------------------------------------- ticker

  void _syncTicker() {
    if (_model.isTicking) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    var dt = elapsed - _lastTick;
    _lastTick = elapsed;
    if (dt > const Duration(milliseconds: 250)) {
      dt = const Duration(milliseconds: 250);
    }
    _model.advance(dt);
  }

  // ---------------------------------------------------------- navigation

  void _advance() {
    final group = _currentGroup;
    if (_item + 1 < group.items.length) {
      _item++;
      _beginItem();
      return;
    }
    _store.setLastIndex(group.id, 0);
    widget.onGroupCompleted?.call(group, _group);
    if (_group + 1 < widget.groups.length) {
      _animateToGroup(_group + 1);
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  void next() => _advance();

  @override
  void previous() {
    if (_item > 0) {
      _item--;
      _beginItem();
    } else if (_group > 0) {
      _animateToGroup(_group - 1);
    } else {
      _beginItem(); // restart the first story
    }
  }

  @override
  void nextGroup() {
    if (_group + 1 < widget.groups.length) _animateToGroup(_group + 1);
  }

  @override
  void previousGroup() {
    if (_group > 0) _animateToGroup(_group - 1);
  }

  @override
  void jumpTo(int group, [int item = 0]) {
    if (group < 0 || group >= widget.groups.length) return;
    final items = widget.groups[group].items.length;
    if (group != _group && _pages.hasClients) _pages.jumpToPage(group);
    _group = group;
    _item = item.clamp(0, items - 1);
    _beginItem();
  }

  void _animateToGroup(int target) {
    if (_animatingGroup || !_pages.hasClients) {
      _activateGroup(target);
      return;
    }
    _animatingGroup = true;
    unawaited(_pages
        .animateToPage(target,
            duration: widget.transitionDuration, curve: widget.transitionCurve)
        .whenComplete(() => _animatingGroup = false));
  }

  void _activateGroup(int target) {
    if (target == _group || target < 0 || target >= widget.groups.length) {
      return;
    }
    _group = target;
    _item = _startIndex(target);
    _beginItem();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _setReason(StoryPauseReason.transition, true);
    } else if (n is ScrollEndNotification) {
      _setReason(StoryPauseReason.transition, false);
      final page = _pages.hasClients ? _pages.page?.round() : null;
      if (page != null) _activateGroup(page);
    }
    return false;
  }

  // ---------------------------------------------------------- preloading

  void _syncPool() {
    final wanted = <String>{};
    final precache = <ImageProvider>[];
    void want(int g, int i) {
      if (g < 0 || g >= widget.groups.length) return;
      final items = widget.groups[g].items;
      if (i < 0 || i >= items.length) return;
      final item = items[i];
      if (item.type == StoryMediaType.video && _pool != null) {
        wanted.add(_key(widget.groups[g], item));
        _pool!.acquire(_key(widget.groups[g], item), item);
      } else if (item.type == StoryMediaType.image) {
        precache.add(item.image!);
      }
    }

    want(_group, _item);
    var g = _group;
    var i = _item;
    for (var k = 0; k < widget.preloadItems; k++) {
      i++;
      if (i >= widget.groups[g].items.length) {
        g++;
        if (g >= widget.groups.length) break;
        i = _startIndex(g);
      }
      want(g, i);
    }
    if (_group > 0) want(_group - 1, _startIndex(_group - 1));
    if (_group + 1 < widget.groups.length) {
      want(_group + 1, _startIndex(_group + 1));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pool?.retainOnly(_wantedNow());
      for (final p in precache) {
        unawaited(precacheImage(p, context, onError: (_, __) {}));
      }
    });
  }

  Set<String> _wantedNow() {
    final keys = <String>{};
    void add(int g, int i) {
      if (g < 0 || g >= widget.groups.length) return;
      final items = widget.groups[g].items;
      if (i < 0 || i >= items.length) return;
      if (items[i].type == StoryMediaType.video) {
        keys.add(_key(widget.groups[g], items[i]));
      }
    }

    add(_group, _item);
    var g = _group;
    var i = _item;
    for (var k = 0; k < widget.preloadItems; k++) {
      i++;
      if (i >= widget.groups[g].items.length) {
        g++;
        if (g >= widget.groups.length) break;
        i = _startIndex(g);
      }
      add(g, i);
    }
    if (_group > 0) add(_group - 1, _startIndex(_group - 1));
    if (_group + 1 < widget.groups.length) {
      add(_group + 1, _startIndex(_group + 1));
    }
    return keys;
  }

  String _key(StoryGroup g, StoryItem i) => '${g.id}/${i.id}';

  // ----------------------------------------------------------- lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setReason(StoryPauseReason.lifecycle, state != AppLifecycleState.resumed);
  }

  // ------------------------------------------------------------- pointer

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return;
    }
    _pointer = e.pointer;
    _downPosition = e.position;
    _moved = false;
    _held = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(widget.holdDelay, () {
      _held = true;
      _setReason(StoryPauseReason.hold, true);
    });
    if (widget.enableKeyboard && !_isTyping()) _focus.requestFocus();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _moved) return;
    if ((e.position - _downPosition).distance > kTouchSlop) {
      _moved = true;
      _holdTimer?.cancel();
    }
  }

  void _onPointerUp(PointerUpEvent e, double width) {
    if (e.pointer != _pointer) return;
    final wasHeld = _held;
    final wasMoved = _moved;
    _endPointer();
    if (!wasHeld && !wasMoved) {
      final leading = widget.tapZoneLeftFraction * width;
      final x = _isRtl ? width - e.localPosition.dx : e.localPosition.dx;
      if (x < leading) {
        previous();
      } else {
        next();
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _endPointer();
  }

  void _endPointer() {
    _holdTimer?.cancel();
    _pointer = null;
    if (_held) {
      _held = false;
      _setReason(StoryPauseReason.hold, false);
    }
  }

  // --------------------------------------------------------- vertical drag

  void _onSettleStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && _dismissing) {
      widget.onDismiss?.call();
    }
  }

  void _animateDrag(double to) {
    _settleFrom = _dragDy.value;
    _settleTo = to;
    _settle.forward(from: 0);
  }

  void _onDragStart(DragStartDetails d) {
    if (_dismissing) return;
    _settle.stop();
    _setReason(StoryPauseReason.drag, true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    var dy = _dragDy.value + d.delta.dy;
    if (dy < 0 && widget.onSwipeUp == null) dy = 0;
    if (dy > 0 && !widget.dismissOnSwipeDown) dy = 0;
    _dragDy.value = dy.clamp(-200.0, double.infinity);
  }

  void _onDragEnd(DragEndDetails d, double height) {
    if (_dismissing) return;
    final dy = _dragDy.value;
    final v = d.primaryVelocity ?? 0;
    if (widget.dismissOnSwipeDown && dy > 0 && (dy > height * 0.2 || v > 900)) {
      _dismissing = true;
      _animateDrag(height);
      return;
    }
    if (widget.onSwipeUp != null && dy < 0 && (dy < -60 || v < -900)) {
      widget.onSwipeUp!(_currentGroup, _currentItem);
    }
    _animateDrag(0);
    _setReason(StoryPauseReason.drag, false);
  }

  void _onDragCancel() {
    if (_dismissing) return;
    _animateDrag(0);
    _setReason(StoryPauseReason.drag, false);
  }

  // ------------------------------------------------------------ keyboard

  bool _isTyping() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!widget.enableKeyboard || e is! KeyDownEvent || _isTyping()) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight) {
      next();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      previous();
    } else if (k == LogicalKeyboardKey.pageDown) {
      nextGroup();
    } else if (k == LogicalKeyboardKey.pageUp) {
      previousGroup();
    } else if (k == LogicalKeyboardKey.space) {
      _controller.isPaused ? _controller.resume() : _controller.pause();
    } else if (k == LogicalKeyboardKey.escape) {
      widget.onDismiss?.call();
    } else if (k == LogicalKeyboardKey.arrowUp && widget.onSwipeUp != null) {
      widget.onSwipeUp!(_currentGroup, _currentItem);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------- build

  bool get _arrows =>
      widget.showNavigationArrows ??
      (kIsWeb ||
          const {
            TargetPlatform.macOS,
            TargetPlatform.windows,
            TargetPlatform.linux
          }.contains(defaultTargetPlatform));

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final pageView = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pages,
          physics: widget.enableSwipeBetweenGroups
              ? const PageScrollPhysics(parent: ClampingScrollPhysics())
              : const NeverScrollableScrollPhysics(),
          itemCount: widget.groups.length,
          itemBuilder: _buildPage,
        ),
      ),
    );

    Widget card = MouseRegion(
      key: _cardKey,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          pageView,
          if (_arrows && _hovering) ..._arrowButtons(theme),
        ],
      ),
    );
    if (widget.aspectRatio != null) {
      card = Center(
        child: AspectRatio(
          aspectRatio: widget.aspectRatio!,
          child: ClipRRect(borderRadius: theme.cardBorderRadius, child: card),
        ),
      );
    } else if (theme.cardBorderRadius != BorderRadius.zero) {
      card = ClipRRect(borderRadius: theme.cardBorderRadius, child: card);
    }

    return Focus(
      focusNode: _focus,
      autofocus: widget.enableKeyboard,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, c) {
        final height = c.maxHeight.isFinite ? c.maxHeight : 800.0;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: (d) => _onDragEnd(d, height),
          onVerticalDragCancel: _onDragCancel,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragDy,
            child: card,
            builder: (context, dy, child) {
              final down = dy.clamp(0.0, height);
              final t = down / height;
              return ColoredBox(
                color: theme.backdropColor.withValues(alpha: 1 - t),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(0, down, 0).multiplied(
                      Matrix4.diagonal3Values(1 - 0.12 * t, 1 - 0.12 * t, 1)),
                  child: child,
                ),
              );
            },
          ),
        );
      }),
    );
  }

  List<Widget> _arrowButtons(StoryDeckTheme theme) {
    Widget arrow(bool left) => Positioned(
          left: left ? 8 : null,
          right: left ? null : 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: left ? previous : next,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x66000000)),
                child: CustomPaint(
                    painter: _ChevronPainter(theme.iconColor, left)),
              ),
            ),
          ),
        );
    return [arrow(true), arrow(false)];
  }

  Widget _buildPage(BuildContext context, int index) {
    final group = widget.groups[index];
    final active = index == _group;
    final itemIndex = active ? _item : _startIndex(index);
    final item = group.items[itemIndex];
    final theme = widget.theme;
    final progress = active ? _model.progress : _zero;
    final data = StoryOverlayData(
      group: group,
      item: item,
      groupIndex: index,
      itemIndex: itemIndex,
      controller: _controller,
      progress: progress,
      isActive: active,
    );

    final media = KeyedSubtree(
      key: ValueKey<String>(_key(group, item)),
      child: _buildMedia(context, group, item, active),
    );

    final header = widget.headerBuilder?.call(context, data) ??
        (widget.showHeader
            ? StoryHeader(data: data, theme: theme, onClose: widget.onDismiss)
            : null);
    final footer = widget.footerBuilder?.call(context, data) ??
        (item.caption == null ? null : _defaultCaption(item.caption!));
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.viewInsets.bottom, mq.padding.bottom);

    final page = LayoutBuilder(builder: (context, c) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: theme.backgroundColor),
          media,
          if (active)
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: (e) => _onPointerUp(e, c.maxWidth),
                onPointerCancel: _onPointerCancel,
                child: const SizedBox.expand(),
              ),
            ),
          if (theme.topScrim != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 160,
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(gradient: theme.topScrim))),
            ),
          if (theme.bottomScrim != null && footer != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 220,
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(gradient: theme.bottomScrim))),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: theme.progressPadding,
                    child: IgnorePointer(
                      child: widget.progressBuilder?.call(context,
                              group.items.length, itemIndex, progress) ??
                          StoryProgressBars(
                            count: group.items.length,
                            currentIndex: itemIndex,
                            progress: progress,
                            theme: theme,
                          ),
                    ),
                  ),
                  if (header != null) header,
                ],
              ),
            ),
          ),
          if (footer != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: footer,
              ),
            ),
          if (active &&
              widget.onSwipeUp != null &&
              widget.swipeUpBuilder != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 8,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _dragDy,
                  builder: (context, dy, child) => Opacity(
                    opacity: (-dy / 80).clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: widget.swipeUpBuilder!(context, data),
                ),
              ),
            ),
        ],
      );
    });

    return AnimatedBuilder(
      animation: _pages,
      child: page,
      builder: (context, child) {
        var offset = 0.0;
        if (_pages.hasClients &&
            _pages.position.hasPixels &&
            _pages.position.hasContentDimensions) {
          offset = index - (_pages.page ?? index.toDouble());
        } else {
          offset = (index - _group).toDouble();
        }
        return widget.transition.builder(context, child!, offset);
      },
    );
  }

  Widget _defaultCaption(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: IgnorePointer(
          child: Text(text, style: widget.theme.captionStyle),
        ),
      );

  Widget _buildMedia(
      BuildContext context, StoryGroup group, StoryItem item, bool active) {
    final StoryPlayback playback =
        active ? _playback : const InactiveStoryPlayback();
    final custom = widget.mediaBuilder?.call(context, item, playback);
    if (custom != null) return custom;
    switch (item.type) {
      case StoryMediaType.image:
        return StoryImageLayer(
          item: item,
          playback: playback,
          theme: widget.theme,
          errorBuilder: widget.errorBuilder,
          loadingBuilder: widget.loadingBuilder,
        );
      case StoryMediaType.video:
        final pool = _pool;
        if (pool == null) {
          if (active) {
            final err = StateError(
                'StoryDeck.videoAdapterFactory is required for video items');
            scheduleMicrotask(() => playback.fail(err));
          }
          return widget.errorBuilder
                  ?.call(context, 'No videoAdapterFactory was provided') ??
              StoryDefaultError(color: widget.theme.iconColor);
        }
        return StoryVideoLayer(
          item: item,
          entry: pool.acquire(_key(group, item), item),
          playback: playback,
          isActive: active,
          theme: widget.theme,
          bufferingBuilder: widget.bufferingBuilder,
          errorBuilder: widget.errorBuilder,
        );
      case StoryMediaType.custom:
        return item.builder!(context, playback);
    }
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color, this.left);
  final Color color;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = size.center(Offset.zero);
    final s = left ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(c.dx - 3 * s, c.dy - 7)
      ..lineTo(c.dx + 4 * s, c.dy)
      ..lineTo(c.dx - 3 * s, c.dy + 7);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.left != left;
}
