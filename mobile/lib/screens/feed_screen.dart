import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/message_card.dart';
import '../widgets/message_popup.dart';
import '../widgets/search_bar_widget.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _sort = 'distance';
  String? _filterHashtag;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    context.read<MessagesProvider>().loadNearby(
          location ?? LocationService.lastKnownOrDefault,
          radius: 50000,
        );
  }

  void _showMessage(msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessagePopup(message: msg, onRefresh: _load),
    );
  }

  void _showReportFromCard(String messageId) {
    final reasons = <String, String>{
      'spam': 'Spam',
      'harassment': 'Harcelement',
      'inappropriate': 'Contenu inapproprie',
      'misinformation': 'Desinformation',
      'other': 'Autre',
    };
    String? selectedReason;
    final descController = TextEditingController();

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
                  Icon(Icons.flag_rounded, color: Colors.red[400], size: 22),
                  const SizedBox(width: 8),
                  const Text('Signaler',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            onTap: () =>
                                setDialogState(() => selectedReason = entry.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color:
                                            Colors.red.withValues(alpha: 0.3))
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
                                  Text(entry.value,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      maxLength: 500,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Details (optionnel)',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35)),
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
                  child: Text('Annuler',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ),
                TextButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          try {
                            await ApiService().reportMessage(
                              messageId,
                              selectedReason!,
                              description: descController.text.trim(),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Signalement enregistre, merci'),
                                  backgroundColor: Colors.green[600],
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
                                  content:
                                      const Text('Erreur lors du signalement'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: Text('Signaler',
                      style: TextStyle(
                        color: selectedReason == null
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.2)
                            : Colors.red[400],
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSortSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Trier par',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _SortOption(
                  icon: Icons.near_me_rounded,
                  label: 'Plus proches',
                  subtitle: 'Par distance',
                  selected: _sort == 'distance',
                  onTap: () {
                    setState(() => _sort = 'distance');
                    Navigator.pop(ctx);
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                ),
                _SortOption(
                  icon: Icons.schedule_rounded,
                  label: 'Plus recents',
                  subtitle: 'Par date',
                  selected: _sort == 'recent',
                  onTap: () {
                    setState(() => _sort = 'recent');
                    Navigator.pop(ctx);
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                ),
                _SortOption(
                  icon: Icons.favorite_rounded,
                  label: 'Plus populaires',
                  subtitle: 'Par likes',
                  selected: _sort == 'popular',
                  onTap: () {
                    setState(() => _sort = 'popular');
                    Navigator.pop(ctx);
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 56,
              title: Row(
                children: [
                  Text(
                    'GeoNote',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (_filterHashtag != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GeoNoteTheme.primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$_filterHashtag',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GeoNoteTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(
                                () => _filterHashtag = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: GeoNoteTheme.primary
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _showSortSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _sort != 'distance'
                              ? GeoNoteTheme.primary
                                  .withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: _sort != 'distance'
                              ? GeoNoteTheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: SearchBarWidget(
                  onHashtagSelected: (tag) {
                    setState(() => _filterHashtag = tag);
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                  onUserSelected: (userId, username) {
                    // Navigate to user profile could be added here
                    // For now, we show a snackbar with the username
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profil de $username'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  onClear: () {
                    setState(() => _filterHashtag = null);
                  },
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          color: GeoNoteTheme.primary,
          onRefresh: _load,
          child: provider.error != null
              ? _ErrorState(onRetry: _load, isDark: isDark)
              : provider.loading && provider.messages.isEmpty
                  ? _ShimmerLoading(isDark: isDark)
                  : provider.messages.isEmpty
                      ? const _EmptyFeed()
                      : Builder(
                          builder: (context) {
                            final sorted =
                                _sortedMessages(provider.messages);
                            return ListView.builder(
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 80),
                              itemCount: sorted.length,
                              itemBuilder: (context, i) {
                                return MessageCard(
                                  message: sorted[i],
                                  onTap: () =>
                                      _showMessage(sorted[i]),
                                  onHashtagTap: (tag) {
                                    setState(
                                        () => _filterHashtag = tag);
                                    _scrollController.animateTo(0,
                                        duration: const Duration(
                                            milliseconds: 300),
                                        curve: Curves.easeOut);
                                  },
                                  onLike: () async {
                                    await provider
                                        .toggleLike(sorted[i].id);
                                    _load();
                                  },
                                  onReport: context.read<AuthProvider>().isLoggedIn
                                      ? () => _showReportFromCard(sorted[i].id)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
        ),
      ),
    );
  }

  List<dynamic> _sortedMessages(List msgs) {
    var sorted = List.of(msgs);

    // Filter by hashtag
    if (_filterHashtag != null) {
      sorted = sorted
          .where((m) => m.hashtags.any((h) =>
              h.toString().toLowerCase() ==
              _filterHashtag!.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sort) {
      case 'recent':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'popular':
        sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      default:
        break;
    }
    return sorted;
  }
}

// ---- Sort option tile ----

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: selected
            ? GeoNoteTheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? GeoNoteTheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? GeoNoteTheme.primary
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? GeoNoteTheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: GeoNoteTheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Shimmer loading ----

class _ShimmerLoading extends StatelessWidget {
  final bool isDark;
  const _ShimmerLoading({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!;
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : Colors.grey[50]!;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: 4,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header shimmer
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content lines shimmer
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action bar shimmer
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 60,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---- Empty feed state ----

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      GeoNoteTheme.primary.withValues(alpha: 0.15),
                      const Color(0xFFFF9800).withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GeoNoteTheme.primary, Color(0xFFFF9800)],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.explore_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucune note autour de vous',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Soyez le premier a laisser un message !',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Error state ----

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorState({required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 36,
                    color: Colors.red[isDark ? 300 : 400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Erreur de connexion',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verifiez votre connexion internet\net reessayez',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          GeoNoteTheme.primary,
                          Color(0xFFFF9800),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded,
                          size: 18),
                      label: const Text('Reessayer'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
    );
  }
}
