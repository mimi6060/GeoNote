import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class SearchBarWidget extends StatefulWidget {
  final void Function(String hashtag)? onHashtagSelected;
  final void Function(String userId, String username)? onUserSelected;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    this.onHashtagSelected,
    this.onUserSelected,
    this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _api = ApiService();

  Timer? _debounce;
  bool _isSearching = false;
  bool _showResults = false;
  String _searchType = 'hashtag';

  // Results
  List<Message> _messageResults = [];
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _popularHashtags = [];
  int _totalResults = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _loadPopularHashtags();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() => _showResults = true);
    }
  }

  Future<void> _loadPopularHashtags() async {
    try {
      final hashtags = await _api.getPopularHashtags(limit: 10);
      if (mounted) {
        setState(() => _popularHashtags = hashtags);
      }
    } catch (_) {
      // Silently ignore - popular hashtags are optional
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _messageResults = [];
        _userResults = [];
        _totalResults = 0;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      try {
        final result = await _api.search(query, type: _searchType);

        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _totalResults = result['total'] as int? ?? 0;

          if (_searchType == 'hashtag') {
            final messages = result['messages'] as List<dynamic>? ?? [];
            _messageResults = messages
                .map((e) => Message.fromJson(e as Map<String, dynamic>))
                .toList();
            _userResults = [];
          } else {
            final users = result['users'] as List<dynamic>? ?? [];
            _userResults = users.cast<Map<String, dynamic>>();
            _messageResults = [];
          }
        });
      } catch (_) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  void _selectHashtag(String tag) {
    final cleaned = tag.startsWith('#') ? tag.substring(1) : tag;
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _messageResults = [];
      _userResults = [];
    });
    widget.onHashtagSelected?.call(cleaned);
  }

  void _selectUser(String userId, String username) {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _messageResults = [];
      _userResults = [];
    });
    widget.onUserSelected?.call(userId, username);
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _messageResults = [];
      _userResults = [];
      _totalResults = 0;
    });
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? GeoNoteTheme.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: _searchType == 'hashtag'
                        ? 'Rechercher un #hashtag...'
                        : 'Rechercher un utilisateur...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              // Toggle between hashtag and user search
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchType = _searchType == 'hashtag' ? 'user' : 'hashtag';
                    _messageResults = [];
                    _userResults = [];
                    _totalResults = 0;
                  });
                  if (_controller.text.isNotEmpty) {
                    _onSearchChanged(_controller.text);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GeoNoteTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchType == 'hashtag' ? Icons.tag_rounded : Icons.person_rounded,
                        size: 14,
                        color: GeoNoteTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _searchType == 'hashtag' ? '#' : '@',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GeoNoteTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Results dropdown
        if (_showResults) _buildResultsDropdown(theme, isDark),
      ],
    );
  }

  Widget _buildResultsDropdown(ThemeData theme, bool isDark) {
    final hasQuery = _controller.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, top: 4),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasQuery ? _buildSearchResults(theme, isDark) : _buildPopularHashtags(theme, isDark),
      ),
    );
  }

  Widget _buildPopularHashtags(ThemeData theme, bool isDark) {
    if (_popularHashtags.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            'Hashtags populaires',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ..._popularHashtags.map((h) {
          final tag = h['tag'] as String? ?? '';
          final count = h['count'] as int? ?? 0;
          return _HashtagTile(
            tag: tag,
            count: count,
            isDark: isDark,
            onTap: () => _selectHashtag(tag),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme, bool isDark) {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: GeoNoteTheme.primary,
            ),
          ),
        ),
      );
    }

    if (_searchType == 'hashtag') {
      if (_messageResults.isEmpty) {
        return _EmptyResults(
          icon: Icons.tag_rounded,
          message: 'Aucun message avec ce hashtag',
          isDark: isDark,
        );
      }

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              '$_totalResults resultat${_totalResults > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Show the hashtag itself as a filter option first
          _HashtagTile(
            tag: _controller.text.replaceAll('#', ''),
            count: _totalResults,
            isDark: isDark,
            onTap: () => _selectHashtag(_controller.text),
          ),
          // Then show matching messages
          ..._messageResults.take(5).map((msg) {
            return _MessageResultTile(
              message: msg,
              isDark: isDark,
              onTap: () => _selectHashtag(_controller.text),
            );
          }),
        ],
      );
    } else {
      // User search
      if (_userResults.isEmpty) {
        return _EmptyResults(
          icon: Icons.person_search_rounded,
          message: 'Aucun utilisateur trouve',
          isDark: isDark,
        );
      }

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              '$_totalResults utilisateur${_totalResults > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ..._userResults.map((u) {
            final id = u['id'] as String? ?? '';
            final username = u['username'] as String? ?? '';
            return _UserResultTile(
              userId: id,
              username: username,
              isDark: isDark,
              onTap: () => _selectUser(id, username),
            );
          }),
        ],
      );
    }
  }
}

// ---- Hashtag tile ----

class _HashtagTile extends StatelessWidget {
  final String tag;
  final int count;
  final bool isDark;
  final VoidCallback onTap;

  const _HashtagTile({
    required this.tag,
    required this.count,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GeoNoteTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tag_rounded,
                size: 16,
                color: GeoNoteTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- User result tile ----

class _UserResultTile extends StatelessWidget {
  final String userId;
  final String username;
  final bool isDark;
  final VoidCallback onTap;

  const _UserResultTile({
    required this.userId,
    required this.username,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: GeoNoteTheme.primary.withValues(alpha: 0.12),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: GeoNoteTheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                username,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Message result tile (compact preview) ----

class _MessageResultTile extends StatelessWidget {
  final Message message;
  final bool isDark;
  final VoidCallback onTap;

  const _MessageResultTile({
    required this.message,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.length > 60
                        ? '${message.content.substring(0, 60)}...'
                        : message.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.username,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Empty results ----

class _EmptyResults extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptyResults({
    required this.icon,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
