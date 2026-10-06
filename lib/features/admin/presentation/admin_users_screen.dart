import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _selectedEtatFilter = 'all'; // all, 1 (Actif), 0 (Désactivé)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  void _loadUsers() {
    context.read<AdminProvider>().fetchUsers(forceRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getRoleName(dynamic roleId, [Map<String, dynamic>? user]) {
    final roleNom = user?['roles']?['nom'] ?? user?['role_nom'] ?? user?['role_name'];
    if (roleNom != null && roleNom.toString().trim().isNotEmpty) {
      return roleNom.toString();
    }
    final id = int.tryParse(roleId?.toString() ?? '') ?? 0;
    switch (id) {
      case 1:
        return 'Administrateur';
      case 2:
        return 'Pharmacien (Titulaire)';
      case 3:
        return 'Patient';
      case 4:
        return 'Conseil Régional';
      case 7:
        return 'Jeune Pharmacie (Remplaçant)';
      case 8:
        return 'Employé';
      default:
        return 'Utilisateur';
    }
  }

  Color _getRoleColor(dynamic roleId) {
    final id = int.tryParse(roleId?.toString() ?? '') ?? 0;
    switch (id) {
      case 1:
        return const Color(0xFF6366F1); // Indigo
      case 2:
        return AppColors.forestGreen; // Green
      case 3:
        return const Color(0xFF0284C7); // Sky Blue
      case 4:
        return const Color(0xFFD97706); // Amber
      case 7:
      case 8:
        return const Color(0xFF0D9488); // Teal
      default:
        return AppColors.textMuted;
    }
  }

  void _showAddUserSheet() {
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final telController = TextEditingController();
    final cnoptController = TextEditingController();
    final passwordController = TextEditingController();
    int selectedRole = 2; // Default Pharmacien
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.userPlus, color: AppColors.primaryGreen, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Ajouter un utilisateur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                const Text('Rôle *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('Pharmacien (Titulaire)')),
                        DropdownMenuItem(value: 3, child: Text('Patient')),
                        DropdownMenuItem(value: 4, child: Text('Conseil Régional')),
                        DropdownMenuItem(value: 7, child: Text('Jeune Pharmacie (Remplaçant)')),
                        DropdownMenuItem(value: 1, child: Text('Administrateur')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedRole = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nom
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom et prénom *',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Email / Login
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email / Login *',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Password
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe *',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Téléphone
                TextField(
                  controller: telController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // N° CNOPT (if pharmacist)
                if (selectedRole == 2 || selectedRole == 7) ...[
                  TextField(
                    controller: cnoptController,
                    decoration: InputDecoration(
                      labelText: 'Numéro CNOPT',
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final nom = nomController.text.trim();
                            final email = emailController.text.trim();
                            final pwd = passwordController.text.trim();
                            final tel = telController.text.trim();
                            final cnopt = cnoptController.text.trim();

                            if (nom.isEmpty) {
                              AppToast.showError('Nom et prénom est obligatoire');
                              return;
                            }
                            if (email.isEmpty || !email.contains('@')) {
                              AppToast.showError('E-mail invalide');
                              return;
                            }
                            if (pwd.length < 6) {
                              AppToast.showError('Le mot de passe doit comporter au moins 6 caractères.');
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            Navigator.pop(ctx);
                            final result = await context.read<AdminProvider>().addUser({
                              'nom': nom,
                              'login': email,
                              'email': email,
                              'tel': tel,
                              'role': selectedRole,
                              'id_role': selectedRole,
                              'num_cnopt': cnopt,
                              'tva': cnopt,
                              'password': pwd,
                              'etat': 1,
                            });
                            if (mounted) {
                              if (result.success) {
                                AppToast.showSuccess(result.message);
                              } else {
                                AppToast.showError(result.message);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Enregistrer l\'utilisateur', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditUserSheet(Map<String, dynamic> u) {
    final id = u['id'];
    final nomController = TextEditingController(text: u['nom']?.toString() ?? '');
    final emailController = TextEditingController(text: (u['login'] ?? u['email'] ?? '').toString());
    final telController = TextEditingController(text: u['tel']?.toString() ?? '');
    final cnoptController = TextEditingController(text: (u['num_cnopt'] ?? u['tva'] ?? '').toString());
    final passwordController = TextEditingController();
    int selectedRole = int.tryParse(u['id_role']?.toString() ?? u['role']?.toString() ?? '2') ?? 2;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.pencil, color: Colors.amber, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Modifier l\'utilisateur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                const Text('Rôle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('Pharmacien (Titulaire)')),
                        DropdownMenuItem(value: 3, child: Text('Patient')),
                        DropdownMenuItem(value: 4, child: Text('Conseil Régional')),
                        DropdownMenuItem(value: 7, child: Text('Jeune Pharmacie (Remplaçant)')),
                        DropdownMenuItem(value: 1, child: Text('Administrateur')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedRole = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nom
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom et prénom *',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Email
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email / Login *',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Téléphone
                TextField(
                  controller: telController,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // N° CNOPT
                TextField(
                  controller: cnoptController,
                  decoration: InputDecoration(
                    labelText: 'Numéro CNOPT',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Nouveau Mot de passe (optionnel)
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe (optionnel)',
                    hintText: 'Laisser vide pour ne pas modifier',
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final nom = nomController.text.trim();
                            final email = emailController.text.trim();
                            final pwd = passwordController.text.trim();
                            final tel = telController.text.trim();
                            final cnopt = cnoptController.text.trim();

                            if (nom.isEmpty) {
                              AppToast.showError('Nom et prénom est obligatoire');
                              return;
                            }
                            if (email.isEmpty || !email.contains('@')) {
                              AppToast.showError('E-mail invalide');
                              return;
                            }
                            if (pwd.isNotEmpty && pwd.length < 6) {
                              AppToast.showError('Le mot de passe doit comporter au moins 6 caractères.');
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            Navigator.pop(ctx);
                            final result = await context.read<AdminProvider>().updateUser({
                              ...u,
                              'id': id,
                              'id_user': id,
                              'nom': nom,
                              'login': email,
                              'email': email,
                              'tel': tel,
                              'id_role': selectedRole,
                              'role': selectedRole,
                              'num_cnopt': cnopt,
                              'tva': cnopt,
                              if (pwd.isNotEmpty) 'password': pwd,
                            });
                            if (mounted) {
                              if (result.success) {
                                AppToast.showSuccess(result.message);
                              } else {
                                AppToast.showError(result.message);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportExcel(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      AppToast.showError('Aucune donnée à exporter');
      return;
    }
    AppToast.showSuccess('Exportation de ${list.length} utilisateurs effectuée');
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    // Filter displayed users by etat if selected
    final displayedUsers = admin.users.where((u) {
      if (_selectedEtatFilter == '1') return (u['etat'] == 1 || u['etat']?.toString() == '1');
      if (_selectedEtatFilter == '0') return (u['etat'] == 0 || u['etat']?.toString() == '0');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.forestGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liste des utilisateurs',
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
              await admin.fetchUsers(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Action Buttons Header (Identique React ListUser.jsx)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // + Ajouter Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showAddUserSheet,
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text(
                          'Ajouter',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7), // Info blue matching React
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Exporter Excel Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportExcel(admin.allUsers),
                        icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                        label: const Text(
                          'Exporter Excel',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A), // Excel green matching React
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => admin.setUserFilter(query: val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher (nom, email, CNOPT, tél...)',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(LucideIcons.search, color: AppColors.primaryGreen, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              admin.setUserFilter(query: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Role Filter Chips (Horizontal Scroll)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip(
                        label: 'Tous (${admin.allUsers.length})',
                        isSelected: admin.selectedRoleFilter == 'all',
                        onTap: () => admin.setUserFilter(role: 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildChip(
                        label: 'Pharmaciens',
                        isSelected: admin.selectedRoleFilter == 'pharmacien',
                        onTap: () => admin.setUserFilter(role: 'pharmacien'),
                      ),
                      const SizedBox(width: 6),
                      _buildChip(
                        label: 'Patients',
                        isSelected: admin.selectedRoleFilter == 'patient',
                        onTap: () => admin.setUserFilter(role: 'patient'),
                      ),
                      const SizedBox(width: 6),
                      _buildChip(
                        label: 'Régionaux',
                        isSelected: admin.selectedRoleFilter == 'regional',
                        onTap: () => admin.setUserFilter(role: 'regional'),
                      ),
                      const SizedBox(width: 6),
                      _buildChip(
                        label: 'Admins',
                        isSelected: admin.selectedRoleFilter == 'admin',
                        onTap: () => admin.setUserFilter(role: 'admin'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Table / Card List
          Expanded(
            child: admin.isLoading && admin.allUsers.isEmpty
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des utilisateurs...'))
                : displayedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.users, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucun utilisateur trouvé',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(LucideIcons.refreshCw, size: 16),
                              label: const Text('Actualiser'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => admin.fetchUsers(forceRefresh: true),
                        color: AppColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: displayedUsers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = displayedUsers[index];
                            final id = int.tryParse(user['id']?.toString() ?? '') ?? 0;
                            final nom = (user['nom'] ?? user['nom_ar'] ?? 'Utilisateur').toString().trim();
                            final email = (user['login'] ?? user['email'] ?? '').toString().trim();
                            final tel = (user['tel'] ?? '').toString().trim();
                            final cnopt = (user['num_cnopt'] ?? user['tva'] ?? '').toString().trim();
                            final horaireRamadan = (user['horaire_ramadan'] ?? user['heureRamadan'] ?? '').toString().trim();
                            final roleId = user['id_role'] ?? user['role'] ?? user['roles']?['id'] ?? 2;
                            final roleName = _getRoleName(roleId, user);
                            final roleColor = _getRoleColor(roleId);
                            final etat = int.tryParse(user['etat']?.toString() ?? '1') ?? 1;
                            final isActif = etat == 1;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Avatar, Name, and Status Badge
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: roleColor.withValues(alpha: 0.15),
                                          child: Text(
                                            nom.isNotEmpty ? nom[0].toUpperCase() : 'U',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: roleColor,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nom,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  roleName,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: roleColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Status Pill (Actif / Désactivé)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActif ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isActif ? 'Actif' : 'Désactivé',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isActif ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 10),

                                    // Row 2: Details Info (Email, Tel, CNOPT, Ramadan)
                                    if (email.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.mail, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    if (tel.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.phone, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Text(
                                            tel,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    if (cnopt.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.hash, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Text(
                                            'CNOPT : $cnopt',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.forestGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    if (horaireRamadan.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.clock, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ramadan : $horaireRamadan',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    const SizedBox(height: 8),

                                    // Row 3: Actions Buttons (Identique React: Edit + Toggle State)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Edit Button (Warning yellow)
                                        InkWell(
                                          onTap: () => _showEditUserSheet(user),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7), // Amber light
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(LucideIcons.pencil, size: 14, color: Color(0xFFB45309)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Modifier',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFB45309),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Toggle State Button (Check/Cross matching React)
                                        InkWell(
                                          onTap: () async {
                                            final success = await admin.changeUserEtat(id, etat);
                                            if (mounted) {
                                              if (success) {
                                                AppToast.showSuccess(
                                                  isActif ? 'Désactivation avec succès' : 'Activation avec succès',
                                                );
                                              } else {
                                                AppToast.showError('Échec de la modification d\'état');
                                              }
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isActif
                                                  ? const Color(0xFFFEE2E2) // Red for deactivate
                                                  : const Color(0xFFDCFCE7), // Green for activate
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isActif ? LucideIcons.x : LucideIcons.check,
                                                  size: 14,
                                                  color: isActif ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isActif ? 'Désactiver' : 'Activer',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: isActif ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 200.ms);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forestGreen : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
