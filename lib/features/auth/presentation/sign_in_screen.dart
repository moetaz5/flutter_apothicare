import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: Stack(
        children: [
          // Background Gradient Overlay
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

          // Ambient Decorative Blurred Glows (Animated)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withValues(alpha: 0.18),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 4.seconds),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF244082).withValues(alpha: 0.10),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 5.seconds),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Hero Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Apothicare Logo container with glow & pop animation
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo1.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.easeOutBack)
                          .fadeIn(duration: 400.ms)
                          .shimmer(delay: 600.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5)),

                      const SizedBox(height: 12),
                      const Text(
                        'Bienvenue sur Apothicare !',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: AppColors.forestGreen,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOutCubic),

                      const SizedBox(height: 4),
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
                          .fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 14),

                      // Quick Action: Trouver la pharmacie ouverte (Animated pill)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.gardesMap);
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withValues(alpha: 0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.mapPin, size: 14, color: AppColors.primaryGreen),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Trouvez la pharmacie ouverte',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.chevronRight, size: 15, color: AppColors.primaryGreen),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 400.ms)
                          .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),
                    ],
                  ),
                ),

                // Bottom Floating Sheet Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF244082).withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle pill
                          Center(
                            child: Container(
                              width: 40,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: AppColors.borderGray,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (!_isForgotPassword) ...[
                            const Text(
                              'Connexion',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: -0.1, end: 0, duration: 300.ms),
                            const SizedBox(height: 4),
                            const Text(
                              'Connectez-vous à votre espace santé',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 350.ms),
                            const SizedBox(height: 20),

                            // Login Field
                            CustomTextField(
                              label: 'Login',
                              hintText: 'Votre login ou e-mail',
                              controller: _loginController,
                              prefixIcon: LucideIcons.user,
                              keyboardType: TextInputType.emailAddress,
                            )
                                .animate()
                                .fadeIn(delay: 150.ms, duration: 350.ms)
                                .slideY(begin: 0.15, end: 0, delay: 150.ms, duration: 350.ms),
                            const SizedBox(height: 14),

                            // Password Field
                            CustomTextField(
                              label: 'Mot de passe',
                              hintText: 'Votre mot de passe',
                              controller: _passwordController,
                              prefixIcon: LucideIcons.lock,
                              isPassword: true,
                            )
                                .animate()
                                .fadeIn(delay: 250.ms, duration: 350.ms)
                                .slideY(begin: 0.15, end: 0, delay: 250.ms, duration: 350.ms),
                            const SizedBox(height: 8),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _isForgotPassword = true);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
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
                            )
                                .animate()
                                .fadeIn(delay: 300.ms, duration: 300.ms),
                            const SizedBox(height: 16),

                            // Submit Button
                            CustomButton(
                              text: 'Se connecter',
                              onPressed: _handleLogin,
                              isLoading: auth.isLoading,
                            )
                                .animate()
                                .fadeIn(delay: 350.ms, duration: 350.ms)
                                .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), delay: 350.ms, duration: 350.ms),
                            const SizedBox(height: 14),

                            // Divider
                            const Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.borderGray)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'ou',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.borderGray)),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 400.ms, duration: 300.ms),
                            const SizedBox(height: 12),

                            // Create Account
                            CustomButton(
                              text: 'Créer un compte patient',
                              type: CustomButtonType.outline,
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.signUp);
                              },
                            )
                                .animate()
                                .fadeIn(delay: 450.ms, duration: 350.ms),
                          ] else ...[
                            // Forgot Password View
                            const Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms),
                            const SizedBox(height: 4),
                            const Text(
                              'Entrez votre e-mail pour recevoir un lien de réinitialisation',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 350.ms),
                            const SizedBox(height: 20),

                            CustomTextField(
                              label: 'Adresse e-mail',
                              hintText: 'Votre adresse e-mail',
                              controller: _resetEmailController,
                              prefixIcon: LucideIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                            )
                                .animate()
                                .fadeIn(delay: 150.ms, duration: 350.ms),
                            const SizedBox(height: 20),

                            CustomButton(
                              text: 'Envoyer le lien',
                              onPressed: _handleSendResetEmail,
                              isLoading: auth.isLoading,
                            )
                                .animate()
                                .fadeIn(delay: 250.ms, duration: 350.ms),
                            const SizedBox(height: 10),

                            CustomButton(
                              text: 'Annuler',
                              type: CustomButtonType.dangerOutline,
                              onPressed: () {
                                setState(() => _isForgotPassword = false);
                              },
                            )
                                .animate()
                                .fadeIn(delay: 300.ms, duration: 350.ms),
                          ],
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
