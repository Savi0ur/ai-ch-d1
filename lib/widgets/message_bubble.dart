import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onBranch;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onBranch,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final isAutoTrigger = widget.message.isAutoTrigger;
    final colors = Theme.of(context).colorScheme;
    final showBranchButton = widget.onBranch != null && _hovered && !widget.isStreaming;

    // Авто-триггер фазы — компактный системный маркер по центру
    if (isAutoTrigger) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            Expanded(child: Divider(color: colors.outlineVariant, height: 1)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 12, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              widget.message.content,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: colors.outlineVariant, height: 1)),
          ],
        ),
      );
    }

    // Контент сообщения
    final Widget contentWidget;
    if (widget.isStreaming) {
      contentWidget = ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message.content,
              style: TextStyle(color: colors.onSurface),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      );
    } else if (isUser) {
      contentWidget = SelectableText(
        widget.message.content,
        style: TextStyle(color: colors.onPrimary),
      );
    } else {
      // Markdown для assistant-сообщений
      contentWidget = MarkdownBody(
        data: widget.message.content,
        selectable: true,
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: colors.onSurface, fontSize: 14),
          a: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
          h1: TextStyle(color: colors.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
          h2: TextStyle(color: colors.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          h3: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
          strong: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
          em: TextStyle(color: colors.onSurface, fontStyle: FontStyle.italic),
          code: TextStyle(
            color: colors.onSurfaceVariant,
            backgroundColor: colors.surfaceContainerHigh,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          codeblockDecoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.outline, width: 3)),
          ),
          listBullet: TextStyle(color: colors.onSurface),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: isUser ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: contentWidget,
            ),
            if (showBranchButton)
              Positioned(
                top: 0,
                right: isUser ? null : 4,
                left: isUser ? 4 : null,
                child: Material(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onBranch,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.call_split,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
