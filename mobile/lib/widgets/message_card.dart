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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.12)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: avatar + username + time
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: GeoNoteTheme.primary.withOpacity(0.15),
                      child: Text(
                        message.username.isNotEmpty
                            ? message.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GeoNoteTheme.primary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${message.username}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.place, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 2),
                              if (message.distanceMeters != null)
                                Text(
                                  message.distanceFormatted,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                ),
                              if (message.distanceMeters != null)
                                Text(' · ', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                              Text(
                                _timeAgo(message.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _VisibilityBadge(visibility: message.visibility),
                  ],
                ),
                const SizedBox(height: 12),
                // Content
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
                // Hashtags
                if (message.hashtags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: message.hashtags.map((tag) {
                      return Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 13,
                          color: GeoNoteTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.favorite_border,
                      activeIcon: Icons.favorite,
                      label: '${message.likesCount}',
                      color: Colors.red[400]!,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 20),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '${message.commentsCount}',
                      color: Colors.grey[600]!,
                      onTap: onTap,
                    ),
                    const Spacer(),
                    if (showDelete && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'a l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return DateFormat('dd/MM').format(date);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final String visibility;
  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (visibility) {
      'public' => (Icons.public, const Color(0xFF4CAF50)),
      'friends' => (Icons.group, const Color(0xFF2196F3)),
      _ => (Icons.lock, const Color(0xFF9E9E9E)),
    };

    return Icon(icon, size: 16, color: color.withOpacity(0.6));
  }
}
