import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MessagePopup extends StatefulWidget {
  final Message message;
  final VoidCallback? onRefresh;

  const MessagePopup({super.key, required this.message, this.onRefresh});

  @override
  State<MessagePopup> createState() => _MessagePopupState();
}

class _MessagePopupState extends State<MessagePopup> {
  final ApiService _api = ApiService();
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _liked = false;
  int _likesCount = 0;
  bool _sendingComment = false;
  bool _showComments = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.message.likesCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

  Future<void> _toggleLike() async {
    // Optimistic update
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });

    try {
      final result = await _api.toggleLikeRaw(widget.message.id);
      if (mounted) {
        setState(() {
          _liked = result['liked'] as bool;
          _likesCount = result['likes_count'] as int;
        });
      }
      widget.onRefresh?.call();
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likesCount += _liked ? 1 : -1;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle ───
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),

          // ─── Scrollable ───
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Author row ──
                  Row(
                    children: [
                      _Avatar(name: widget.message.username, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${widget.message.username}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            _MetaRow(message: widget.message),
                          ],
                        ),
                      ),
                      _VisIcon(visibility: widget.message.visibility),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Content ──
                  Text(widget.message.content,
                      style: const TextStyle(fontSize: 16, height: 1.55, letterSpacing: -0.1)),

                  // ── Hashtags ──
                  if (widget.message.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: widget.message.hashtags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: GeoNoteTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('#$tag',
                            style: const TextStyle(fontSize: 13, color: GeoNoteTheme.primary, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Action buttons ──
                  Row(
                    children: [
                      // Like
                      _ActionPill(
                        icon: _liked ? Icons.favorite : Icons.favorite_border,
                        label: '$_likesCount',
                        color: _liked ? Colors.red : Colors.grey[600]!,
                        bgColor: _liked ? Colors.red.withOpacity(0.08) : Colors.grey[100]!,
                        onTap: isLoggedIn ? _toggleLike : null,
                      ),
                      const SizedBox(width: 10),
                      // Comments
                      _ActionPill(
                        icon: _showComments ? Icons.chat_bubble : Icons.chat_bubble_outline,
                        label: '${_comments.length}',
                        color: _showComments ? Colors.blue : Colors.grey[600]!,
                        bgColor: _showComments ? Colors.blue.withOpacity(0.08) : Colors.grey[100]!,
                        onTap: () => setState(() => _showComments = !_showComments),
                      ),
                      const Spacer(),
                      // Share
                      _ActionPill(
                        icon: Icons.ios_share,
                        label: '',
                        color: Colors.grey[500]!,
                        bgColor: Colors.grey[100]!,
                        onTap: () {},
                      ),
                    ],
                  ),

                  // ── Comments section ──
                  if (_showComments) ...[
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey[200], height: 1),
                    const SizedBox(height: 16),
                    // Comment list
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 32, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Soyez le premier a commenter !',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._comments.map((c) => _CommentTile(comment: c)),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ─── Comment input (always visible when comments open) ───
          if (_showComments && isLoggedIn)
            Container(
              padding: EdgeInsets.fromLTRB(
                14, 10, 8,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    _Avatar(
                      name: auth.user?.username ?? '?',
                      radius: 16,
                      fontSize: 12,
                      bgColor: Colors.grey[200],
                      textColor: Colors.grey[600],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(fontSize: 14),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Ecrire un commentaire...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _sendingComment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            onPressed: _addComment,
                            icon: const Icon(Icons.send_rounded, color: GeoNoteTheme.primary, size: 22),
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

// ─── Sub-widgets ───

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;
  final double? fontSize;
  final Color? bgColor;
  final Color? textColor;
  const _Avatar({required this.name, required this.radius, this.fontSize, this.bgColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor ?? GeoNoteTheme.primary.withOpacity(0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor ?? GeoNoteTheme.primary,
          fontSize: fontSize ?? radius * 0.8,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Message message;
  const _MetaRow({required this.message});

  @override
  Widget build(BuildContext context) {
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
        Icon(Icons.schedule, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        if (message.distanceMeters != null) ...[
          Text('  ·  ', style: TextStyle(color: Colors.grey[300], fontSize: 12)),
          Icon(Icons.near_me, size: 13, color: Colors.grey[400]),
          const SizedBox(width: 3),
          Text(message.distanceFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ],
    );
  }
}

class _VisIcon extends StatelessWidget {
  final String visibility;
  const _VisIcon({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (visibility) {
      'public' => (Icons.public, const Color(0xFF4CAF50), 'Public'),
      'friends' => (Icons.group, const Color(0xFF2196F3), 'Amis'),
      _ => (Icons.lock, const Color(0xFF9E9E9E), 'Prive'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
  const _ActionPill({required this.icon, required this.label, required this.color, required this.bgColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 10 : 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final username = comment['username'] as String? ?? '?';
    final content = comment['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(comment['created_at'] as String? ?? '');

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
          _Avatar(
            name: username,
            radius: 15,
            fontSize: 12,
            bgColor: Colors.grey[100],
            textColor: Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('@$username',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const Spacer(),
                      if (time.isNotEmpty)
                        Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(content, style: const TextStyle(fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
