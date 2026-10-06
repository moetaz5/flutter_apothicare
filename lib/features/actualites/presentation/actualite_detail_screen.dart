import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/actualite_model.dart';
import '../../../core/providers/actualite_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/wave_clipper.dart';

class ActualiteDetailScreen extends StatefulWidget {
  final ActualiteModel actualite;
  final String themeName;

  const ActualiteDetailScreen({
    super.key,
    required this.actualite,
    required this.themeName,
  });

  @override
  State<ActualiteDetailScreen> createState() => _ActualiteDetailScreenState();
}

class _ActualiteDetailScreenState extends State<ActualiteDetailScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
    _trackView();
  }

  void _trackView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.actualite.id != null) {
        final auth = context.read<AuthProvider>();
        context.read<ActualiteProvider>().addVue(
              id: widget.actualite.id!,
              idUser: auth.currentUser?.id,
            );
      }
    });
  }

  void _initVideoPlayer() {
    final videoFileName = widget.actualite.video;
    if (videoFileName == null || videoFileName.trim().isEmpty) return;

    final videoUrl = videoFileName.startsWith('http')
        ? videoFileName
        : '${AppConstants.backBaseUrl}uploads/$videoFileName';

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
            _hasVideoError = true;
          });
        }
      });

    _videoController?.addListener(() {
      if (mounted && _videoController != null) {
        final isPlaying = _videoController!.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return dateStr;
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) {
        final years = (diff.inDays / 365).floor();
        return 'Il y a $years an${years > 1 ? 's' : ''}';
      } else if (diff.inDays > 30) {
        final months = (diff.inDays / 30).floor();
        return 'Il y a $months mois';
      } else if (diff.inDays > 0) {
        return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
      } else if (diff.inHours > 0) {
        return 'Il y a ${diff.inHours} h';
      } else if (diff.inMinutes > 0) {
        return 'Il y a ${diff.inMinutes} min';
      } else {
        return "À l'instant";
      }
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final title = widget.actualite.titre ?? '';
    final desc = widget.actualite.description ?? '';
    final dateFormatted = _formatDate(widget.actualite.createdAt);
    final hasVideo = widget.actualite.video != null && widget.actualite.video!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    padding: EdgeInsets.only(
                      top: topPadding + 14,
                      bottom: 26,
                      left: 18,
                      right: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
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
                        ),
                        const SizedBox(height: 10),

                        // Green Newspaper Icon Badge
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_green, _greenDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withValues(alpha: 0.40),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.newspaper, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text(
                          "Détails de l'actualité",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 22),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── CARD DETAILS ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Media Image
                    if (widget.actualite.image != null && widget.actualite.image!.trim().isNotEmpty)
                      Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: '${AppConstants.backBaseUrl}uploads/${widget.actualite.image}',
                            width: double.infinity,
                            height: 240,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              height: 240,
                              color: const Color(0xFFE9EDF4),
                              child: const Center(
                                child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.themeName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theme badge if no image
                          if (widget.actualite.image == null || widget.actualite.image!.trim().isEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                widget.themeName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),

                          // Date Row
                          if (dateFormatted.isNotEmpty)
                            Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 14, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 6),
                                Text(
                                  dateFormatted,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ─── VIDEO SECTION (Identique à la version React) ───
                          if (hasVideo) ...[
                            const Row(
                              children: [
                                Icon(LucideIcons.video, size: 18, color: AppColors.primaryGreen),
                                SizedBox(width: 8),
                                Text(
                                  'Vidéo :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildVideoPlayer(),
                            const SizedBox(height: 20),
                          ],

                          // Divider
                          Container(height: 1, color: const Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          // Description
                          if (desc.isNotEmpty) ...[
                            const Text(
                              'Description :',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.forestGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF374151),
                                height: 1.7,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasVideoError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.videoOff, size: 36, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Impossible de charger la vidéo',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              SizedBox(height: 10),
              Text(
                'Chargement de la vidéo...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final duration = _videoController!.value.duration;
    final position = _videoController!.value.position;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Video viewport
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio > 0
                ? _videoController!.value.aspectRatio
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_videoController!),
                // Center Play/Pause Overlay Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 0.9,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? LucideIcons.pause : LucideIcons.play,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                // Progress Slider
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primaryGreen,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        _isPlaying ? LucideIcons.pause : LucideIcons.play,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                    ),

                    // Time display
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),

                    const Spacer(),

                    // Mute/Unmute
                    IconButton(
                      icon: Icon(
                        _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
