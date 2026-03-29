import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../core/theme/app_theme.dart';

class TextLikeMessageContent extends StatelessWidget {
  final MessageRow message;
  final TextAlign textAlign;
  final MessageRow? repliedMessage;

  const TextLikeMessageContent({
    super.key,
    required this.message,
    required this.textAlign,
    this.repliedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final contentAlignment = textAlign == TextAlign.right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    if (message.type == 'call_summary') {
      final metadata = message.metadataJson == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(message.metadataJson!) as Map);
      final icon = metadata['callType'] == 'video'
          ? Icons.videocam
          : Icons.call;

      return Column(
        crossAxisAlignment: contentAlignment,
        children: [
          if (repliedMessage != null) ...[
            ReplyPreview(message: repliedMessage!, textAlign: textAlign),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.positive, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.textBody ?? 'Call',
                  textAlign: textAlign,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final text = message.textBody ?? '';
    if (isEmojiOnly(text)) {
      return Column(
        crossAxisAlignment: contentAlignment,
        children: [
          if (repliedMessage != null) ...[
            ReplyPreview(message: repliedMessage!, textAlign: textAlign),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: textAlign,
            style: const TextStyle(fontSize: 44, height: 1.0),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: contentAlignment,
      children: [
        if (repliedMessage != null) ...[
          ReplyPreview(message: repliedMessage!, textAlign: textAlign),
          const SizedBox(height: 8),
        ],
        Linkify(
          text: text,
          textAlign: textAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            height: 1.45,
          ),
          linkStyle: TextStyle(
            color: palette.brand,
            decoration: TextDecoration.underline,
            fontSize: 15.5,
          ),
          onOpen: (link) async {
            final uri = Uri.tryParse(link.url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

class ReplyPreview extends StatelessWidget {
  final MessageRow message;
  final TextAlign textAlign;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final alignment = textAlign == TextAlign.right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: palette.brand.withValues(alpha: 0.85),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                color: palette.brand,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Replying to',
                style: TextStyle(
                  color: palette.brand,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _previewText(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  static String _previewText(MessageRow message) {
    final text = message.textBody?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    switch (message.type) {
      case 'file':
        return 'Attachment';
      case 'call_summary':
        return 'Call summary';
      case 'system':
        return 'System message';
      default:
        return message.type;
    }
  }
}
