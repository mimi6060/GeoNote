import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../widgets/create_sheet.dart';
import 'map_screen.dart';
import 'feed_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _index = 0;

  void _onTabTapped(int index) {
    if (index == 2) {
      // Center "+" button -> open create sheet
      _openCreateSheet();
      return;
    }
    setState(() => _index = index);
  }

  void _openCreateSheet() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final position = LocationService.lastKnownOrDefault;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CreateSheet(
                position: position,
                onCreated: () {
                  // Optionally refresh
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const realScreens = [
      MapScreen(),
      FeedScreen(),
      LeaderboardScreen(),
      ProfileScreen(),
    ];

    // Map tab index to screen index
    int displayIndex;
    if (_index <= 1) {
      displayIndex = _index;
    } else {
      // tabs 3,4 map to screens 2,3
      displayIndex = _index - 1;
    }

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: IndexedStack(
          key: ValueKey<int>(displayIndex.clamp(0, 3)),
          index: displayIndex.clamp(0, 3),
          children: realScreens,
        ),
      ),
      bottomNavigationBar: _GeoNoteBottomBar(
        currentIndex: _index,
        onTap: _onTabTapped,
        isDark: isDark,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Custom glassmorphic bottom navigation bar with animations
// ────────────────────────────────────────────────────────────────

class _GeoNoteBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _GeoNoteBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_GeoNoteBottomBar> createState() => _GeoNoteBottomBarState();
}

class _GeoNoteBottomBarState extends State<_GeoNoteBottomBar>
    with TickerProviderStateMixin {
  late AnimationController _fabScaleController;
  late Animation<double> _fabScaleAnimation;

  late AnimationController _fabEntryController;
  late Animation<double> _fabEntryAnimation;

  @override
  void initState() {
    super.initState();

    // Tap bounce animation for the "+" button
    _fabScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fabScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _fabScaleController,
      curve: Curves.easeOut,
    ));

    // Entry scale-up animation for the "+" button
    _fabEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabEntryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabEntryController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );
    _fabEntryController.forward();
  }

  @override
  void dispose() {
    _fabScaleController.dispose();
    _fabEntryController.dispose();
    super.dispose();
  }

  void _onFabTap() {
    _fabScaleController.forward(from: 0).then((_) {
      widget.onTap(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
      ),
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // --- Glassmorphic bar ---
            ClipRRect(
              borderRadius: BorderRadius.circular(GeoNoteTheme.radiusLg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.88),
                    borderRadius:
                        BorderRadius.circular(GeoNoteTheme.radiusLg),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: widget.isDark ? 0.3 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.map_outlined,
                        activeIcon: Icons.map_rounded,
                        label: 'Carte',
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.dynamic_feed_outlined,
                        activeIcon: Icons.dynamic_feed_rounded,
                        label: 'Feed',
                      ),
                      // Center spacer for the "+" button
                      const Expanded(child: SizedBox()),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.emoji_events_outlined,
                        activeIcon: Icons.emoji_events_rounded,
                        label: 'Classement',
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profil',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Center "+" button (elevated, TikTok-style) with scale animation ---
            Positioned(
              top: -8,
              child: ScaleTransition(
                scale: _fabEntryAnimation,
                child: AnimatedBuilder(
                  animation: _fabScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabScaleController.isAnimating
                          ? _fabScaleAnimation.value
                          : 1.0,
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onTap: _onFabTap,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: GeoNoteTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GeoNoteTheme.primary
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = widget.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey<bool>(isActive),
                    size: 24,
                    color: isActive
                        ? GeoNoteTheme.primary
                        : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? GeoNoteTheme.primary
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFF9CA3AF)),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
