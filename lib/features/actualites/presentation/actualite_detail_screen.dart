import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/actualite_model.dart';
import '../../../core/providers/actualite_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
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

class _ActualiteDetailScreenState extends State<ActualiteDetailScreen> with RouteAware {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _pauseVideo();
    super.didPushNext();
  }

  @override
  void didPop() {
    _pauseVideo();
    super.didPop();
  }

  void _pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
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
    routeObserver.unsubscribe(this);
    try {
      _videoController?.pause();
      _videoController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _openImageFullScreen(BuildContext context, String imageUrl, String title) {
    if (imageUrl.toLowerCase().endsWith('.pdf')) {
      _openExternalUrl(imageUrl);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _FullScreenImageViewer(
          imageUrl: imageUrl,
          title: title,
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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

    final imageFile = widget.actualite.image?.trim();
    final hasImage = imageFile != null && imageFile.isNotEmpty;
    final imageUrl = hasImage
        ? (imageFile.startsWith('http')
            ? imageFile
            : '${AppConstants.backBaseUrl}uploads/$imageFile')
        : '';
    final isImagePdf = hasImage && imageFile.toLowerCase().endsWith('.pdf');

    final attachedFile = widget.actualite.file?.trim();
    final hasAttachedFile = attachedFile != null && attachedFile.isNotEmpty;
    final attachedFileUrl = hasAttachedFile
        ? (attachedFile.startsWith('http')
            ? attachedFile
            : '${AppConstants.backBaseUrl}uploads/$attachedFile')
        : '';

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
                            onTap: () {
                              _pauseVideo();
                              Navigator.pop(context);
                            },
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
                    // Media Image / Document
                    if (hasImage)
                      if (isImagePdf)
                        InkWell(
                          onTap: () => _openExternalUrl(imageUrl),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(LucideIcons.fileText, color: Color(0xFFDC2626), size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DOCUMENT PDF OFFICIEL',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFDC2626),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        imageFile,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Appuyer pour ouvrir le document',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.externalLink, color: Color(0xFFDC2626), size: 20),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _openImageFullScreen(context, imageUrl, title),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(
                                  height: 260,
                                  color: const Color(0xFFE9EDF4),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 180,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: Icon(LucideIcons.imageOff, color: Color(0xFF9CA3AF), size: 36),
                                  ),
                                ),
                              ),

                              // Theme badge
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

                              // Expand / Zoom affordance pill button
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF163820).withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.maximize2, color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Agrandir le document',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                          // Attached Document Section
                          if (hasAttachedFile) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Document associé :',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.forestGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                final isImg = attachedFileUrl.toLowerCase().endsWith('.png') ||
                                    attachedFileUrl.toLowerCase().endsWith('.jpg') ||
                                    attachedFileUrl.toLowerCase().endsWith('.jpeg') ||
                                    attachedFileUrl.toLowerCase().endsWith('.webp');
                                if (isImg) {
                                  _openImageFullScreen(context, attachedFileUrl, title);
                                } else {
                                  _openExternalUrl(attachedFileUrl);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(LucideIcons.fileText, color: AppColors.primaryGreen, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'DOCUMENT JOINT',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF15803D),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            attachedFile,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.eye, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Visualiser',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

// ─── FULLSCREEN IMAGE & DOCUMENT VIEWER ───
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.title,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < 6.0) {
      _transformationController.value = Matrix4.copy(_transformationController.value)
        ..scaleByDouble(1.4, 1.4, 1.0, 1.0);
    }
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 0.7) {
      _transformationController.value = Matrix4.copy(_transformationController.value)
        ..scaleByDouble(0.7, 0.7, 1.0, 1.0);
    }
  }

  Future<void> _openExternal() async {
    try {
      final uri = Uri.parse(widget.imageUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title.isNotEmpty ? widget.title : 'Visualisation du document',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Ouvrir en externe / Télécharger',
            icon: const Icon(LucideIcons.externalLink, color: Colors.white),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: SizedBox.expand(
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 6.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryGreen),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Impossible de charger l\'image en direct',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _openExternal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(LucideIcons.externalLink, size: 16),
                              label: const Text('Ouvrir dans le navigateur'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom floating controls pill
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Dézoomer',
                      icon: const Icon(LucideIcons.zoomOut, color: Colors.white, size: 19),
                      onPressed: _zoomOut,
                      visualDensity: VisualDensity.compact,
                    ),
                    InkWell(
                      onTap: _resetZoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '100%',
                          style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zoomer',
                      icon: const Icon(LucideIcons.zoomIn, color: Colors.white, size: 19),
                      onPressed: _zoomIn,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Container(height: 18, width: 1, color: Colors.white24),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Ouvrir le fichier original',
                      icon: const Icon(LucideIcons.download, color: Colors.white, size: 19),
                      onPressed: _openExternal,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

