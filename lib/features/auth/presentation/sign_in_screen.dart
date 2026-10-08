import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
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
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // Responsive sizing helpers
    final isSmallScreen = screenHeight < 760;
    final topLogoSize = isSmallScreen ? 48.0 : 56.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: Stack(
        children: [
          // Background Gradient Overlay (full screen)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF0F8EB),
                    Color(0xFFE5F2DC),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Ambient Decorative Blurred Glows
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF244082).withValues(alpha: 0.08),
              ),
            ),
          ),

          // Main scrollable content stretching across full screen
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ─── TOP HEADER SECTION (Aware of Notch / Dynamic Island) ───
                        Padding(
                          padding: EdgeInsets.only(
                            top: topPadding + (isSmallScreen ? 6 : 12),
                            left: 20,
                            right: 20,
                            bottom: isSmallScreen ? 12 : 16,
                          ),
                          child: Column(
                            children: [
                              // Apothicare Logo with sleek rounded badge & shadow
                              Container(
                                width: topLogoSize,
                                height: topLogoSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.20),
                                      blurRadius: 18,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/logo1.png',
                                    width: topLogoSize * 0.70,
                                    height: topLogoSize * 0.70,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                                  .animate()
                                  .scale(duration: 400.ms, curve: Curves.easeOutBack)
                                  .fadeIn(duration: 350.ms),

                              SizedBox(height: isSmallScreen ? 8 : 12),
                              Text(
                                'Bienvenue sur Apothicare !',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 23,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.forestGreen,
                                  letterSpacing: -0.4,
                                ),
                                textAlign: TextAlign.center,
                              )
                                  .animate()
                                  .fadeIn(delay: 150.ms, duration: 350.ms),

                              const SizedBox(height: 3),
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSubtitle,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  children: [
                                    TextSpan(text: 'Développée par le '),
                                    TextSpan(
                                      text: 'CNOPT',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(text: ' au service des citoyens'),
                                  ],
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 350.ms),

                              SizedBox(height: isSmallScreen ? 10 : 14),

                              // Quick Action: Trouvez la pharmacie ouverte
                              InkWell(
                                onTap: () {
                                  Navigator.pushNamed(context, AppRoutes.gardesMap);
                                },
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.18),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.mapPin, size: 14, color: AppColors.primaryGreen),
                                      SizedBox(width: 8),
                                      Text(
                                        'Trouvez la pharmacie ouverte',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.forestGreen,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primaryGreen),
                                    ],
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: 250.ms, duration: 350.ms),
                            ],
                          ),
                        ),

                        // ─── BOTTOM FLOATING WHITE CARD (Stretches all the way to screen bottom) ───
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF244082).withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, -8),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.fromLTRB(
                              22,
                              isSmallScreen ? 14 : 20,
                              22,
                              bottomPadding > 0 ? bottomPadding + 14 : 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Handle indicator
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 10 : 16),

                                if (!_isForgotPassword) ...[
                                  const Text(
                                    'Connexion',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.forestGreen,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Connectez-vous à votre espace santé',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 18),

                                  // Login Field
                                  CustomTextField(
                                    label: 'LOGIN',
                                    hintText: 'Votre login ou e-mail',
                                    controller: _loginController,
                                    prefixIcon: LucideIcons.user,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  SizedBox(height: isSmallScreen ? 10 : 14),

                                  // Password Field
                                  CustomTextField(
                                    label: 'MOT DE PASSE',
                                    hintText: 'Votre mot de passe',
                                    controller: _passwordController,
                                    prefixIcon: LucideIcons.lock,
                                    isPassword: true,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      if (!auth.isLoading) {
                                        _handleLogin();
                                      }
                                    },
                                  ),
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
                                      child: const Text(
                                        'Mot de passe oublié ?',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 10 : 16),

                                  // Submit Button
                                  CustomButton(
                                    text: 'Se connecter',
                                    onPressed: _handleLogin,
                                    isLoading: auth.isLoading,
                                  ),
                                  SizedBox(height: isSmallScreen ? 10 : 14),

                                  // Divider
                                  const Row(
                                    children: [
                                      Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 14),
                                        child: Text(
                                          'ou',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                                    ],
                                  ),
                                  SizedBox(height: isSmallScreen ? 10 : 14),

                                  // Create Account
                                  CustomButton(
                                    text: 'Créer un compte patient',
                                    type: CustomButtonType.outline,
                                    onPressed: () {
                                      Navigator.pushNamed(context, AppRoutes.signUp);
                                    },
                                  ),
                                ] else ...[
                                  // Forgot Password View
                                  const Text(
                                    'Mot de passe oublié ?',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.forestGreen,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Entrez votre e-mail pour recevoir un lien de réinitialisation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  CustomTextField(
                                    label: 'ADRESSE E-MAIL',
                                    hintText: 'Votre adresse e-mail',
                                    controller: _resetEmailController,
                                    prefixIcon: LucideIcons.mail,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 18),

                                  CustomButton(
                                    text: 'Envoyer le lien',
                                    onPressed: _handleSendResetEmail,
                                    isLoading: auth.isLoading,
                                  ),
                                  const SizedBox(height: 12),

                                  CustomButton(
                                    text: 'Annuler',
                                    type: CustomButtonType.dangerOutline,
                                    onPressed: () {
                                      setState(() => _isForgotPassword = false);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
