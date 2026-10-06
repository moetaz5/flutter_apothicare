import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/rotating_glowing_avatar.dart';
import '../../../shared/widgets/wave_clipper.dart';
import '../../admin/presentation/admin_profile_screen.dart';
import 'pharmacien_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  int _currentTabIndex = 2; // Profile is tab index 2

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  void _initUserData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nomController.text = user.nom ?? '';
      _telController.text = (user.tel != null && !user.tel!.contains('@')) ? user.tel! : '';
      _loginController.text = user.login ?? user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index, UserModel? user) {
    if (index == 2) return;
    setState(() => _currentTabIndex = index);

    if (index == 0) {
      if (user?.isAdmin == true || user?.idRole == 1) {
        Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
      } else if (user?.isPatient == true) {
        Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
      }
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.actualites);
    } else if (index == 3) {
      _showLogoutDialog();
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  bool _isStrongPassword(String pwd) {
    if (pwd.isEmpty) return true; // Optional if not changing password
    return pwd.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);
  }

  void _handleSaveProfile() async {
    final nom = _nomController.text.trim();
    final login = _loginController.text.trim();
    final tel = _telController.text.trim();
    final password = _passwordController.text.trim();

    if (nom.isEmpty || login.isEmpty) {
      AppToast.showError('Toutes les données marquées d\'une étoile sont obligatoires');
      return;
    }

    if (password.isNotEmpty && !_isStrongPassword(password)) {
      AppToast.showError('Le mot de passe doit respecter les règles de sécurité (12 caractères, Maj, Min, Chiffre, Symbole).');
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.updateProfile(
      nom: nom,
      login: login,
      tel: tel,
      password: password.isNotEmpty ? password : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        AppToast.showSuccess('Modification réussie');
        _passwordController.clear();
      } else {
        AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour');
      }
    }
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Supprimer le compte', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.error, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF374151)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await auth.deleteAccount();
              if (mounted) {
                if (success) {
                  AppToast.showSuccess('Votre compte a été supprimé avec succès.');
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (route) => false);
                } else {
                  AppToast.showError(auth.errorMessage ?? 'Impossible de supprimer votre compte.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Oui, supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;

    // 1. If Admin: Show dedicated Admin Profile
    if (user?.isAdmin == true || user?.idRole == 1) {
      return const AdminProfileScreen();
    }

    // 2. If Pharmacien: Show dedicated Pharmacien Profile (Identique React UserDetails.jsx)
    if (user?.isPharmacien == true ||
        user?.isJeunePharmacie == true ||
        user?.idRole == 2 ||
        user?.idRole == 4 ||
        user?.idRole == 7 ||
        user?.idRole == 8) {
      return const PharmacienProfileScreen();
    }

    final loginEmail = user?.login ?? user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ─── HERO HEADER (Identique React .pf-hero) ───
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage('assets/images/back-mobile.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.18,
                  scale: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xD9FFFFFF),
                            Color(0xC4F0F8EB),
                            Color(0x2871A246),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Decorative blurred circle
                  Positioned(
                    bottom: -40,
                    right: -30,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  // Pinned "Retour" button at top-left
                  Positioned(
                    top: topPadding + 10,
                    left: 14,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.undo2, size: 14, color: AppColors.primaryGreen),
                            SizedBox(width: 6),
                            Text(
                              'Retour',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Avatar + Titles (Centered across full width with entrance animation)
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.only(top: topPadding + 44, bottom: 24, left: 20, right: 20),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 18 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Patient Avatar
                              RotatingGlowingAvatar(
                                user: user,
                                size: 90,
                                showCameraBadge: false,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Mon profil',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF163820),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loginEmail,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B6A3A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Wave Transition
            CustomPaint(
              size: const Size(double.infinity, 24),
              painter: WavePainter(),
            ),

            // ─── BODY CONTENT ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // 1. SECTION: INFORMATIONS PERSONNELLES
                  _buildSectionCard(
                    title: 'Informations personnelles',
                    icon: LucideIcons.user,
                    iconGradient: const [Color(0xFF71A246), Color(0xFF5D8A38)],
                    child: Column(
                      children: [
                        _buildInputField(
                          label: 'NOM*',
                          hint: 'Nom',
                          controller: _nomController,
                          icon: LucideIcons.user,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          label: 'TÉLÉPHONE',
                          hint: 'Téléphone',
                          controller: _telController,
                          icon: LucideIcons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          label: 'LOGIN*',
                          hint: 'Login',
                          controller: _loginController,
                          icon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. SECTION: SÉCURITÉ
                  _buildSectionCard(
                    title: 'Sécurité',
                    icon: LucideIcons.lock,
                    iconGradient: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          label: 'MOT DE PASSE* (12 CARACTÈRES MINIMUM)',
                          hint: 'Mot de passe',
                          controller: _passwordController,
                          icon: LucideIcons.lock,
                          isPassword: true,
                          obscureText: !_showPassword,
                          onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                        ),
                        const SizedBox(height: 10),
                        // Password rules checklist
                        const Column(
                          children: [
                            _PasswordChecklistRule(rule: 'Au moins 12 caractères'),
                            _PasswordChecklistRule(rule: 'Au moins une lettre majuscule'),
                            _PasswordChecklistRule(rule: 'Au moins une lettre minuscule'),
                            _PasswordChecklistRule(rule: 'Au moins un chiffre'),
                            _PasswordChecklistRule(rule: 'Au moins un caractère spécial'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. SECTION: SUPPRESSION DE COMPTE
                  _buildSectionCard(
                    title: 'Suppression de compte',
                    icon: LucideIcons.trash2,
                    iconGradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _handleDeleteAccount,
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: const Text('Supprimer mon compte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleSaveProfile,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.save, size: 18),
                      label: Text(
                        _isLoading ? 'Enregistrement…' : 'Enregistrer les modifications',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        shadowColor: AppColors.primaryGreen.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTabIndex,
        notifCount: auth.unreadNotifications,
        onTap: (index) => _onBottomNavTapped(index, user),
      ),
    );
  }

  // ─── HELPER WIDGETS ───

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF244082).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF163820),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (isPassword && onTogglePassword != null)
                IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: const Color(0xFF9CA3AF),
                  ),
                  onPressed: onTogglePassword,
                  padding: const EdgeInsets.only(right: 8),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordChecklistRule extends StatelessWidget {
  final String rule;
  const _PasswordChecklistRule({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD1D5DB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rule,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
