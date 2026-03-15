import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final void Function(String hashtag)? onHashtagTap;
  final bool showDelete;

  const MessageCard({
    super.key,
    required this.message,
    this.onTap,
    this.onLike,
    this.onDelete,
    this.onHashtagTap,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : theme.cardColor;
    final subtleText = isDark ? Colors.grey[500]! : Colors.grey[500]!;
    final actionBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey[50]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        elevation: isDark ? 0 : 2,
        shadowColor: isDark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  )
                : null,
          ),
          child: Semantics(
            label:
                'Message de ${message.username}, ${message.content.substring(0, message.content.length.clamp(0, 50))}',
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Header --
                    Row(
                      children: [
                        _GradientAvatar(
                          name: message.username,
                          radius: 22,
                          messageType: message.messageType,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      message.username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: theme
                                            .colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (message.isMystery ||
                                      message.isCapsule ||
                                      message.isEphemeral) ...[
                                    const SizedBox(width: 8),
                                    _TypeBadgeChip(message: message),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (message.distanceMeters !=
                                      null) ...[
                                    Icon(Icons.near_me,
                                        size: 11, color: subtleText),
                                    const SizedBox(width: 2),
                                    Text(
                                      message.distanceFormatted,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: subtleText),
                                    ),
                                    Text(
                                      ' \u00B7 ',
                                      style: TextStyle(
                                          color: subtleText,
                                          fontSize: 11),
                                    ),
                                  ],
                                  Icon(Icons.schedule,
                                      size: 11, color: subtleText),
                                  const SizedBox(width: 2),
                                  Text(
                                    _timeAgo(message.createdAt),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: subtleText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _VisibilityIcon(
                          visibility: message.visibility,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // -- Content --
                    if (message.isLocked)
                      _MysteryLockedContainer(
                        isDark: isDark,
                        mysteryRadius: message.mysteryRadius,
                      )
                    else if (message.isCapsulePending)
                      _CapsulePendingContainer(
                        countdown: message.capsuleCountdown,
                        isDark: isDark,
                      )
                    else
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                    // -- Hashtags --
                    if (message.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.hashtags
                            .map(
                              (tag) => GestureDetector(
                                onTap: () =>
                                    onHashtagTap?.call(tag),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GeoNoteTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GeoNoteTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // -- Reactions display --
                    if (message.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: message.reactions.map((r) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: r.reacted
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.1)
                                    : actionBg,
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: r.reacted
                                    ? Border.all(
                                        color: theme
                                            .colorScheme.primary
                                            .withValues(alpha: 0.25),
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.emoji,
                                      style: const TextStyle(
                                          fontSize: 13)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${r.count}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: r.reacted
                                          ? theme.colorScheme.primary
                                          : subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // -- Action bar --
                    Row(
                      children: [
                        // Comments
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble_outline,
                          count: message.commentsCount,
                          color: Colors.blue,
                          bgColor: actionBg,
                          onTap: onTap,
                        ),
                        const Spacer(),
                        // Delete (discreet icon)
                        if (showDelete && onDelete != null)
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: onDelete,
                              borderRadius:
                                  BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: subtleText,
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

// ---- Gradient ring avatar (Instagram stories style) ----

class _GradientAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String messageType;

  const _GradientAvatar({
    required this.name,
    required this.radius,
    required this.messageType,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = switch (messageType) {
      'mystery' => [Colors.deepPurple, Colors.purpleAccent, Colors.deepPurpleAccent],
      'capsule' => [Colors.purple, Colors.pinkAccent, Colors.deepPurple],
      _ => [GeoNoteTheme.primary, const Color(0xFFFF9800), const Color(0xFFFF5722)],
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        child: CircleAvatar(
          radius: radius - 4.5,
          backgroundColor: gradientColors[0].withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: gradientColors[0],
              fontSize: (radius - 4.5) * 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Type badge chip next to username ----

class _TypeBadgeChip extends StatelessWidget {
  final Message message;
  const _TypeBadgeChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = message.isMystery
        ? (
            message.isLocked ? 'Mystere' : 'Mystere',
            Colors.deepPurple,
            Icons.help_outline,
          )
        : message.isCapsule
            ? (
                message.isCapsulePending
                    ? message.capsuleCountdown
                    : 'Capsule',
                Colors.purple,
                Icons.schedule,
              )
            : (
                message.timeRemaining,
                Colors.orange,
                Icons.timer,
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Mystery locked container (glassmorphic purple) ----

class _MysteryLockedContainer extends StatelessWidget {
  final bool isDark;
  final int mysteryRadius;
  const _MysteryLockedContainer({required this.isDark, required this.mysteryRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withValues(alpha: isDark ? 0.25 : 0.08),
            Colors.purpleAccent.withValues(alpha: isDark ? 0.15 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 18, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approchez-vous pour lire',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple[isDark ? 200 : 700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A moins de ${mysteryRadius}m de ce lieu',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.deepPurple[isDark ? 300 : 400],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Capsule pending container ----

class _CapsulePendingContainer extends StatelessWidget {
  final String countdown;
  final bool isDark;
  const _CapsulePendingContainer({required this.countdown, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withValues(alpha: isDark ? 0.25 : 0.08),
            Colors.pinkAccent.withValues(alpha: isDark ? 0.12 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule_rounded, size: 18, color: Colors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capsule temporelle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[isDark ? 200 : 700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ouverture dans $countdown',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple[isDark ? 300 : 400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Action button (like / comment) ----

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Visibility icon ----

class _VisibilityIcon extends StatelessWidget {
  final String visibility;
  final bool isDark;
  const _VisibilityIcon({required this.visibility, required this.isDark});

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
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}
