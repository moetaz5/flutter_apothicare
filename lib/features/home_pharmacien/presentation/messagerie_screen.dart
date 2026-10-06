import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/messagerie_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/wave_clipper.dart';

class MessagerieScreen extends StatefulWidget {
  const MessagerieScreen({super.key});

  @override
  State<MessagerieScreen> createState() => _MessagerieScreenState();
}

class _MessagerieScreenState extends State<MessagerieScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newChatSearchController = TextEditingController();
  String _searchQuery = '';
  String _newChatSearchQuery = '';
  MessagerieUser? _activeChatUser;
  final TextEditingController _msgInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  Timer? _pollingTimer;

  List<int> _historyIds = [];

  static const List<Color> _avatarColors = [
    Color(0xFFEAB308), // Yellow / Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFF22C55E), // Green
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF6366F1), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _historyIds = StorageService.getConversationHistoryIds();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });

    // Polling every 5 seconds for background sync
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final currentId = auth.currentUser?.id;
      if (currentId == null) return;

      final messagerie = context.read<MessagerieProvider>();
      if (_activeChatUser != null) {
        messagerie.fetchMessages(
          idSender: currentId,
          idReceiver: _activeChatUser!.id,
          silent: true,
        );
      } else {
        messagerie.fetchUnreadCounts(idReceiver: currentId);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    _newChatSearchController.dispose();
    _msgInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      context.read<MessagerieProvider>().fetchUsers(
            idGouvernorat: user.idGouvernorat,
            idUser: user.id,
          );
    }
  }

  void _openChat(MessagerieUser user) {
    // Add to history and move to top
    setState(() {
      _activeChatUser = user;
      _historyIds.remove(user.id);
      _historyIds.insert(0, user.id);
    });
    StorageService.saveConversationHistoryIds(_historyIds);

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser?.id != null) {
      context.read<MessagerieProvider>().fetchMessages(
            idSender: currentUser!.id!,
            idReceiver: user.id,
          );
    }
    _scrollToBottom();
  }

  void _closeChat() {
    setState(() => _activeChatUser = null);
    context.read<MessagerieProvider>().clearCurrentChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  PlatformFile? _selectedFile;
  XFile? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  void _clearAttachment() {
    setState(() {
      _selectedFile = null;
      _selectedImage = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
          _selectedFile = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _selectedImage = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _showAttachmentOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Joindre une pièce',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: LucideIcons.camera,
                  label: 'Appareil photo',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: LucideIcons.image,
                  label: 'Galerie photo',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  icon: LucideIcons.fileText,
                  label: 'Document',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocument();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgInputController.text.trim();
    final hasAttachment = _selectedImage != null || _selectedFile != null;
    if ((text.isEmpty && !hasAttachment) || _activeChatUser == null) return;

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser?.id == null) return;

    final targetUser = _activeChatUser!;
    _msgInputController.clear();

    String? filePath;
    List<int>? fileBytes;
    String? fileName;

    if (_selectedImage != null) {
      filePath = _selectedImage!.path;
      fileName = _selectedImage!.name;
    } else if (_selectedFile != null) {
      filePath = _selectedFile!.path;
      fileBytes = _selectedFile!.bytes;
      fileName = _selectedFile!.name;
    }

    _clearAttachment();

    // Ensure target is in history at the top
    setState(() {
      _historyIds.remove(targetUser.id);
      _historyIds.insert(0, targetUser.id);
    });
    StorageService.saveConversationHistoryIds(_historyIds);

    final ok = await context.read<MessagerieProvider>().sendMessage(
          idSender: currentUser!.id!,
          idReceiver: targetUser.id,
          content: text,
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        );

    if (ok) {
      _scrollToBottom();
    }
  }

  Color _getAvatarColor(int id, String name) {
    final hash = (id * 31 + (name.isNotEmpty ? name.codeUnitAt(0) : 0)).abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  void _showNewConversationModal(List<MessagerieUser> allUsers) {
    _newChatSearchController.clear();
    _newChatSearchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final filtered = allUsers.where((u) {
            if (_newChatSearchQuery.isEmpty) return true;
            return u.nom.toLowerCase().contains(_newChatSearchQuery.toLowerCase());
          }).toList()
            ..sort((a, b) => a.nom.compareTo(b.nom));

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // Modal Handle Bar
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouvelle conversation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sélectionnez un contact pour échanger',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(LucideIcons.x, color: Color(0xFF64748B)),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar inside Modal
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _newChatSearchController,
                      autofocus: false,
                      onChanged: (val) {
                        setModalState(() {
                          _newChatSearchQuery = val;
                        });
                      },
                      decoration: const InputDecoration(
                        icon: Icon(LucideIcons.search, color: Color(0xFF94A3B8), size: 18),
                        hintText: 'Rechercher un confrère, labo, CNOPT...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Contact list
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.searchX, size: 40, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 8),
                              Text('Aucun contact correspondant',
                                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                          itemBuilder: (c, i) {
                            final u = filtered[i];
                            final initial = u.nom.isNotEmpty ? u.nom[0].toUpperCase() : 'U';
                            final avatarBg = _getAvatarColor(u.id, u.nom);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: avatarBg,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                u.nom.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: u.login != null && u.login!.isNotEmpty
                                  ? Text(
                                      u.login!,
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                    )
                                  : null,
                              trailing: const Icon(LucideIcons.messageSquarePlus, size: 18, color: Color(0xFF3B82F6)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                _openChat(u);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.homePharmacien, (r) => false);
    } else if (index == 1) {
      Navigator.pushNamed(context, AppRoutes.actualites);
    } else if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.profile);
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();
    final messagerie = context.watch<MessagerieProvider>();

    final allUsers = messagerie.users;
    final unreadCounts = messagerie.unreadCounts;

    DateTime? parseDate(String? raw) {
      if (raw == null || raw.isEmpty || raw == 'null') return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        try {
          return DateTime.parse(raw.replaceAll(' ', 'T'));
        } catch (_) {}
      }
      return null;
    }

    // 1. Filter to ONLY conversations with messages (has lastMessageDate, lastMessage, unread count, or in history)
    final activeUsers = allUsers.where((u) {
      final hasLastDate = u.lastMessageDate != null &&
          u.lastMessageDate!.isNotEmpty &&
          u.lastMessageDate != 'null';
      final hasLastMsg = u.lastMessage != null &&
          u.lastMessage!.isNotEmpty &&
          u.lastMessage != 'null';
      final hasUnread = (unreadCounts[u.id] ?? 0) > 0;
      final inHistory = _historyIds.contains(u.id);

      return hasLastDate || hasLastMsg || hasUnread || inHistory;
    }).toList();

    // 2. Sort active conversations: unread first, latest message date first, then history order
    activeUsers.sort((a, b) {
      // Unread count priority
      final unreadA = unreadCounts[a.id] ?? 0;
      final unreadB = unreadCounts[b.id] ?? 0;
      if (unreadA != unreadB && (unreadA > 0 || unreadB > 0)) {
        return unreadB.compareTo(unreadA);
      }

      // Date priority (most recent first)
      final dateA = parseDate(a.lastMessageDate);
      final dateB = parseDate(b.lastMessageDate);

      if (dateA != null && dateB != null) {
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }

      // History priority
      final idxA = _historyIds.indexOf(a.id);
      final idxB = _historyIds.indexOf(b.id);
      if (idxA != -1 && idxB != -1) {
        return idxA.compareTo(idxB);
      } else if (idxA != -1) {
        return -1;
      } else if (idxB != -1) {
        return 1;
      }

      return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    });

    // 3. Apply search query on active conversations
    final displayConversations = activeUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.nom.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: _activeChatUser != null
          ? _buildChatView(topPadding, auth.currentUser?.id ?? 0, messagerie)
          : _buildConversationListView(topPadding, messagerie, allUsers, displayConversations, unreadCounts),
      bottomNavigationBar: _activeChatUser == null
          ? AppBottomNavBar(
              currentIndex: 0,
              notifCount: auth.unreadNotifications,
              onTap: _onBottomNavTapped,
            )
          : null,
    );
  }

  Widget _buildConversationListView(
    double topPadding,
    MessagerieProvider messagerie,
    List<MessagerieUser> allUsers,
    List<MessagerieUser> conversations,
    Map<int, int> unreadCounts,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ─── HERO HEADER ───
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: AssetImage('assets/images/back-mobile.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.16,
                scale: 1.5,
              ),
            ),
            child: Stack(
              children: [
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
                Padding(
                  padding: EdgeInsets.only(top: topPadding + 14, bottom: 26, left: 18, right: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar: Back & Add Conversation Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: const Color(0xFF70BA8E), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.undo2, size: 15, color: Color(0xFF22C55E)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Retour',
                                    style: TextStyle(
                                      color: Color(0xFF22C55E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // + Button
                          InkWell(
                            onTap: () => _showNewConversationModal(allUsers),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.plus, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Nouveau',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Messagerie directe',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B6A3A),
                                ),
                              ),
                              Text(
                                'Discussions actives',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forestGreen,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: const Size(double.infinity, 20),
                    painter: WavePainter(),
                  ),
                ),
              ],
            ),
          ),

          // ─── ACTIVE CONVERSATIONS CARD ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Card Header: CONVERSATIONS + Search
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.messagesSquare, size: 18, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            Text(
                              'CONVERSATIONS (${conversations.length})',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (messagerie.isLoadingUsers) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (messagerie.totalUnreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${messagerie.totalUnreadCount} non lus',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              icon: Icon(LucideIcons.search, color: Color(0xFF94A3B8), size: 18),
                              hintText: 'Filtrer mes conversations...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loading State
                  if (messagerie.isLoadingUsers && conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Chargement des discussions...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Empty State
                  else if (conversations.isEmpty && !messagerie.isLoadingUsers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.messageSquarePlus, size: 28, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Aucune conversation récente',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Appuyez sur le bouton "+" pour démarrer un échange avec un confrère ou partenaire.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => _showNewConversationModal(allUsers),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Démarrer une discussion', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: conversations.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64),
                      itemBuilder: (ctx, i) {
                        final u = conversations[i];
                        final unread = unreadCounts[u.id] ?? 0;
                        final initial = u.nom.isNotEmpty ? u.nom[0].toUpperCase() : 'U';
                        final avatarBg = _getAvatarColor(u.id, u.nom);

                        return InkWell(
                          onTap: () => _openChat(u),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: unread > 0 ? const Color(0xFFEFF6FF) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                // Avatar circle with initial
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: avatarBg,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: avatarBg.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Name and subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              u.nom.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                                                color: const Color(0xFF1E293B),
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (u.lastMessageDate != null &&
                                              u.lastMessageDate!.isNotEmpty &&
                                              u.lastMessageDate != 'null') ...[
                                            Builder(builder: (_) {
                                              String timeLabel = '';
                                              try {
                                                final dt = DateTime.parse(u.lastMessageDate!);
                                                final now = DateTime.now();
                                                if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                                                  timeLabel = DateFormat('HH:mm').format(dt);
                                                } else {
                                                  timeLabel = DateFormat('d MMM', 'fr_FR').format(dt);
                                                }
                                              } catch (_) {}
                                              if (timeLabel.isEmpty) return const SizedBox.shrink();
                                              return Text(
                                                timeLabel,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                                  color: unread > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (u.lastMessage != null && u.lastMessage!.isNotEmpty && u.lastMessage != 'null')
                                                  ? u.lastMessage!
                                                  : (unread > 0
                                                      ? '$unread message(s) non lu(s)'
                                                      : 'Appuyez pour ouvrir la discussion'),
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                                color: unread > 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (unread > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                unread > 99 ? '99+' : unread.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 250.ms, delay: (i * 25).ms)
                            .slideY(begin: 0.04, end: 0);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CHAT VIEW SCREEN ───
  Widget _buildChatView(double topPadding, int currentUserId, MessagerieProvider messagerie) {
    final messages = messagerie.currentMessages;
    final user = _activeChatUser!;
    final avatarBg = _getAvatarColor(user.id, user.nom);
    final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : 'U';

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        // Chat Header
        Container(
          padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeChat,
                icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nom.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Row(
                      children: [
                        Icon(LucideIcons.circle, size: 8, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text(
                          'En ligne',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Message Thread
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: messagerie.isLoadingMessages
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des messages...'))
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.messagesSquare, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text(
                              'Démarrez la conversation avec ${user.nom}',
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = messages[i];
                          final isMe = msg.idSender == currentUserId;
                          final timeStr = DateFormat('HH:mm').format(msg.createdAt);

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isMe ? null : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMe ? 'Moi' : user.nom,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isMe ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  _buildMessageAttachment(msg, isMe),
                                  if (msg.content.trim().isNotEmpty) ...[
                                    Text(
                                      msg.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe ? Colors.white : const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          msg.lu == 1 ? LucideIcons.checkCheck : LucideIcons.check,
                                          size: 13,
                                          color: msg.lu == 1 ? const Color(0xFF86EFAC) : Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),

        // Attachment Preview Banner if any selected
        if (_selectedImage != null || _selectedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border(
                top: BorderSide(color: Colors.blue.shade100),
                bottom: BorderSide(color: Colors.blue.shade100),
              ),
            ),
            child: Row(
              children: [
                if (_selectedImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImage!.path),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo sélectionnée',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          _selectedImage!.name,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedFile != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.fileText, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document sélectionné',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          _selectedFile!.name,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFFEF4444)),
                  onPressed: _clearAttachment,
                  splashRadius: 18,
                  tooltip: 'Supprimer la pièce jointe',
                ),
              ],
            ),
          ),

        // Message Input Field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: _showAttachmentOptionsModal,
                  icon: const Icon(LucideIcons.paperclip, color: Color(0xFF64748B), size: 22),
                  splashRadius: 22,
                  tooltip: 'Joindre un fichier ou photo',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _msgInputController,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: messagerie.isSending
                        ? const Center(
                            child: AppLoadingIndicator.small(color: Colors.white, size: 18),
                          )
                        : const Icon(LucideIcons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageAttachment(ChatMessage msg, bool isMe) {
    // 1. If it's a local file just sent optimistically
    if (msg.localPath != null || msg.localBytes != null) {
      final name = msg.fileUrl ?? msg.localPath ?? 'Fichier';
      final ext = name.split('.').last.toLowerCase();
      final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);

      if (isImg) {
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black12,
          ),
          clipBehavior: Clip.antiAlias,
          child: msg.localPath != null
              ? Image.file(File(msg.localPath!), fit: BoxFit.cover)
              : Image.memory(Uint8List.fromList(msg.localBytes!), fit: BoxFit.cover),
        );
      } else {
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isMe ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(ext),
                size: 22,
                color: isMe ? Colors.white : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name.split(RegExp(r'[/\\]')).last,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
    }

    if (msg.fileUrl == null || msg.fileUrl!.isEmpty || msg.fileUrl == 'null') {
      return const SizedBox.shrink();
    }

    final rawPath = msg.fileUrl!;
    final String fullUrl;
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      fullUrl = rawPath;
    } else if (rawPath.startsWith('/')) {
      fullUrl = '${AppConstants.backBaseUrl.replaceAll(RegExp(r'/+$'), '')}$rawPath';
    } else {
      fullUrl = '${AppConstants.backBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$rawPath';
    }

    final fileName = rawPath.split('/').last.split('\\').last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);

    if (isImg) {
      return GestureDetector(
        onTap: () => _openUrl(fullUrl),
        child: Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black12,
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, _) => Container(
              height: 140,
              width: 200,
              color: const Color(0xFFE2E8F0),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
              ),
            ),
            errorWidget: (ctx, _, __) => Container(
              height: 80,
              width: 140,
              color: const Color(0xFFE2E8F0),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.imageOff, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openUrl(fullUrl),
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(ext),
              size: 22,
              color: isMe ? Colors.white : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Appuyer pour ouvrir',
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.download,
              size: 16,
              color: isMe ? Colors.white70 : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'doc':
      case 'docx':
        return LucideIcons.fileText;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return LucideIcons.fileSpreadsheet;
      case 'zip':
      case 'rar':
      case '7z':
        return LucideIcons.fileArchive;
      default:
        return LucideIcons.file;
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }
}
