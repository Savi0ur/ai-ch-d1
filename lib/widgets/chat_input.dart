import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isStreaming,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isDesktop =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  void _handleSubmit() {
    if (widget.controller.text.trim().isNotEmpty && !widget.isStreaming) {
      widget.onSend();
    }
  }

  void _insertNewline() {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    final newText = text.replaceRange(
      sel.isValid ? sel.start : text.length,
      sel.isValid ? sel.end : text.length,
      '\n',
    );
    final offset = (sel.isValid ? sel.start : text.length) + 1;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (!_isDesktop) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;

    final isModified = HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (isModified) {
      _insertNewline();
    } else {
      _handleSubmit();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _onKeyEvent,
                child: TextField(
                  controller: widget.controller,
                  maxLines: 5,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isStreaming)
              IconButton.filled(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop',
              )
            else
              IconButton.filled(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.send),
                tooltip: 'Send',
              ),
          ],
        ),
      ),
    );
  }
}
