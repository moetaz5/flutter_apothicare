import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';

class FullScreenVideoViewer extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;

  const FullScreenVideoViewer({
    super.key,
    required this.controller,
    this.title = '',
  });

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isLandscape = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Enable sticky immersive mode (hides system status bar and nav bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Allow auto-rotation between portrait and landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    _isMuted = widget.controller.value.volume == 0;
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    if (widget.controller.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && widget.controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _togglePlay() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _hideControlsTimer?.cancel();
        _showControls = true;
      } else {
        widget.controller.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    final currentPos = widget.controller.value.position;
    final target = currentPos + Duration(seconds: seconds);
    final duration = widget.controller.value.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    widget.controller.seekTo(clamped);
    _startHideTimer();
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      setState(() {
        _isLandscape = false;
      });
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() {
        _isLandscape = true;
      });
    }
    _startHideTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    // Restore portrait mode and standard system UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.title.trim().isNotEmpty;
    final isPlaying = widget.controller.value.isPlaying;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // ─── VIDEO FRAME ───
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio > 0
                      ? widget.controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(widget.controller),
                ),
              ),

              // ─── CONTROLS OVERLAY ───
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: [0.0, 0.25, 0.75, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // ─── TOP BAR ───
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Back Button
                                  InkWell(
                                    onTap: () => Navigator.pop(context),
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title
                                  Expanded(
                                    child: Text(
                                      hasTitle ? widget.title : 'Lecture vidéo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Orientation Toggle (Landscape / Portrait)
                                  InkWell(
                                    onTap: _toggleOrientation,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isLandscape ? LucideIcons.smartphone : LucideIcons.screenShare,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isLandscape ? 'Portrait' : 'Paysage',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ─── CENTER ACTION BUTTONS (-10s, PLAY/PAUSE, +10s) ───
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Seek -10s
                              InkWell(
                                onTap: () => _seekRelative(-10),
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 1),
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.rotateCcw, color: Colors.white, size: 26),
                                      SizedBox(height: 2),
                                      Text(
                                        '10s',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),

                              // Play / Pause Circle
                              GestureDetector(
                                onTap: _togglePlay,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.92),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ValueListenableBuilder<VideoPlayerValue>(
                                    valueListenable: widget.controller,
                                    builder: (context, value, _) {
                                      return Icon(
                                        value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                                        color: Colors.white,
                                        size: 34,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),

                              // Seek +10s
                              InkWell(
                                onTap: () => _seekRelative(10),
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 1),
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.rotateCw, color: Colors.white, size: 26),
                                      SizedBox(height: 2),
                                      Text(
                                        '10s',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ─── BOTTOM CONTROLS BAR ───
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Scrubbable Progress Bar
                                  VideoProgressIndicator(
                                    widget.controller,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    colors: const VideoProgressColors(
                                      playedColor: AppColors.primaryGreen,
                                      bufferedColor: Colors.white30,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Bottom Row with Timers, Mute, Minimize
                                  Row(
                                    children: [
                                      // Position / Duration
                                      ValueListenableBuilder<VideoPlayerValue>(
                                        valueListenable: widget.controller,
                                        builder: (context, value, _) {
                                          return Text(
                                            '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          );
                                        },
                                      ),

                                      const Spacer(),

                                      // Volume Mute / Unmute
                                      IconButton(
                                        tooltip: _isMuted ? 'Activer le son' : 'Couper le son',
                                        icon: Icon(
                                          _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: _toggleMute,
                                      ),
                                      const SizedBox(width: 4),

                                      // Minimize / Exit Fullscreen Button
                                      IconButton(
                                        tooltip: 'Quitter le plein écran',
                                        icon: const Icon(
                                          LucideIcons.minimize2,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}
