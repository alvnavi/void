import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class EditorView extends StatelessWidget {
  final TextEditingController controller;
  final bool isEditing;
  final String transientText;
  final Function(String)? onNoteLinkTapped;

  const EditorView({
    Key? key,
    required this.controller,
    required this.isEditing,
    this.transientText = '',
    this.onNoteLinkTapped,
  }) : super(key: key);

  String _preprocessLinks(String text) {
    // Convert [[Title]] to [Title](void-link://open?title=Title)
    final wikiLinkRegex = RegExp(r'\[\[(.*?)\]\]');
    return text.replaceAllMapped(wikiLinkRegex, (match) {
      final title = match.group(1);
      return '[$title](void-link://open?title=${Uri.encodeComponent(title!)})';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
                fontFamily: 'JetBrains Mono',
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing...',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ),
          if (transientText.isNotEmpty)
            _buildTransientText(),
        ],
      );
    } else {
      String displayContent = controller.text;
      if (displayContent.isEmpty && transientText.isEmpty) {
        return const Center(child: Text('VOID', style: TextStyle(color: Colors.white10, letterSpacing: 10)));
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: _preprocessLinks(displayContent),
              onTapLink: (text, href, title) {
                if (href != null && href.startsWith('void-link://open')) {
                  final uri = Uri.parse(href);
                  final targetTitle = uri.queryParameters['title'];
                  if (targetTitle != null && onNoteLinkTapped != null) {
                    onNoteLinkTapped!(targetTitle);
                  }
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                h1: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold),
                listBullet: const TextStyle(color: Colors.redAccent),
                blockquote: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                code: const TextStyle(backgroundColor: Colors.white12, fontFamily: 'JetBrains Mono'),
                a: const TextStyle(color: Colors.redAccent, decoration: TextDecoration.underline),
              ),
            ),
            if (transientText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildTransientText(),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildTransientText() {
    return _BlinkingText(text: transientText);
  }
}

class _BlinkingText extends StatefulWidget {
  final String text;
  const _BlinkingText({Key? key, required this.text}) : super(key: key);

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        // Linear interpolation between white and a medium-light grey
        final Color color = Color.lerp(Colors.white, Colors.white38, _blinkController.value)!;
        return Opacity(
          opacity: 0.5 + (_blinkController.value * 0.5), // v8.7 pulsing
          child: Text(
            widget.text,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        );
      },
    );
  }
}
