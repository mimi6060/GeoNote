import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
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
      if (mounted) setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final result = await context.read<MessagesProvider>().toggleLikeAndReturn(widget.message.id);
      if (mounted) {
        setState(() {
          _liked = result['liked'] as bool;
          _likesCount = result['likes_count'] as int;
        });
      }
      widget.onRefresh?.call();
    } catch (_) {}
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
    } catch (_) {}
    if (mounted) setState(() => _sendingComment = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: GeoNoteTheme.primary.withOpacity(0.15),
                        child: Text(
                          widget.message.username.isNotEmpty
                              ? widget.message.username[0].toUpperCase()
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
                              '@${widget.message.username}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatTime(widget.message.createdAt),
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                                if (widget.message.distanceMeters != null) ...[
                                  Text(' · ', style: TextStyle(color: Colors.grey[400])),
                                  Icon(Icons.place, size: 12, color: Colors.grey[400]),
                                  Text(
                                    widget.message.distanceFormatted,
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
                    widget.message.content,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  // Hashtags
                  if (widget.message.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.message.hashtags.map((tag) {
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
                  const SizedBox(height: 16),
                  // Actions bar
                  Row(
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: auth.isLoggedIn ? _toggleLike : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _liked ? Colors.red.withOpacity(0.08) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _liked ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _liked ? Icons.favorite : Icons.favorite_border,
                                size: 20,
                                color: _liked ? Colors.red : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_likesCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _liked ? Colors.red : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Comment count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              '${_comments.length}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Comments section
                  Divider(color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingComments)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Aucun commentaire pour le moment',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._comments.map((c) => _CommentTile(comment: c)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Comment input
          if (auth.isLoggedIn)
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 8, top: 8, bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ecrire un commentaire...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _sendingComment ? null : _addComment,
                    icon: _sendingComment
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: GeoNoteTheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd MMM yyyy').format(date);
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[200],
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(content, style: const TextStyle(fontSize: 14, height: 1.3)),
              ],
            ),
          ),
        ],
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
