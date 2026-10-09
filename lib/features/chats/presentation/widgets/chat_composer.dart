import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.onSend,
    required this.onTyping,
    this.isReadOnly = false,
    super.key,
  });

  final Future<void> Function(String text) onSend;
  final VoidCallback onTyping;
  final bool isReadOnly;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _canSend = false;
  int _charCount = 0;
  bool _isSending = false;

  static const int _maxChars = 2000;
  static const int _warningThreshold = 1800;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final trimmed = text.trim();
    final canSendNow = trimmed.isNotEmpty && trimmed.length <= _maxChars && !_isSending;

    if (canSendNow != _canSend || _charCount != text.length) {
      setState(() {
        _canSend = canSendNow;
        _charCount = text.length;
      });
    }

    if (trimmed.isNotEmpty) {
      widget.onTyping();
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > _maxChars || _isSending || widget.isReadOnly) {
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    setState(() => _isSending = true);

    _controller.clear();
    setState(() {
      _canSend = false;
      _charCount = 0;
    });

    try {
      await widget.onSend(text);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (widget.isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'This past trip chat is now in read-only mode',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(160),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Solid surface (no glass on composer)
    const composerBg = Color(0xFFFFFFFF); // Solid white light
    final borderColor = theme.colorScheme.outline.withAlpha(40);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Character count warning indicator
            if (_charCount >= _warningThreshold) ...[
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$_charCount / $_maxChars',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _charCount > _maxChars
                          ? theme.colorScheme.error
                          : Colors.orange,
                    ),
                  ),
                ),
              ),
            ],

            // Input bar with multiline field and 48dp send button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text Field Container (24px radius, 1 to 5 lines)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: composerBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? theme.colorScheme.primary.withAlpha(150)
                            : borderColor,
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        // Desktop & Web: Enter sends, Shift+Enter inserts new line
                        if (kIsWeb ||
                            defaultTargetPlatform == TargetPlatform.macOS ||
                            defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.linux) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            unawaited(_handleSend());
                          }
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: kIsWeb
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        onSubmitted: (_) {
                          if (kIsWeb) unawaited(_handleSend());
                        },
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message group...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 48dp Send Button with scale animation
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: AnimatedScale(
                      scale: _canSend ? 1.0 : 0.88,
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _canSend ? 1.0 : 0.35,
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        child: Material(
                          color: theme.colorScheme.primary,
                          shape: const CircleBorder(),
                          elevation: _canSend ? 2 : 0,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _canSend ? _handleSend : null,
                            child: Center(
                              child: _isSending
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_upward_rounded,
                                      color: theme.colorScheme.onPrimary,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
