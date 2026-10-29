import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../state/story_controller.dart';

/// Default reply bar: a rounded text field with a send button.
///
/// While the field has focus the story is paused through
/// [StoryController.pause] and resumed when it loses focus.
class StoryReplyBar extends StatefulWidget {
  /// Creates a reply bar.
  const StoryReplyBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Send message',
    this.color = const Color(0xFFFFFFFF),
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
  });

  /// The deck controller to pause while typing.
  final StoryController controller;

  /// Called with the text when the user submits.
  final ValueChanged<String> onSend;

  /// Placeholder text.
  final String hintText;

  /// Color of the text, hint and border.
  final Color color;

  /// Outer padding.
  final EdgeInsets padding;

  @override
  State<StoryReplyBar> createState() => _StoryReplyBarState();
}

class _StoryReplyBarState extends State<StoryReplyBar> {
  final FocusNode _focus = FocusNode();
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.controller.pause();
    } else {
      widget.controller.resume();
    }
  }

  void _submit([String? _]) {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    widget.onSend(value);
    _text.clear();
    _focus.unfocus();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_focus.hasFocus) widget.controller.resume();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: widget.color, fontSize: 15);
    return Padding(
      padding: widget.padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: widget.color.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  ListenableBuilder(
                    listenable: _text,
                    builder: (context, _) => _text.text.isEmpty
                        ? IgnorePointer(
                            child: Text(widget.hintText,
                                style: style.copyWith(
                                    color:
                                        widget.color.withValues(alpha: 0.8))),
                          )
                        : const SizedBox.shrink(),
                  ),
                  EditableText(
                    controller: _text,
                    focusNode: _focus,
                    style: style,
                    cursorColor: widget.color,
                    backgroundCursorColor: const Color(0xFF888888),
                    onSubmitted: _submit,
                    textInputAction: TextInputAction.send,
                    selectionColor: widget.color.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: _text,
              builder: (context, _) => _text.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: _submit,
                      child: Text('Send',
                          style: style.copyWith(fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
