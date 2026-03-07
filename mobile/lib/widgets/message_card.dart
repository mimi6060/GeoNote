import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final bool showDelete;

  const MessageCard({
    super.key,
    required this.message,
    this.onTap,
    this.onLike,
    this.onDelete,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: GeoNoteTheme.primary.withOpacity(0.12),
                        child: Text(
                          message.username.isNotEmpty ? message.username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: GeoNoteTheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${message.username}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                if (message.distanceMeters != null) ...[
                                  Icon(Icons.near_me, size: 11, color: Colors.grey[400]),
                                  const SizedBox(width: 2),
                                  Text(message.distanceFormatted,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                  Text(' · ', style: TextStyle(color: Colors.grey[300], fontSize: 11)),
                                ],
                                Icon(Icons.schedule, size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 2),
                                Text(_timeAgo(message.createdAt),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _VisibilityIcon(visibility: message.visibility),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Content ──
                  Text(message.content,
                      style: const TextStyle(fontSize: 15, height: 1.45)),

                  // ── Hashtags ──
                  if (message.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: message.hashtags.map((tag) => Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 13,
                          color: GeoNoteTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── Action bar ──
                  Row(
                    children: [
                      // Like
                      Material(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onLike,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border, size: 18, color: Colors.red[300]),
                                const SizedBox(width: 5),
                                Text('${message.likesCount}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Comment
                      Material(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 17, color: Colors.blue[300]),
                                const SizedBox(width: 5),
                                Text('${message.commentsCount}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (showDelete && onDelete != null)
                        Material(
                          color: Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline, size: 17, color: Colors.red[400]),
                                  const SizedBox(width: 4),
                                  Text('Supprimer',
                                      style: TextStyle(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return DateFormat('dd/MM').format(date);
  }
}

class _VisibilityIcon extends StatelessWidget {
  final String visibility;
  const _VisibilityIcon({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (visibility) {
      'public' => (Icons.public, const Color(0xFF4CAF50)),
      'friends' => (Icons.group, const Color(0xFF2196F3)),
      _ => (Icons.lock, const Color(0xFF9E9E9E)),
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}
