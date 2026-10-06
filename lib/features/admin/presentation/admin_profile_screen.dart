import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import 'widgets/admin_drawer.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nomController.text = user.nom ?? '';
      _telController.text = user.tel ?? '';
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

  void _onBottomNavTapped(int index) {
    if (index == 2) return;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
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
    if (pwd.isEmpty) return true; // Optional if not changed
    return pwd.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);
  }

  void _submitForm() async {
    final nom = _nomController.text.trim();
    final login = _loginController.text.trim();
    final tel = _telController.text.trim();
    final password = _passwordController.text.trim();

    if (nom.isEmpty || login.isEmpty) {
      AppToast.showError('Toutes les données obligatoires doivent être renseignées.', context);
      return;
    }

    if (password.isNotEmpty && !_isStrongPassword(password)) {
      AppToast.showError(
        'Le mot de passe doit respecter les règles :\n• Au moins 12 caractères\n• Une majuscule\n• Une minuscule\n• Un chiffre\n• Un caractère spécial',
        context,
      );
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.updateProfile(
      nom: nom,
      login: login,
      tel: tel,
      password: password.isNotEmpty ? password : null,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        AppToast.showSuccess('Modification réussie', context);
      } else {
        AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour du profil', context);
      }
    }
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.triangleAlert, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Supprimer le compte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir supprimer votre compte administrateur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final auth = context.read<AuthProvider>();
              final success = await auth.deleteAccount();
              if (mounted) {
                if (success) {
                  AppToast.showSuccess('Votre compte a été supprimé avec succès.', context);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (route) => false);
                } else {
                  AppToast.showError('Impossible de supprimer votre compte.', context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Oui, supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(LucideIcons.menu, color: AppColors.forestGreen, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mon profil',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.primaryGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = await auth.fetchCurrentUserProfile();
              if (!mounted) return;
              if (user != null) {
                _nomController.text = user.nom ?? '';
                _telController.text = user.tel ?? '';
                _loginController.text = user.login ?? user.email ?? '';
                AppToast.showSuccess('Profil actualisé avec succès');
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: _onBottomNavTapped,
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: () async {
          final auth = context.read<AuthProvider>();
          final user = await auth.fetchCurrentUserProfile();
          if (!mounted) return;
          if (user != null) {
            _nomController.text = user.nom ?? '';
            _telController.text = user.tel ?? '';
            _loginController.text = user.login ?? user.email ?? '';
            AppToast.showSuccess('Profil actualisé avec succès');
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
          children: [
            // Main Profile Form Card (Identique React Profile.jsx)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.user, size: 20, color: Color(0xFF00897B)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mon profil',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // Form Fields
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NOM*
                        const Text(
                          'NOM *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nomController,
                          decoration: InputDecoration(
                            hintText: 'Nom',
                            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // TÉLÉPHONE
                        const Text(
                          'TÉLÉPHONE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _telController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Téléphone',
                            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // LOGIN*
                        const Text(
                          'LOGIN *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _loginController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Login',
                            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // MOT DE PASSE* (12 CARACTÈRES MINIMUM)
                        const Text(
                          'MOT DE PASSE* (12 CARACTÈRES MINIMUM)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            hintText: 'Mot de passe',
                            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Password rules list
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PasswordRuleItem(text: 'Au moins 12 caractères'),
                              _PasswordRuleItem(text: 'Au moins une lettre majuscule'),
                              _PasswordRuleItem(text: 'Au moins une lettre minuscule'),
                              _PasswordRuleItem(text: 'Au moins un chiffre'),
                              _PasswordRuleItem(text: 'Au moins un caractère spécial'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons: Supprimer mon compte (left) & Enregistrer (right)
                        Row(
                          children: [
                            // Supprimer mon compte
                            ElevatedButton.icon(
                              onPressed: _handleDeleteAccount,
                              icon: const Icon(LucideIcons.userX, size: 15),
                              label: const Text('Supprimer mon compte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC62828),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const Spacer(),

                            // Enregistrer
                            ElevatedButton(
                              onPressed: _isSaving ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Enregistrer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _PasswordRuleItem extends StatelessWidget {
  final String text;
  const _PasswordRuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF777777),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}
