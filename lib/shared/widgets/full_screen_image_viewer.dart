import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title = '',
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
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
      _resetZoom();
    } else {
      final pos = _doubleTapDetails?.localPosition;
      if (pos != null) {
        _transformationController.value = Matrix4.identity()
          ..translateByDouble(-pos.dx * 1.5, -pos.dy * 1.5, 0.0, 1.0)
          ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      } else {
        _transformationController.value = Matrix4.identity()
          ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      }
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
          tooltip: 'Fermer',
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

          // Bottom floating controls pill (Responsive with SafeArea for devices with system navigation bars)
          Positioned(
            bottom: 0,
            left: 20,
            right: 20,
            child: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
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
            ),
          ),
        ],
      ),
    );
  }
}

