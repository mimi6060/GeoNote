import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/message.dart';

class MessagePopup extends StatelessWidget {
  final Message message;

  const MessagePopup({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '@${message.username}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            message.content,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          // Hashtags
          if (message.hashtags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: message.hashtags.map((tag) {
                return Chip(
                  label: Text(
                    '#$tag',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GeoNoteTheme.primary,
                    ),
                  ),
                  backgroundColor: const Color(0xFFFFF0E8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              _ActionButton(
                icon: Icons.favorite_border,
                label: '${message.likesCount}',
                onTap: () {}, // TODO: toggle like
              ),
              const SizedBox(width: 24),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: '${message.commentsCount}',
                onTap: () {}, // TODO: open comments
              ),
              const Spacer(),
              if (message.distanceMeters != null)
                Text(
                  message.distanceFormatted,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
