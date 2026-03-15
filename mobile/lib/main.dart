import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/events_provider.dart';
import 'providers/messages_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'light') _mode = ThemeMode.light;
    if (saved == 'dark') _mode = ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode.name);
  }
}

void main() {
  // Disable Google Fonts HTTP fetching — use bundled/system fonts to avoid crashes
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const GeoNoteApp());
}

class GeoNoteApp extends StatelessWidget {
  const GeoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeNotifier>().mode;
          return MaterialApp(
            title: 'GeoNote',
            debugShowCheckedModeBanner: false,
            theme: GeoNoteTheme.light,
            darkTheme: GeoNoteTheme.dark,
            themeMode: themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  bool? _onboardingSeen;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final authProvider = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    await authProvider.init();

    if (mounted) {
      setState(() {
        _onboardingSeen = onboardingSeen;
        _ready = true;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_ready) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -1.0),
              end: const Alignment(1.0, 1.0),
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
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Opacity(
                    opacity: 0.7 + _pulseAnimation.value * 0.3,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: GeoNoteTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color:
                              GeoNoteTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                        Positioned(
                          bottom: 18,
                          right: 18,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: GeoNoteTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        GeoNoteTheme.primaryGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: const Text(
                      'GeoNote',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Onboarding not seen yet
    if (_onboardingSeen == false) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    final auth = context.watch<AuthProvider>();
    final destination = auth.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey<bool>(auth.isLoggedIn),
        child: destination,
      ),
    );
  }
}
