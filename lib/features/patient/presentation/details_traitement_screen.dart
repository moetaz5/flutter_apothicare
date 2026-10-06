import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/traitement_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';

class DetailsTraitementScreen extends StatefulWidget {
  final dynamic traitement;
  final dynamic traitementId;

  const DetailsTraitementScreen({
    super.key,
    this.traitement,
    this.traitementId,
  });

  @override
  State<DetailsTraitementScreen> createState() => _DetailsTraitementScreenState();
}

class _DetailsTraitementScreenState extends State<DetailsTraitementScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  Map<String, dynamic>? _traitementData;
  bool _isLoading = true;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.traitement is Map<String, dynamic>) {
      _traitementData = Map<String, dynamic>.from(widget.traitement);
      _isLoading = false;
      _initVideoIfAvailable();
      setState(() {});
    } else if (widget.traitement is Map) {
      _traitementData = Map<String, dynamic>.from(widget.traitement);
      _isLoading = false;
      _initVideoIfAvailable();
      setState(() {});
    }

    final id = widget.traitementId ?? _traitementData?['id'];
    if (id != null) {
      final fresh = await context.read<TraitementProvider>().getTraitementById(id);
      if (fresh != null && mounted) {
        setState(() {
          _traitementData = fresh;
          _isLoading = false;
        });
        _initVideoIfAvailable();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _initVideoIfAvailable() {
    final videoFileName = _traitementData?['video']?.toString();
    if (videoFileName == null || videoFileName.trim().isEmpty) return;

    final videoUrl = '${AppConstants.backBaseUrl}uploads/$videoFileName';

    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
          });
        }
      });

    _videoController?.addListener(() {
      if (mounted) {
        final isPlayingNow = _videoController?.value.isPlaying ?? false;
        if (isPlayingNow != _isPlaying) {
          setState(() {
            _isPlaying = isPlayingNow;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _openFullScreenVideo() {
    if (_videoController == null || !_isVideoInitialized) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _FullScreenVideoViewer(controller: _videoController!),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.actualites);
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
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
    final auth = context.watch<AuthProvider>();
    final topPadding = MediaQuery.of(context).padding.top;
    final item = _traitementData;

    final nom = item?['nom']?.toString() ?? 'Traitement';
    final doctor = item?['doctor']?.toString();
    final date = item?['date']?.toString();
    final categoryName = item?['categories'] is Map ? item!['categories']['nom']?.toString() : null;
    final description = item?['description']?.toString() ?? item?['texte']?.toString();

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER SECTION (Exact React design) ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 36),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/back-mobile.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.18,
                  scale: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF4F9F1),
                    Color(0xFFEAF5E5),
                    Color(0xFFE2EFE0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Retour button
                  Align(
                    alignment: Alignment.topLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _green, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.undo2, size: 14, color: _green),
                            SizedBox(width: 6),
                            Text(
                              'Retour',
                              style: TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Hero Icon Badge
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_green, _greenDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.video, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  const Text(
                    'Détails du traitement',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B6A3A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ─── BODY SECTION ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: _green),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card: Détails du traitement
                        Container(
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
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category badge if exists
                                if (categoryName != null && categoryName.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      categoryName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Désignation
                                const Text(
                                  'DÉSIGNATION',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  nom,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
                                ),
                                const SizedBox(height: 14),

                                // Doctor & Date Row
                                Row(
                                  children: [
                                    if (doctor != null && doctor.isNotEmpty) ...[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'MÉDECIN',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Dr. $doctor',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _greenDark),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (date != null && date.isNotEmpty) ...[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'DATE',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              date,
                                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 18),
                                const Divider(color: Color(0xFFF3F4F6)),
                                const SizedBox(height: 14),

                                // ─── VIDEO PLAYER SECTION ───
                                const Text(
                                  'VIDÉO ÉDUCATIVE',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
                                ),
                                const SizedBox(height: 10),

                                if (item?['video'] != null && item!['video'].toString().trim().isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      height: 240,
                                      color: const Color(0xFF0D1F3C),
                                      child: _isVideoInitialized && _videoController != null
                                          ? GestureDetector(
                                              onTap: () => setState(() => _showControls = !_showControls),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Center(
                                                    child: AspectRatio(
                                                      aspectRatio: _videoController!.value.aspectRatio,
                                                      child: VideoPlayer(_videoController!),
                                                    ),
                                                  ),

                                                  // Controls overlay
                                                  if (_showControls) ...[
                                                    Container(
                                                      color: Colors.black38,
                                                    ),

                                                    // Center Play / Pause
                                                    IconButton(
                                                      iconSize: 52,
                                                      icon: Icon(
                                                        _isPlaying ? LucideIcons.pauseCircle : LucideIcons.playCircle,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          if (_isPlaying) {
                                                            _videoController!.pause();
                                                          } else {
                                                            _videoController!.play();
                                                          }
                                                        });
                                                      },
                                                    ),

                                                    // Bottom bar with slider & fullscreen
                                                    Positioned(
                                                      bottom: 8,
                                                      left: 12,
                                                      right: 12,
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          VideoProgressIndicator(
                                                            _videoController!,
                                                            allowScrubbing: true,
                                                            colors: const VideoProgressColors(
                                                              playedColor: _green,
                                                              bufferedColor: Colors.white24,
                                                              backgroundColor: Colors.white12,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              ValueListenableBuilder(
                                                                valueListenable: _videoController!,
                                                                builder: (context, VideoPlayerValue value, _) {
                                                                  return Text(
                                                                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                                  );
                                                                },
                                                              ),
                                                              Row(
                                                                children: [
                                                                  // Mute / Unmute
                                                                  InkWell(
                                                                    onTap: () {
                                                                      setState(() {
                                                                        _isMuted = !_isMuted;
                                                                        _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
                                                                      });
                                                                    },
                                                                    child: Icon(
                                                                      _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                                                                      color: Colors.white,
                                                                      size: 18,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 14),

                                                                  // Fullscreen enlarge button
                                                                  InkWell(
                                                                    onTap: _openFullScreenVideo,
                                                                    child: const Icon(
                                                                      LucideIcons.maximize2,
                                                                      color: Colors.white,
                                                                      size: 18,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(color: _green),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Chargement de la vidéo…',
                                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Grandir la vidéo Button
                                  if (_isVideoInitialized && _videoController != null)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _openFullScreenVideo,
                                        icon: const Icon(LucideIcons.maximize2, size: 16, color: _green),
                                        label: const Text(
                                          'Agrandir la vidéo en plein écran',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: _green, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 36),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(LucideIcons.videoOff, size: 32, color: Color(0xFF9CA3AF)),
                                        SizedBox(height: 8),
                                        Text('Aucune vidéo associée à ce traitement', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],

                                // Description
                                if (description != null && description.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'DESCRIPTION & RECOMMANDATIONS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.6),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.6),
                                  ),
                                ],

                                const SizedBox(height: 24),

                                // Action: Quiz Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.quizTraitement,
                                        arguments: item,
                                      );
                                    },
                                    icon: const Icon(LucideIcons.helpCircle, size: 18),
                                    label: const Text(
                                      'Passer le Quiz de ce traitement',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA580C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 3,
                                      shadowColor: const Color(0xFFEA580C).withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }
}

// ─── FULLSCREEN VIDEO VIEWER ───
class _FullScreenVideoViewer extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullScreenVideoViewer({required this.controller});

  @override
  State<_FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<_FullScreenVideoViewer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            if (_showControls) ...[
              Container(color: Colors.black45),

              // Close / Back button
              Positioned(
                top: 36,
                left: 20,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(LucideIcons.x, color: Colors.white, size: 22),
                  ),
                ),
              ),

              // Center Play / Pause
              IconButton(
                iconSize: 64,
                icon: Icon(
                  widget.controller.value.isPlaying ? LucideIcons.pauseCircle : LucideIcons.playCircle,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (widget.controller.value.isPlaying) {
                      widget.controller.pause();
                    } else {
                      widget.controller.play();
                    }
                  });
                },
              ),

              // Bottom timeline
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      widget.controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF71A246),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: widget.controller,
                          builder: (context, VideoPlayerValue value, _) {
                            String twoDigits(int n) => n.toString().padLeft(2, '0');
                            final pos = '${twoDigits(value.position.inMinutes.remainder(60))}:${twoDigits(value.position.inSeconds.remainder(60))}';
                            final dur = '${twoDigits(value.duration.inMinutes.remainder(60))}:${twoDigits(value.duration.inSeconds.remainder(60))}';
                            return Text('$pos / $dur', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
                          },
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(LucideIcons.minimize2, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
