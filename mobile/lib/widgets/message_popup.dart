import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MessagePopup extends StatefulWidget {
  final Message message;
  final VoidCallback? onRefresh;

  const MessagePopup({super.key, required this.message, this.onRefresh});

  @override
  State<MessagePopup> createState() => _MessagePopupState();
}

class _MessagePopupState extends State<MessagePopup>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _sendingComment = false;
  bool _showComments = false;
  bool _unlocking = false;
  String? _unlockedContent;

  // Reactions state
  static const List<String> _availableEmojis = [
    '\u2764\uFE0F', // heart
    '\u{1F602}', // joy
    '\u{1F62E}', // open mouth
    '\u{1F622}', // cry
    '\u{1F525}', // fire
    '\u{1F44F}', // clap
  ];
  List<ReactionSummary> _reactions = [];
  String? _animatingEmoji;

  late AnimationController _reactionAnimController;
  late Animation<double> _reactionScaleAnim;

  @override
  void initState() {
    super.initState();
    _reactions = List.from(widget.message.reactions);
    _loadComments();
    _reactionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _reactionScaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _reactionAnimController, curve: Curves.easeOut),
    );
    _reactionAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _reactionAnimController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reactionAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _api.getComments(widget.message.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    HapticFeedback.lightImpact();
    setState(() => _animatingEmoji = emoji);
    _reactionAnimController.forward();

    // Optimistic update
    final oldReactions = List<ReactionSummary>.from(_reactions);
    setState(() {
      final idx = _reactions.indexWhere((r) => r.emoji == emoji);
      if (idx >= 0) {
        final existing = _reactions[idx];
        if (existing.reacted) {
          if (existing.count <= 1) {
            _reactions.removeAt(idx);
          } else {
            _reactions[idx] = ReactionSummary(
              emoji: emoji,
              count: existing.count - 1,
              reacted: false,
            );
          }
        } else {
          _reactions[idx] = ReactionSummary(
            emoji: emoji,
            count: existing.count + 1,
            reacted: true,
          );
        }
      } else {
        _reactions.add(ReactionSummary(
          emoji: emoji,
          count: 1,
          reacted: true,
        ));
      }
    });

    try {
      final result = await _api.toggleReaction(widget.message.id, emoji);
      if (mounted) {
        final reactionsData = result['reactions'] as List<dynamic>? ?? [];
        setState(() {
          _reactions = reactionsData
              .map((e) =>
                  ReactionSummary.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
      widget.onRefresh?.call();
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() => _reactions = oldReactions);
      }
    } finally {
      if (mounted) {
        setState(() => _animatingEmoji = null);
      }
    }
  }

  Future<void> _unlockMystery() async {
    setState(() => _unlocking = true);
    try {
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Position GPS requise')),
          );
        }
        return;
      }
      final result = await _api.unlockMystery(
        widget.message.id,
        location.latitude,
        location.longitude,
      );
      final unlocked = result['unlocked'] as bool? ?? false;
      if (unlocked && result['message'] != null) {
        final msg = result['message'] as Map<String, dynamic>;
        setState(() => _unlockedContent = msg['content'] as String?);
        widget.onRefresh?.call();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Trop loin ! Rapprochez-vous du message.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      await _api.addComment(widget.message.id, content);
      _commentController.clear();
      await _loadComments();
      widget.onRefresh?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi')),
        );
      }
    }
    if (mounted) setState(() => _sendingComment = false);
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _api.deleteComment(commentId);
      await _loadComments();
      widget.onRefresh?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur lors de la suppression')),
        );
      }
    }
  }

  void _showReportDialog() {
    final reasons = <String, String>{
      'spam': 'Spam',
      'harassment': 'Harcelement',
      'inappropriate': 'Contenu inapproprie',
      'misinformation': 'Desinformation',
      'other': 'Autre',
    };
    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.flag_rounded,
                      color: Colors.red[400], size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Signaler ce message',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quelle est la raison ?',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.entries.map((entry) {
                      final isSelected = selectedReason == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: isSelected
                              ? Colors.red.withValues(alpha: 0.08)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.grey[50]!),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => setDialogState(
                                () => selectedReason = entry.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.red
                                            .withValues(alpha: 0.3),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 20,
                                    color: isSelected
                                        ? Colors.red[400]
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color:
                                          theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      maxLength: 500,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Details supplementaires (optionnel)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _submitReport(
                            selectedReason!,
                            descriptionController.text.trim(),
                          );
                        },
                  child: Text(
                    'Signaler',
                    style: TextStyle(
                      color: selectedReason == null
                          ? theme.colorScheme.onSurface
                              .withValues(alpha: 0.2)
                          : Colors.red[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(String reason, String description) async {
    try {
      await _api.reportMessage(
        widget.message.id,
        reason,
        description: description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signalement enregistre, merci'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du signalement'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[50]!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Handle bar ---
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // --- Scrollable content ---
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Author row --
                  Row(
                    children: [
                      _GradientAvatar(
                        name: widget.message.username,
                        radius: 24,
                        messageType: widget.message.messageType,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.message.username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: theme
                                          .colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.message.isMystery ||
                                    widget.message.isCapsule ||
                                    widget.message.isEphemeral) ...[
                                  const SizedBox(width: 8),
                                  _TypeBadge(
                                      message: widget.message),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            _MetaRow(message: widget.message),
                          ],
                        ),
                      ),
                      _VisIcon(
                        visibility: widget.message.visibility,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // -- Content --
                  if (widget.message.isLocked &&
                      _unlockedContent == null)
                    _MysteryUnlockSection(
                      message: widget.message,
                      unlocking: _unlocking,
                      isLoggedIn: isLoggedIn,
                      isDark: isDark,
                      onUnlock: _unlockMystery,
                    )
                  else
                    Text(
                      _unlockedContent ?? widget.message.content,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.55,
                        letterSpacing: -0.1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                  // -- Hashtags --
                  if (widget.message.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.message.hashtags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: GeoNoteTheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: GeoNoteTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // -- Reactions bar --
                  _ReactionsBar(
                    availableEmojis: _availableEmojis,
                    reactions: _reactions,
                    animatingEmoji: _animatingEmoji,
                    scaleAnim: _reactionScaleAnim,
                    isLoggedIn: isLoggedIn,
                    isDark: isDark,
                    onToggle: _toggleReaction,
                  ),

                  // -- Reaction counts display --
                  if (_reactions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ReactionCountsRow(
                      reactions: _reactions,
                      isDark: isDark,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // -- Action bar --
                  Row(
                    children: [
                      // Comments
                      _ActionPill(
                        icon: _showComments
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        label: '${_comments.length}',
                        color: _showComments
                            ? Colors.blue
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                        bgColor: _showComments
                            ? Colors.blue.withValues(alpha: 0.1)
                            : surfaceColor,
                        onTap: () => setState(
                            () => _showComments = !_showComments),
                      ),
                      const Spacer(),
                      // Report
                      if (isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ActionPill(
                            icon: Icons.flag_outlined,
                            label: '',
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            bgColor: surfaceColor,
                            onTap: _showReportDialog,
                          ),
                        ),
                      // Share
                      _ActionPill(
                        icon: Icons.ios_share_rounded,
                        label: '',
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                        bgColor: surfaceColor,
                        onTap: () {
                          final text =
                              '${widget.message.content}\n\nDecouvre cette note sur GeoNote !';
                          Share.share(text);
                        },
                      ),
                    ],
                  ),

                  // -- Comments section --
                  if (_showComments) ...[
                    const SizedBox(height: 18),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey[200],
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    // Comment list
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: GeoNoteTheme.primary,
                          ),
                        ),
                      )
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons
                                      .chat_bubble_outline_rounded,
                                  size: 28,
                                  color: theme
                                      .colorScheme.onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Soyez le premier a commenter !',
                                style: TextStyle(
                                  color: theme
                                      .colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._comments.map(
                        (c) => _CommentTile(
                          comment: c,
                          currentUserId: auth.user?.id,
                          onDelete: () =>
                              _deleteComment(c['id'] as String),
                          isDark: isDark,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // --- Comment input bar ---
          if (_showComments && isLoggedIn)
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                8,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.scaffoldBackgroundColor
                    : theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey[200]!,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    _SmallAvatar(
                      name: auth.user?.username ?? '?',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Ecrire un commentaire...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: surfaceColor,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: GeoNoteTheme.primary
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _sendingComment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GeoNoteTheme.primary,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  GeoNoteTheme.primary,
                                  Color(0xFFFF9800),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(20),
                              child: InkWell(
                                onTap: _addComment,
                                borderRadius:
                                    BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Sub-widgets ----

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Color> gradientColors = switch (messageType) {
      'mystery' => [
          Colors.deepPurple,
          Colors.purpleAccent,
          Colors.deepPurpleAccent,
        ],
      'capsule' => [
          Colors.purple,
          Colors.pinkAccent,
          Colors.deepPurple,
        ],
      _ => [
          GeoNoteTheme.primary,
          const Color(0xFFFF9800),
          const Color(0xFFFF5722),
        ],
    };

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
          color: isDark
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.white,
        ),
        child: CircleAvatar(
          radius: radius - 4.5,
          backgroundColor:
              gradientColors[0].withValues(alpha: 0.12),
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

class _SmallAvatar extends StatelessWidget {
  final String name;
  final bool isDark;
  const _SmallAvatar({required this.name, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey[200],
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final Message message;
  const _TypeBadge({required this.message});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = message.isMystery
        ? (
            'Mystere',
            Colors.deepPurple,
            Icons.help_outline_rounded,
          )
        : message.isCapsule
            ? (
                message.isCapsulePending
                    ? message.capsuleCountdown
                    : 'Capsule',
                Colors.purple,
                Icons.schedule_rounded,
              )
            : (
                message.timeRemaining,
                Colors.orange,
                Icons.timer_rounded,
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (message.isMystery) ...[
            const SizedBox(width: 6),
            Text(
              '${message.unlocksCount}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.deepPurple[300],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Message message;
  const _MetaRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.4);

    final diff = DateTime.now().difference(message.createdAt);
    String time;
    if (diff.inMinutes < 1) {
      time = 'maintenant';
    } else if (diff.inMinutes < 60) {
      time = '${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      time = '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      time = '${diff.inDays}j';
    } else {
      time = DateFormat('dd/MM').format(message.createdAt);
    }

    return Row(
      children: [
        Icon(Icons.schedule, size: 13, color: subtleColor),
        const SizedBox(width: 3),
        Text(time,
            style: TextStyle(fontSize: 12, color: subtleColor)),
        if (message.distanceMeters != null) ...[
          Text('  \u00B7  ',
              style: TextStyle(color: subtleColor, fontSize: 12)),
          Icon(Icons.near_me, size: 13, color: subtleColor),
          const SizedBox(width: 3),
          Text(message.distanceFormatted,
              style:
                  TextStyle(fontSize: 12, color: subtleColor)),
        ],
      ],
    );
  }
}

class _VisIcon extends StatelessWidget {
  final String visibility;
  final bool isDark;
  const _VisIcon({required this.visibility, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (visibility) {
      'public' => (
          Icons.public,
          const Color(0xFF4CAF50),
          'Public',
        ),
      'friends' => (
          Icons.group,
          const Color(0xFF2196F3),
          'Amis',
        ),
      _ => (
          Icons.lock,
          const Color(0xFF9E9E9E),
          'Prive',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MysteryUnlockSection extends StatelessWidget {
  final Message message;
  final bool unlocking;
  final bool isLoggedIn;
  final bool isDark;
  final VoidCallback onUnlock;

  const _MysteryUnlockSection({
    required this.message,
    required this.unlocking,
    required this.isLoggedIn,
    required this.isDark,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withValues(alpha: isDark ? 0.3 : 0.08),
            Colors.purpleAccent.withValues(alpha: isDark ? 0.15 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: isDark ? 0.35 : 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 32,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ce message est verrouille',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.deepPurple[isDark ? 200 : 700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Approchez-vous a moins de ${message.mysteryRadius}m pour le lire',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.deepPurple[isDark ? 300 : 400],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (isLoggedIn)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.deepPurple,
                      Colors.purpleAccent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ElevatedButton.icon(
                  onPressed: unlocking ? null : onUnlock,
                  icon: unlocking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded,
                          size: 18),
                  label: const Text('Tenter de deverrouiller'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: label.isEmpty ? 12 : 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionsBar extends StatelessWidget {
  final List<String> availableEmojis;
  final List<ReactionSummary> reactions;
  final String? animatingEmoji;
  final Animation<double> scaleAnim;
  final bool isLoggedIn;
  final bool isDark;
  final void Function(String emoji) onToggle;

  const _ReactionsBar({
    required this.availableEmojis,
    required this.reactions,
    required this.animatingEmoji,
    required this.scaleAnim,
    required this.isLoggedIn,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[50]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: availableEmojis.map((emoji) {
          final reactionIdx =
              reactions.indexWhere((r) => r.emoji == emoji);
          final isReacted =
              reactionIdx >= 0 && reactions[reactionIdx].reacted;
          final isAnimating = animatingEmoji == emoji;

          Widget emojiWidget = Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          );

          if (isAnimating) {
            emojiWidget = ScaleTransition(
              scale: scaleAnim,
              child: emojiWidget,
            );
          }

          return GestureDetector(
            onTap: isLoggedIn ? () => onToggle(emoji) : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isReacted
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isReacted
                    ? Border.all(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.3),
                        width: 1.5,
                      )
                    : null,
              ),
              child: emojiWidget,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionCountsRow extends StatelessWidget {
  final List<ReactionSummary> reactions;
  final bool isDark;

  const _ReactionCountsRow({
    required this.reactions,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: reactions.map((r) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: r.reacted
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey[100]!),
            borderRadius: BorderRadius.circular(16),
            border: r.reacted
                ? Border.all(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.25),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${r.count}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: r.reacted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final bool isDark;

  const _CommentTile({
    required this.comment,
    this.currentUserId,
    this.onDelete,
    required this.isDark,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = widget.comment['username'] as String? ?? '?';
    final content = widget.comment['content'] as String? ?? '';
    final userId = widget.comment['user_id'] as String? ?? '';
    final createdAt = DateTime.tryParse(
        widget.comment['created_at'] as String? ?? '');
    final isOwn = widget.currentUserId != null &&
        userId == widget.currentUserId;

    String time = '';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 1) {
        time = 'maintenant';
      } else if (diff.inMinutes < 60) {
        time = '${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        time = '${diff.inHours}h';
      } else if (diff.inDays < 7) {
        time = '${diff.inDays}j';
      } else {
        time = DateFormat('dd/MM').format(createdAt);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallAvatar(
            name: username,
            isDark: widget.isDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme
                                    .colorScheme.onSurface
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions under the bubble
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _liked = !_liked),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: _liked
                                  ? Colors.red
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'J\'aime',
                              style: TextStyle(
                                fontSize: 11,
                                color: _liked
                                    ? Colors.red
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                fontWeight: _liked
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwn &&
                          widget.onDelete != null) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 14,
                                color: theme
                                    .colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Supprimer',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme
                                      .colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
