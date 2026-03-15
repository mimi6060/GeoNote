import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  late AnimationController _bgAnimController;
  late Animation<double> _bgAnimation;

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
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    // Client-side validation
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Veuillez entrer un email valide');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 6 caracteres');
      return;
    }
    if (_isRegister && username.isEmpty) {
      setState(() => _error = 'Veuillez entrer un pseudo');
      return;
    }

    setState(() { _error = null; _submitting = true; });

    try {
      final auth = context.read<AuthProvider>();
      if (_isRegister) {
        await auth.register(username: username, email: email, password: password);
      } else {
        await auth.login(email: email, password: password);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur de connexion. Verifiez votre reseau.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),

                  // --- Logo ---
                  _buildLogo(),
                  const SizedBox(height: 24),

                  // --- Title with gradient ---
                  ShaderMask(
                    shaderCallback: (bounds) => GeoNoteTheme.primaryGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: Text(
                      'GeoNote',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laissez des messages partout dans le monde',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // --- Login / Register toggle ---
                  _buildModeToggle(isDark),
                  const SizedBox(height: 28),

                  // --- Form ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey<bool>(_isRegister),
                        children: [
                          if (_isRegister) ...[
                            _buildTextField(
                              controller: _usernameController,
                              hint: 'Pseudo',
                              icon: Icons.alternate_email_rounded,
                              isDark: isDark,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                          ],
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Email',
                            icon: Icons.mail_outline_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'Mot de passe',
                            icon: Icons.lock_outline_rounded,
                            isDark: isDark,
                            obscure: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  key: ValueKey(_obscurePassword),
                                  size: 20,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Error ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: GeoNoteTheme.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: GeoNoteTheme.error.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: GeoNoteTheme.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.inter(
                                        color: GeoNoteTheme.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // --- Main CTA button with gradient ---
                  _buildGradientButton(),
                  const SizedBox(height: 20),

                  // --- Guest mode ---
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const HomeScreen(),
                          transitionDuration: const Duration(milliseconds: 500),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Continuer sans compte',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: GeoNoteTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: GeoNoteTheme.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pin icon
          const Icon(
            Icons.location_on_rounded,
            size: 44,
            color: Colors.white,
          ),
          // Small note icon overlay
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
                    color: Colors.black.withValues(alpha: 0.15),
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
    );
  }

  Widget _buildModeToggle(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(GeoNoteTheme.radiusXl),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleTab(
            label: 'Se connecter',
            isActive: !_isRegister,
            isDark: isDark,
            onTap: () => setState(() { _isRegister = false; _error = null; }),
          ),
          _buildToggleTab(
            label: "S'inscrire",
            isActive: _isRegister,
            isDark: isDark,
            onTap: () => setState(() { _isRegister = true; _error = null; }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? GeoNoteTheme.primary : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(GeoNoteTheme.radiusXl),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isDark ? GeoNoteTheme.primary : Colors.black)
                          .withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : GeoNoteTheme.primary)
                  : (isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF7C3AED))
                .withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGradientButton() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: _submitting ? null : GeoNoteTheme.primaryGradient,
          color: _submitting ? GeoNoteTheme.primary.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(GeoNoteTheme.radiusXl),
          boxShadow: _submitting
              ? null
              : [
                  BoxShadow(
                    color: GeoNoteTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
        ),
        child: Center(
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isRegister ? 'Creer un compte' : 'Connexion',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
