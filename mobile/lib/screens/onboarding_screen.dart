import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bgAnimController;
  late Animation<double> _bgAnimation;

  late AnimationController _contentAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.explore_rounded,
      secondaryIcon: Icons.location_on_rounded,
      title: 'Explorez',
      description: 'Decouvrez les messages caches autour de vous',
      gradientColors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
    ),
    _OnboardingPageData(
      icon: Icons.edit_note_rounded,
      secondaryIcon: Icons.auto_awesome_rounded,
      title: 'Creez',
      description:
          'Laissez des notes ephemeres, mysteres ou capsules temporelles',
      gradientColors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    ),
    _OnboardingPageData(
      icon: Icons.people_rounded,
      secondaryIcon: Icons.emoji_events_rounded,
      title: 'Connectez',
      description: 'Reagissez, commentez et grimpez le classement',
      gradientColors: [Color(0xFFEC4899), Color(0xFF7C3AED)],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bgAnimController, curve: Curves.easeInOut),
    );

    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );

    _contentAnimController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _contentAnimController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _contentAnimController.reset();
    _contentAnimController.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  -1.0 + _bgAnimation.value * 0.5,
                  -1.0 + _bgAnimation.value * 0.3,
                ),
                end: Alignment(
                  1.0 - _bgAnimation.value * 0.3,
                  1.0 - _bgAnimation.value * 0.5,
                ),
                colors: isDark
                    ? [
                        const Color(0xFF0A0A0A),
                        const Color(0xFF1A0A2E),
                        const Color(0xFF0A0A0A),
                      ]
                    : [
                        const Color(0xFFF5F3FF),
                        const Color(0xFFEDE9FE),
                        const Color(0xFFE0F2FE),
                      ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 20),
                  child: GestureDetector(
                    onTap: _completeOnboarding,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isDark);
                  },
                ),
              ),

              // Dots indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive
                            ? GeoNoteTheme.primary
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFD1D5DB)),
                      ),
                    );
                  }),
                ),
              ),

              // Next / Start button
              Padding(
                padding:
                    const EdgeInsets.only(left: 28, right: 28, bottom: 24),
                child: GestureDetector(
                  onTap: _nextPage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: GeoNoteTheme.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(GeoNoteTheme.radiusXl),
                      boxShadow: [
                        BoxShadow(
                          color:
                              GeoNoteTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'Commencer'
                              : 'Suivant',
                          key: ValueKey<String>(
                            _currentPage == _pages.length - 1
                                ? 'start'
                                : 'next',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData data, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      data.icon,
                      size: 64,
                      color: Colors.white,
                    ),
                    Positioned(
                      bottom: 22,
                      right: 22,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          data.secondaryIcon,
                          size: 18,
                          color: data.gradientColors[0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Title
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: data.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final IconData secondaryIcon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingPageData({
    required this.icon,
    required this.secondaryIcon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
