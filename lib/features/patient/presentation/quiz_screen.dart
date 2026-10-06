import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/traitement_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';

class QuizScreen extends StatefulWidget {
  final dynamic traitement;
  final dynamic traitementId;

  const QuizScreen({
    super.key,
    this.traitement,
    this.traitementId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  Map<String, dynamic>? _traitement;
  bool _isLoading = true;

  int _currentQuestion = 0;
  int? _selectedResponseIndex;
  int _score = 0;
  bool _quizFinished = false;

  int _durationMinutes = 0;
  int _timeLeftSeconds = 0;
  Timer? _timer;

  bool _isSubmitting = false;

  static const List<String> _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    final id = widget.traitementId ?? (widget.traitement is Map ? widget.traitement['id'] : null);

    if (id != null) {
      final data = await context.read<TraitementProvider>().getTraitementById(id);
      if (data != null && mounted) {
        _traitement = data;
      } else if (widget.traitement is Map<String, dynamic>) {
        _traitement = Map<String, dynamic>.from(widget.traitement);
      }
    } else if (widget.traitement is Map<String, dynamic>) {
      _traitement = Map<String, dynamic>.from(widget.traitement);
    }

    if (mounted) {
      final duree = _traitement?['temps_quiz'] ?? 0;
      _durationMinutes = int.tryParse(duree.toString()) ?? 0;
      if (_durationMinutes > 0) {
        _timeLeftSeconds = _durationMinutes * 60;
        _startTimer();
      }
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftSeconds > 0) {
        setState(() {
          _timeLeftSeconds--;
        });
        if (_timeLeftSeconds == 0) {
          timer.cancel();
          _sendResponse(_score, type: 1);
          setState(() {
            _quizFinished = true;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<dynamic> get _questions {
    if (_traitement != null && _traitement!['questions'] is List) {
      return _traitement!['questions'] as List;
    }
    return [];
  }

  void _handleNext() {
    final questions = _questions;
    if (_currentQuestion >= questions.length || _selectedResponseIndex == null) return;

    final q = questions[_currentQuestion];
    final responses = q['reponses'] is List ? q['reponses'] as List : [];

    bool isCorrect = false;
    if (_selectedResponseIndex! < responses.length) {
      final rep = responses[_selectedResponseIndex!];
      isCorrect = rep['vrai'] == true || rep['vrai'] == 1 || rep['vrai']?.toString() == 'true' || rep['vrai']?.toString() == '1';
    }

    final newScore = isCorrect ? _score + 1 : _score;

    if (_currentQuestion < questions.length - 1) {
      setState(() {
        _score = newScore;
        _currentQuestion++;
        _selectedResponseIndex = null;
      });
    } else {
      _timer?.cancel();
      setState(() {
        _score = newScore;
        _quizFinished = true;
      });
      _sendResponse(newScore, type: 1);
    }
  }

  Future<void> _sendResponse(int finalScore, {int type = 1}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    final auth = context.read<AuthProvider>();
    final patientId = auth.currentUser?.id;
    final traitementId = _traitement?['id'] ?? widget.traitementId;

    if (patientId != null && traitementId != null) {
      await context.read<TraitementProvider>().sendQuizResponse(
            patientId: patientId,
            point: finalScore == 5 ? 1 : 0,
            traitementId: traitementId,
          );
    }

    _isSubmitting = false;
  }

  void _confirmLeave() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFEF08A), Color(0xFFFBBF24)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quitter le quiz ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vos réponses actuelles seront soumises et vous ne pourrez plus revenir à cette question.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _timer?.cancel();
                    _sendResponse(_score, type: 2);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Oui, soumettre et quitter', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: const Color(0xFF374151),
                  ),
                  child: const Text('Non, continuer le quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reloadQuiz() {
    setState(() {
      _currentQuestion = 0;
      _selectedResponseIndex = null;
      _score = 0;
      _quizFinished = false;
      if (_durationMinutes > 0) {
        _timeLeftSeconds = _durationMinutes * 60;
        _startTimer();
      }
    });
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
    final questions = _questions;

    // ─── RESULTS SCREEN (Exact React qz-results-root) ───
    if (_quizFinished && _traitement != null) {
      return Scaffold(
        backgroundColor: _bgGrey,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Hero Results Banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, Color(0xFF0F2916)],
                  ),
                ),
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    const Text(
                      'Bravo !',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Vous avez terminé le quiz',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),

                    // Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_score / ${questions.length}',
                            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'BONNES RÉPONSES',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border(left: BorderSide(color: _green, width: 4)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF244082).withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '💚 Continuez à vous informer pour mieux comprendre votre santé et améliorer votre observance.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF4B6A3A), fontWeight: FontWeight.w600, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rejouer le quiz Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _reloadQuiz,
                        icon: const Icon(LucideIcons.rotateCcw, size: 18),
                        label: const Text('Rejouer le quiz', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                          shadowColor: _green.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Retour aux traitements Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.reply, size: 18),
                        label: const Text('Retour aux traitements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
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

    // ─── MAIN QUIZ VIEW ───
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Header
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
                      onTap: _confirmLeave,
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

                  // Pill Icon Badge
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
                    child: const Icon(LucideIcons.helpCircle, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  const Text(
                    'Quiz',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    _traitement?['nom']?.toString() ?? 'Éducation thérapeutique',
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

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: _green),
                      ),
                    )
                  : questions.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(18)),
                                child: const Icon(LucideIcons.helpCircle, size: 28, color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(height: 16),
                              const Text('Pas de quiz disponible', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              const Text('Il n\'y a aucune question pour ce traitement.', style: TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF))),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        )
                      : Container(
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
                              // Card Header: Question counter & Timer
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [_green, _greenDark]),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(LucideIcons.helpCircle, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Question ${_currentQuestion + 1} / ${questions.length}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _navy,
                                      ),
                                    ),
                                    const Spacer(),

                                    // Timer badge
                                    if (_durationMinutes > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFDBA74), width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(LucideIcons.clock, size: 13, color: Color(0xFFEA580C)),
                                            const SizedBox(width: 5),
                                            Text(
                                              _formatTime(_timeLeftSeconds),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Colors.grey.shade100),

                              // Progress Bar
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('PROGRESSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                                        Text(
                                          '${(((_currentQuestion + 1) / questions.length) * 100).round()}%',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _greenDark),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: (_currentQuestion + 1) / questions.length,
                                        backgroundColor: const Color(0xFFE9EDF4),
                                        valueColor: const AlwaysStoppedAnimation<Color>(_green),
                                        minHeight: 7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Question text
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      questions[_currentQuestion]['texte']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2937),
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // Option cards
                                    ...() {
                                      final currentQ = questions[_currentQuestion];
                                      final reponses = currentQ['reponses'] is List ? currentQ['reponses'] as List : [];
                                      return List.generate(reponses.length, (idx) {
                                        final rep = reponses[idx];
                                        final isSelected = _selectedResponseIndex == idx;
                                        final letter = idx < _letters.length ? _letters[idx] : '${idx + 1}';

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: InkWell(
                                            onTap: () => setState(() => _selectedResponseIndex = idx),
                                            borderRadius: BorderRadius.circular(14),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                              decoration: BoxDecoration(
                                                gradient: isSelected
                                                    ? const LinearGradient(colors: [_green, _greenDark])
                                                    : null,
                                                color: isSelected ? null : const Color(0xFFFAFAFA),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isSelected ? Colors.transparent : const Color(0xFFE4EAF3),
                                                  width: 1.8,
                                                ),
                                                boxShadow: isSelected
                                                    ? [
                                                        BoxShadow(
                                                          color: _green.withValues(alpha: 0.32),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                                                        width: 1.8,
                                                      ),
                                                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        letter,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800,
                                                          color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      rep['texte']?.toString() ?? '',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: isSelected ? Colors.white : const Color(0xFF374151),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                    }(),

                                    const SizedBox(height: 12),

                                    // Next / Finish Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _selectedResponseIndex == null ? null : _handleNext,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _navy,
                                          disabledBackgroundColor: _navy.withValues(alpha: 0.38),
                                          foregroundColor: Colors.white,
                                          disabledForegroundColor: Colors.white70,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          elevation: _selectedResponseIndex == null ? 0 : 3,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _currentQuestion == questions.length - 1 ? 'Terminer' : 'Suivant',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              _currentQuestion == questions.length - 1 ? LucideIcons.checkCircle2 : LucideIcons.chevronRight,
                                              size: 18,
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
