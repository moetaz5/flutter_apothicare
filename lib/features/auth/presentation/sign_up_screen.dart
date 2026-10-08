import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/app_toast.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _cinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedGouvernorat;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _captchaChecked = false;
  bool _captchaLoading = false;
  bool _acceptedTerms = false;

  // Fallback default list of Tunisian Gouvernorats
  final List<Map<String, dynamic>> _defaultGouvernorats = const [
    {'id': 1, 'nom': 'Tunis'},
    {'id': 2, 'nom': 'Ariana'},
    {'id': 3, 'nom': 'Ben Arous'},
    {'id': 4, 'nom': 'Manouba'},
    {'id': 5, 'nom': 'Nabeul'},
    {'id': 6, 'nom': 'Zaghouan'},
    {'id': 7, 'nom': 'Bizerte'},
    {'id': 8, 'nom': 'Béja'},
    {'id': 9, 'nom': 'Jendouba'},
    {'id': 10, 'nom': 'Le Kef'},
    {'id': 11, 'nom': 'Siliana'},
    {'id': 12, 'nom': 'Kairouan'},
    {'id': 13, 'nom': 'Kasserine'},
    {'id': 14, 'nom': 'Sidi Bouzid'},
    {'id': 15, 'nom': 'Sousse'},
    {'id': 16, 'nom': 'Monastir'},
    {'id': 17, 'nom': 'Mahdia'},
    {'id': 18, 'nom': 'Sfax'},
    {'id': 19, 'nom': 'Gafsa'},
    {'id': 20, 'nom': 'Tozeur'},
    {'id': 21, 'nom': 'Kebili'},
    {'id': 22, 'nom': 'Gabès'},
    {'id': 23, 'nom': 'Médenine'},
    {'id': 24, 'nom': 'Tataouine'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchGouvernorats();
    });
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _cinController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleCaptchaClick() async {
    if (_captchaChecked) {
      setState(() => _captchaChecked = false);
      return;
    }
    setState(() => _captchaLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _captchaLoading = false;
        _captchaChecked = true;
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: Color(0xFF163820),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _openGouvernoratSelector(List<Map<String, dynamic>> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = list.where((g) {
              final name = (g['nom'] ?? g['gouvernorat'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppColors.borderGray,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: AppColors.primaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sélectionner un Gouvernorat',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163820),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un gouvernorat...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderGray),
                      itemBuilder: (_, index) {
                        final g = filtered[index];
                        final name = (g['nom'] ?? g['gouvernorat'] ?? '').toString();
                        final isSelected = _selectedGouvernorat?['nom'] == name;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(LucideIcons.checkCircle2, color: AppColors.primaryGreen, size: 20)
                              : null,
                          onTap: () {
                            setState(() => _selectedGouvernorat = g);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Conditions d\'utilisation — Apothicare',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF163820),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderGray),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En utilisant l\'application Apothicare, vous acceptez les présentes conditions d\'utilisation et consentez au traitement de vos données personnelles conformément au Règlement Général sur la Protection des Données (RGPD).',
                      style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 14),
                    _buildModalSectionTitle('1. Collecte et utilisation des données personnelles'),
                    _buildModalBullet('L\'application peut collecter des informations vous concernant, incluant votre nom, prénom, identifiant santé, gouvernorat.'),
                    _buildModalBullet('Ces données sont utilisées pour vous fournir les fonctionnalités de l\'application, notamment : consultation des pharmacies de garde, notifications et statistiques.'),
                    const SizedBox(height: 14),
                    _buildModalSectionTitle('2. Données de santé'),
                    _buildModalBullet('Certaines données sensibles liées à la santé peuvent être traitées uniquement si elles sont nécessaires au bon fonctionnement (ex. Dossier pharmaceutique).'),
                    _buildModalBullet('Ces données sont strictement protégées et ne sont accessibles qu\'aux personnes autorisées.'),
                    const SizedBox(height: 14),
                    _buildModalSectionTitle('3. Localisation'),
                    _buildModalBullet('L\'application peut accéder à votre position géographique lorsque celle-ci est active afin de vous fournir des informations sur les pharmacies de garde à proximité.'),
                    _buildModalBullet('La localisation n\'est jamais utilisée à d\'autres fins commerciales ou publicitaires.'),
                    const SizedBox(height: 14),
                    _buildModalSectionTitle('4. Conservation et sécurité des données'),
                    _buildModalBullet('Vos données sont conservées uniquement pour la durée nécessaire à l\'utilisation des services.'),
                    _buildModalBullet('Des mesures techniques et organisationnelles sont mises en place pour protéger vos données.'),
                    const SizedBox(height: 14),
                    _buildModalSectionTitle('5. Vos droits'),
                    const Text(
                      'Conformément au RGPD, vous disposez d\'un droit d\'accès, de rectification, de suppression et de limitation du traitement de vos données.',
                      style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'En cochant la case, vous consentez explicitement à la collecte et au traitement de vos données personnelles.',
                      style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.borderGray),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fermer', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _acceptedTerms = true);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163820),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
      ),
    );
  }

  Widget _buildModalBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w900)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151)))),
        ],
      ),
    );
  }

  void _handleRegister() async {
    final nom = _nomController.text.trim();
    final email = _emailController.text.trim();
    final tel = _telController.text.trim();
    final cin = _cinController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. Validation Nom
    if (nom.isEmpty) {
      AppToast.showError('Veuillez renseigner votre nom et prénom.');
      return;
    }

    // 2. Validation Gouvernorat
    if (_selectedGouvernorat == null) {
      AppToast.showError('Veuillez sélectionner votre gouvernorat.');
      return;
    }

    // 3. Validation Date de naissance
    if (_selectedDate == null) {
      AppToast.showError('Veuillez sélectionner votre date de naissance.');
      return;
    }

    // 4. Validation CIN
    if (cin.isEmpty) {
      AppToast.showError('Veuillez renseigner les 3 derniers chiffres de votre CIN.');
      return;
    }
    if (cin.length != 3 || !RegExp(r'^\d{3}$').hasMatch(cin)) {
      AppToast.showError('Le champ CIN doit comporter exactement 3 chiffres.');
      return;
    }

    // 5. Validation Email / Login
    if (email.isEmpty) {
      AppToast.showError('Veuillez renseigner votre adresse e-mail.');
      return;
    }
    final emailRegExp = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegExp.hasMatch(email)) {
      AppToast.showError('Format d\'adresse e-mail invalide (ex: exemple@gmail.com).');
      return;
    }

    // 6. Validation Mot de passe
    if (password.isEmpty) {
      AppToast.showError('Veuillez saisir votre mot de passe.');
      return;
    }
    if (password.length < 6) {
      AppToast.showError('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (confirmPassword.isEmpty) {
      AppToast.showError('Veuillez confirmer votre mot de passe.');
      return;
    }
    if (password != confirmPassword) {
      AppToast.showError('Les mots de passe saisis ne correspondent pas.');
      return;
    }

    // 7. Validation Captcha
    if (!_captchaChecked) {
      AppToast.showError('Veuillez cocher la vérification « Je ne suis pas un robot ».');
      return;
    }

    // 8. Validation Conditions
    if (!_acceptedTerms) {
      AppToast.showError('Veuillez accepter les conditions d\'utilisation d\'Apothicare.');
      return;
    }

    // Identifiant calculation: DDMMYYYY + 3 CIN digits (matching React exact formula)
    final dayStr = _selectedDate!.day.toString().padLeft(2, '0');
    final monthStr = _selectedDate!.month.toString().padLeft(2, '0');
    final yearStr = _selectedDate!.year.toString();
    final identifiant = '$dayStr$monthStr$yearStr$cin';
    final dateNaissanceStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final gName = (_selectedGouvernorat!['nom'] ?? _selectedGouvernorat!['gouvernorat'] ?? '').toString();
    final gId = _selectedGouvernorat!['id'] ?? 0;

    final auth = context.read<AuthProvider>();
    final success = await auth.register({
      'num_evax': '',
      'nom': nom,
      'email': email,
      'tel': tel,
      'gouvernorat': gName,
      'id_gouvernorat': gId,
      'delegation': '',
      'date_naissance': dateNaissanceStr,
      'cin': cin,
      'login': email,
      'password': password,
      'identifiant': identifiant,
      'id_role': 3, // Patient
    });

    if (mounted) {
      if (success) {
        AppToast.showSuccess('Inscription réussie ! Vous pouvez maintenant vous connecter.');
        Navigator.pop(context);
      } else {
        AppToast.showError(auth.errorMessage ?? 'Erreur lors de l\'inscription.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = context.watch<AdminProvider>();
    final gouvernoratsList = admin.gouvernorats.isNotEmpty ? admin.gouvernorats : _defaultGouvernorats;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: Stack(
        children: [
          // Background Gradient Overlay (Identical to React S.overlay)
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
            top: -60,
            right: -60,
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
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ─── HERO TOP AREA (Identical to React S.topArea) ───
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 20, left: 20, right: 20),
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/logo1.png',
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                                .animate()
                                .scale(duration: 450.ms, curve: Curves.easeOutBack)
                                .fadeIn(duration: 350.ms),
                            const SizedBox(height: 10),
                            const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF163820),
                                letterSpacing: -0.4,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 150.ms, duration: 350.ms)
                                .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 350.ms),
                            const SizedBox(height: 2),
                            const Text(
                              'Veuillez entrer vos informations personnelles',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4B6A3A),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 350.ms),
                          ],
                        ),
                      ),

                  // ─── FORM CARD (Identical to React S.card) ───
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 36,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card handle pill
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Inscription Patient',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2D5A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tous les champs marqués * sont obligatoires',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8EA0B8),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── SECTION: IDENTITÉ ───
                        _buildSectionHeader('IDENTITÉ'),

                        // Row: Nom et Prénom + Gouvernorat
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'NOM ET PRÉNOM *',
                                hint: 'Nom et prénom',
                                icon: LucideIcons.user,
                                controller: _nomController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGouvernoratDropdown(gouvernoratsList),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Date de naissance
                        _buildDateOfBirthPicker(),
                        const SizedBox(height: 14),

                        // CIN (3 derniers)
                        _buildFormField(
                          label: 'CIN (3 DERNIERS) *',
                          hint: 'Ex: 123',
                          icon: LucideIcons.creditCard,
                          controller: _cinController,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                        ),

                        // ─── SECTION: CONTACT ───
                        _buildSectionHeader('CONTACT'),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'EMAIL (LOGIN) *',
                                hint: 'Email',
                                icon: LucideIcons.mail,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'TÉLÉPHONE',
                                hint: 'Téléphone',
                                icon: LucideIcons.phone,
                                controller: _telController,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),

                        // ─── SECTION: MOT DE PASSE ───
                        _buildSectionHeader('MOT DE PASSE'),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'MOT DE PASSE *',
                                hint: 'Mot de passe',
                                icon: LucideIcons.lock,
                                controller: _passwordController,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'CONFIRMER *',
                                hint: 'Confirmer',
                                icon: LucideIcons.lock,
                                controller: _confirmPasswordController,
                                isPassword: true,
                                obscureText: _obscureConfirmPassword,
                                onTogglePassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ─── reCAPTCHA Box (Identical React Style) ───
                        _buildRecaptchaBox(),
                        const SizedBox(height: 14),

                        // ─── Terms & Conditions Box (Identical React Style) ───
                        _buildTermsBox(),
                        const SizedBox(height: 20),

                        // ─── Submit Button (Identical React btnPrimary) ───
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              shadowColor: AppColors.primaryGreen.withValues(alpha: 0.35),
                            ),
                            child: auth.isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Enregistrement…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    ],
                                  )
                                : const Text("S'inscrire", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Footer Link: Se connecter ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Vous avez déjà un compte ? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8EA0B8),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF163820),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Back button on top-left (Matches React S.btnBack: absolute top 14px, left 14px)
            Positioned(
              left: 14,
              top: 14,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
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
          ],
        ),
      ),
    ],
  ),
);
  }

  // ─── HELPER WIDGETS ───

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE4EAF3), height: 1)),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7A99),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon, size: 16, color: AppColors.primaryGreen),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  maxLength: maxLength,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E2D5A), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF8EA0B8), fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    counterText: '',
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
                    color: const Color(0xFF8EA0B8),
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

  Widget _buildGouvernoratDropdown(List<Map<String, dynamic>> list) {
    final name = _selectedGouvernorat != null
        ? (_selectedGouvernorat!['nom'] ?? _selectedGouvernorat!['gouvernorat'] ?? '').toString()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GOUVERNORAT *',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7A99),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openGouvernoratSelector(list),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name ?? 'Gouvernorat',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: name != null ? FontWeight.w600 : FontWeight.w400,
                      color: name != null ? const Color(0xFF1E2D5A) : const Color(0xFF8EA0B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primaryGreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthPicker() {
    final dateStr = _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DATE DE NAISSANCE *',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7A99),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDateOfBirth,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateStr ?? 'jj/mm/aaaa',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: dateStr != null ? FontWeight.w600 : FontWeight.w400,
                      color: dateStr != null ? const Color(0xFF1E2D5A) : const Color(0xFF8EA0B8),
                    ),
                  ),
                ),
                const Icon(LucideIcons.calendarDays, size: 16, color: Color(0xFF8EA0B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecaptchaBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6D6D6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _handleCaptchaClick,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _captchaChecked ? AppColors.primaryGreen : const Color(0xFFC1C1C1),
                  width: 2,
                ),
              ),
              child: Center(
                child: _captchaLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                      )
                    : _captchaChecked
                        ? const Icon(Icons.check, size: 20, color: AppColors.primaryGreen)
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Je ne suis pas un robot',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF282828),
              ),
            ),
          ),
          Column(
            children: [
              Image.network(
                'https://www.gstatic.com/recaptcha/api2/logo_48.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(LucideIcons.shieldCheck, color: Color(0xFF4285F4), size: 24),
              ),
              const Text(
                'reCAPTCHA',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
              ),
              const Text(
                'Confidentialité - Conditions',
                style: TextStyle(fontSize: 7, color: Color(0xFF888888)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D5F5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _acceptedTerms,
              onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
              activeColor: const Color(0xFF163820),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.5),
                children: [
                  const TextSpan(text: 'J\'accepte les '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: _showTermsDialog,
                      child: const Text(
                        'Conditions d\'utilisation',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163820),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: ' d\'Apothicare, incluant le traitement des données personnelles et de santé, ainsi que l\'utilisation de la localisation lorsque l\'application est active.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
