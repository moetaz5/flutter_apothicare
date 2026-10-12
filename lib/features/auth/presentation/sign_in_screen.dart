import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/garde_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../gardes/presentation/widgets/custom_map_marker.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  bool _isForgotPassword = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
      // Pre-warm map markers and pharmacies in background for zero-lag instant map opening
      CustomMapMarkerHelper.initMarkers();
      try {
        context.read<GardeProvider>().fetchGardes();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_loginController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      AppToast.showError('Veuillez renseigner votre login et mot de passe.', context);
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      login: _loginController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (success && mounted) {
      final user = authProvider.currentUser;
      String target = AppRoutes.homePharmacien;
      if (user?.isAdmin == true || user?.idRole == 1) {
        target = AppRoutes.homeAdmin;
      } else if (user?.isPatient == true || user?.idRole == 3) {
        target = AppRoutes.homePatient;
      } else if (user?.isPharmacien == true ||
          user?.isJeunePharmacie == true ||
          user?.idRole == 2 ||
          user?.idRole == 4 ||
          user?.idRole == 7 ||
          user?.idRole == 8) {
        target = AppRoutes.homePharmacien;
      } else {
        await authProvider.logout();
        if (mounted) {
          AppToast.showError("Vous n'avez pas l'accès pour utiliser cette application.", context);
        }
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, target, (route) => false);
    } else if (mounted && authProvider.errorMessage != null) {
      AppToast.showError(authProvider.errorMessage!, context);
    }
  }

  void _handleSendResetEmail() async {
    if (_resetEmailController.text.trim().isEmpty) {
      AppToast.showError('Veuillez entrer votre adresse e-mail.', context);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendResetPasswordEmail(
      _resetEmailController.text.trim(),
    );

    if (mounted) {
      if (success) {
        AppToast.showSuccess('Lien de réinitialisation envoyé avec succès !', context);
        setState(() => _isForgotPassword = false);
      } else {
        AppToast.showError(authProvider.errorMessage ?? 'Erreur lors de l\'envoi.', context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = mediaQuery.padding.bottom;

    final isSmallScreen = screenHeight < 860;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2916), // Deep Forest Brand Background
      body: Stack(
        children: [
          // ─── 1. LUXURIOUS FOREST & EMERALD GRADIENT HEADER ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.46,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF091F12), // Deepest Forest
                    Color(0xFF143D24), // Official Dark Green
                    Color(0xFF1B4E2E), // Rich Emerald
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ─── 2. SUBTLE BRAND TEXTURE OVERLAY ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.46,
            child: Opacity(
              opacity: 0.045,
              child: Image.asset(
                'assets/images/back-mobile.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          // ─── 3. RADIANT AMBIENT GLOW ORBS (With continuous gentle pulse) ───
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.35),
                    AppColors.primaryGreen.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.18, 1.18), duration: 3500.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4ADE80).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.22, 1.22), duration: 4200.ms, curve: Curves.easeInOut),
          ),

          // ─── 4. MAIN SCROLLABLE CONTENT ───
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // ─── TOP HERO IDENTITY SECTION ───
                          Padding(
                            padding: EdgeInsets.only(
                              top: isSmallScreen ? 8 : 14,
                              bottom: isSmallScreen ? 8 : 14,
                              left: 16,
                              right: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Sleek Floating Brand Emblem with entrance bounce & subtle float
                                Container(
                                  width: isSmallScreen ? 50 : 60,
                                  height: isSmallScreen ? 50 : 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.40),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(9),
                                  child: Image.asset(
                                    'assets/images/logo1.png',
                                    fit: BoxFit.contain,
                                  ),
                                )
                                    .animate()
                                    .scale(duration: 550.ms, curve: Curves.easeOutBack)
                                    .fadeIn(duration: 400.ms)
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .moveY(begin: 0, end: -4, duration: 2400.ms, curve: Curves.easeInOut),

                                SizedBox(height: isSmallScreen ? 6 : 9),

                                // Brand Title with glowing green accent dot
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'APOTHICARE',
                                      style: GoogleFonts.outfit(
                                        fontSize: isSmallScreen ? 21 : 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 3.0,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    )
                                        .animate(onPlay: (c) => c.repeat(reverse: true))
                                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.35, 1.35), duration: 1600.ms),
                                  ],
                                )
                                    .animate()
                                    .fadeIn(delay: 150.ms, duration: 450.ms)
                                    .slideY(begin: 0.25, end: 0, delay: 150.ms, curve: Curves.easeOutCubic),

                                const SizedBox(height: 6),

                                // Official CNOPT Pill Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.20),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.shieldCheck,
                                        size: 13,
                                        color: Color(0xFF86EFAC),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CONSEIL NATIONAL DE L\'ORDRE DES PHARMACIENS',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFDCFCE7),
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    .animate()
                                    .fadeIn(delay: 220.ms, duration: 400.ms)
                                    .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), delay: 220.ms, curve: Curves.easeOut),

                                SizedBox(height: isSmallScreen ? 7 : 10),

                                // Personalized High-Impact Quick Action Button: "Pharmacie de garde"
                                _buildPersonalizedPharmacyButton(context, isSmallScreen),
                              ],
                            ),
                          ),

                          // ─── 5. ELEVATED MODERN LOGIN CARD (Slide-up animated entrance) ───
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF091F12).withValues(alpha: 0.22),
                                    blurRadius: 32,
                                    offset: const Offset(0, -10),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.fromLTRB(
                                22,
                                isSmallScreen ? 16 : 22,
                                22,
                                bottomPadding > 0 ? bottomPadding + 8 : 18,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.04, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: !_isForgotPassword
                                    ? _buildLoginForm(auth, isSmallScreen)
                                    : _buildForgotPasswordForm(auth),
                              ),
                            )
                                .animate()
                                .slideY(begin: 0.12, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
                                .fadeIn(duration: 450.ms),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOGIN FORM VIEW ───
  Widget _buildLoginForm(AuthProvider auth, bool isSmallScreen) {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header inside Card
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connexion',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF143D24),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Connectez-vous à votre espace officiel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Security Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFBBF7D0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.lock,
                    size: 11,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sécurisé',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 400.ms)
            .slideX(begin: -0.04, end: 0, delay: 150.ms, curve: Curves.easeOut),

        SizedBox(height: isSmallScreen ? 12 : 18),

        // ─── LOGIN INPUT ───
        _buildFieldLabel('IDENTIFIANT OU E-MAIL'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _loginController,
          hintText: 'Votre login ou adresse e-mail',
          prefixIcon: LucideIcons.user,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        )
            .animate()
            .fadeIn(delay: 240.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0, delay: 240.ms, curve: Curves.easeOut),

        SizedBox(height: isSmallScreen ? 10 : 14),

        // ─── PASSWORD INPUT ───
        _buildFieldLabel('MOT DE PASSE'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _passwordController,
          hintText: 'Votre mot de passe',
          prefixIcon: LucideIcons.lock,
          isPassword: true,
          obscureText: _obscurePassword,
          onTogglePassword: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!auth.isLoading) _handleLogin();
          },
        )
            .animate()
            .fadeIn(delay: 320.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0, delay: 320.ms, curve: Curves.easeOut),

        const SizedBox(height: 6),

        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() => _isForgotPassword = true);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Mot de passe oublié ?',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 390.ms, duration: 350.ms),

        SizedBox(height: isSmallScreen ? 14 : 18),

        // ─── PRIMARY SUBMIT BUTTON (With entrance scale & periodic idle shimmer) ───
        _buildGradientButton(
          text: 'Se connecter',
          icon: LucideIcons.logIn,
          isLoading: auth.isLoading,
          onPressed: _handleLogin,
        )
            .animate()
            .fadeIn(delay: 460.ms, duration: 400.ms)
            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), delay: 460.ms, curve: Curves.easeOutBack)
            .animate(onPlay: (c) => c.repeat())
            .shimmer(delay: 3600.ms, duration: 1800.ms, color: Colors.white24),

        SizedBox(height: isSmallScreen ? 14 : 18),

        // ─── OR DIVIDER ───
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFE2E8F0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OU',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE2E8F0), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 530.ms, duration: 350.ms),

        SizedBox(height: isSmallScreen ? 14 : 18),

        // ─── CREATE PATIENT ACCOUNT BUTTON ───
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.signUp);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD6E6CC),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.userPlus,
                    size: 18,
                    color: Color(0xFF143D24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Créer un compte patient',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF143D24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0, delay: 600.ms, curve: Curves.easeOut),

        const Spacer(),

        // ─── FOOTER SECURITY REASSURANCE ───
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.shieldAlert,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Plateforme certifiée CNOPT • Données protégées',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 680.ms, duration: 400.ms),
      ],
    );
  }

  // ─── FORGOT PASSWORD VIEW ───
  Widget _buildForgotPasswordForm(AuthProvider auth) {
    return Column(
      key: const ValueKey('forgot_password_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _isForgotPassword = false);
              },
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: Color(0xFF143D24),
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Text(
              'Réinitialisation',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF143D24),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Entrez votre e-mail pour recevoir le lien de réinitialisation sécurisé.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),

        _buildFieldLabel('ADRESSE E-MAIL'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _resetEmailController,
          hintText: 'Votre adresse e-mail enregistrée',
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!auth.isLoading) _handleSendResetEmail();
          },
        ),
        const SizedBox(height: 22),

        _buildGradientButton(
          text: 'Envoyer le lien',
          icon: LucideIcons.send,
          isLoading: auth.isLoading,
          onPressed: _handleSendResetEmail,
        ),
        const SizedBox(height: 14),

        // Cancel Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              setState(() => _isForgotPassword = false);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Retour à la connexion',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // ─── REUSABLE WIDGET HELPERS ───

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.3,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: InputBorder.none,
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF5E7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              prefixIcon,
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: const Color(0xFF94A3B8),
                    size: 19,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: isLoading
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFF71A246),
                  Color(0xFF538332),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isLoading ? Colors.grey.shade400 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF71A246).withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizedPharmacyButton(BuildContext context, bool isSmallScreen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.gardesMap);
        },
        splashColor: const Color(0xFF4ADE80).withValues(alpha: 0.25),
        highlightColor: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 15,
            vertical: isSmallScreen ? 7 : 8.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dual concentric pulsing radar dot
              SizedBox(
                width: 14,
                height: 14,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.9, 1.9), duration: 1500.ms, curve: Curves.easeOut)
                        .fadeOut(duration: 1500.ms),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4ADE80).withValues(alpha: 0.9),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.mapPin,
                size: 14,
                color: Color(0xFF86EFAC),
              ),
              const SizedBox(width: 6),
              Text(
                'Trouver une pharmacie de garde',
                style: GoogleFonts.outfit(
                  fontSize: isSmallScreen ? 12.0 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              // Live 24/7 pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF86EFAC).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '24/7',
                  style: GoogleFonts.inter(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF86EFAC),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.arrowRight,
                size: 13,
                color: Color(0xFF86EFAC),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 260.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0, delay: 260.ms, curve: Curves.easeOutCubic)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(delay: 3000.ms, duration: 1800.ms, color: Colors.white24);
  }
}

