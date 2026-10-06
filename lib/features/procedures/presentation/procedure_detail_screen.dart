import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/procedure_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/wave_clipper.dart';

class ProcedureDetailScreen extends StatefulWidget {
  final ProcedureItem procedure;

  const ProcedureDetailScreen({super.key, required this.procedure});

  @override
  State<ProcedureDetailScreen> createState() => _ProcedureDetailScreenState();
}

class _ProcedureDetailScreenState extends State<ProcedureDetailScreen> {
  WebViewController? _pdfViewController;
  bool _isLoadingDoc = true;

  @override
  void initState() {
    super.initState();
    _initDocViewer();
  }

  void _initDocViewer() {
    final doc = widget.procedure.document;
    if (doc == null || doc.isEmpty) return;

    final docUrl = doc.startsWith('http')
        ? doc
        : '${AppConstants.backBaseUrl}uploads/$doc';

    // Google Docs Viewer URL to render PDF smoothly inside WebView on mobile
    final viewerUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(docUrl)}';

    try {
      WebViewPlatform.instance ??= AndroidWebViewPlatform();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoadingDoc = false);
            },
            onWebResourceError: (_) {
              if (mounted) setState(() => _isLoadingDoc = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(viewerUrl));

      setState(() => _pdfViewController = controller);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLoadingDoc) {
          setState(() => _isLoadingDoc = false);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDoc = false);
    }
  }

  Future<void> _downloadOrOpenExternal() async {
    final doc = widget.procedure.document;
    if (doc == null || doc.isEmpty) return;

    final docUrl = doc.startsWith('http')
        ? doc
        : '${AppConstants.backBaseUrl}uploads/$doc';

    final uri = Uri.parse(docUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppToast.showError('Impossible d\'ouvrir le document dans un navigateur externe.', context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final item = widget.procedure;
    final hasDoc = item.document != null && item.document!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
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
                    padding: EdgeInsets.only(top: topPadding + 14, bottom: 22, left: 18, right: 18),
                    child: Column(
                      children: [
                        // Back Button
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

                        // Green Folder Icon
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF71A246), Color(0xFF558332)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF71A246).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.fileText, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        const Text(
                          'Détails de la procédure',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF163820),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.nom,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B6A3A),
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
                      size: const Size(double.infinity, 18),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── PROCEDURE CONTENT CARD ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Procedure Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nom : ',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                        ),
                        Expanded(
                          child: Text(
                            item.nom,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description if present
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const Text(
                        'Description :',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Image Section if present
                    if (item.image != null && item.image!.isNotEmpty) ...[
                      const Text(
                        'Image :',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: '${AppConstants.backBaseUrl}uploads/${item.image}',
                            height: 180,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Document Preview Section
                    if (hasDoc) ...[
                      const Text(
                        'Document :',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                      ),
                      const SizedBox(height: 8),

                      // Embedded PDF Viewer Container
                      Container(
                        width: double.infinity,
                        height: 420,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (_pdfViewController != null)
                              WebViewWidget(controller: _pdfViewController!),

                            if (_isLoadingDoc)
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF71A246), strokeWidth: 3),
                                    SizedBox(height: 12),
                                    Text('Chargement du document PDF...', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Download / Open External Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _downloadOrOpenExternal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(LucideIcons.download, size: 18),
                          label: const Text(
                            'Télécharger / Ouvrir le PDF',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'Aucun document PDF n\'est associé à cette procédure.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
