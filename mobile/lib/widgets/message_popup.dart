import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../providers/messages_provider.dart';

class MessagePopup extends StatelessWidget {
  final Message message;
  final VoidCallback? onRefresh;

  const MessagePopup({super.key, required this.message, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: GeoNoteTheme.primary.withOpacity(0.15),
                  child: Text(
                    message.username.isNotEmpty
                        ? message.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GeoNoteTheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${message.username}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          if (message.distanceMeters != null) ...[
                            Text(' · ', style: TextStyle(color: Colors.grey[400])),
                            Icon(Icons.place, size: 12, color: Colors.grey[400]),
                            Text(
                              message.distanceFormatted,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            Text(
              message.content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            // Hashtags
            if (message.hashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: message.hashtags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: GeoNoteTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 13,
                        color: GeoNoteTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            // Actions bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PopupAction(
                    icon: Icons.favorite_border,
                    label: '${message.likesCount} Like${message.likesCount != 1 ? 's' : ''}',
                    color: Colors.red[400]!,
                    onTap: () async {
                      await context.read<MessagesProvider>().toggleLike(message.id);
                      onRefresh?.call();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  _PopupAction(
                    icon: Icons.chat_bubble_outline,
                    label: '${message.commentsCount} Comment${message.commentsCount != 1 ? 's' : ''}',
                    color: Colors.blue[400]!,
                    onTap: () {},
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  _PopupAction(
                    icon: Icons.share_outlined,
                    label: 'Partager',
                    color: Colors.grey[600]!,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd MMM yyyy', 'fr').format(date);
  }
}

class _PopupAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PopupAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
