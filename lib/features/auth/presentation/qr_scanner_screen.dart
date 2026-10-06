import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _viewfinderKey = GlobalKey();

  bool _isProcessing = false;
  Uint8List? _lastFrameBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchAllMedicaments();
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Instant direct scan of whatever is currently in the camera viewfinder frame (NO external camera app)
  Future<void> _handleDirectScan() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Uint8List? imageBytes = _lastFrameBytes;

      // Capture direct snapshot from current on-screen viewfinder widget
      if (imageBytes == null || imageBytes.isEmpty) {
        try {
          final boundary = _viewfinderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              imageBytes = byteData.buffer.asUint8List();
            }
          }
        } catch (err) {
          debugPrint('Viewfinder capture error: $err');
        }
      }

      String? imageSrc;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final base64Image = base64Encode(imageBytes);
        imageSrc = 'data:image/jpeg;base64,$base64Image';
      }

      if (!mounted) return;
      final patientProvider = context.read<PatientProvider>();
      final product = await patientProvider.getProduit(imageSrc: imageSrc);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showProductResultSheet(product);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showProductResultSheet(null);
      }
    }
  }

  /// Scan from Gallery
  Future<void> _handleGalleryScan() async {
    if (_isProcessing) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() {
        _isProcessing = true;
      });

      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final imageSrc = 'data:image/jpeg;base64,$base64Image';

      if (!mounted) return;
      final patientProvider = context.read<PatientProvider>();
      final product = await patientProvider.getProduit(imageSrc: imageSrc);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showProductResultSheet(product);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        AppToast.showError('Erreur lors de la sélection : ${e.toString()}', context);
      }
    }
  }

  /// Handle automatic barcode detection if visible
  Future<void> _handleBarcodeDetected(String rawCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final patientProvider = context.read<PatientProvider>();
    final allMeds = patientProvider.allMedicamentsList;

    // Check local medication catalog first
    dynamic matchedLocal;
    for (var m in allMeds) {
      final codeStr = (m['code_barre'] ?? m['code'] ?? '').toString().trim();
      if (codeStr.isNotEmpty && codeStr == rawCode) {
        matchedLocal = m;
        break;
      }
    }

    Map<String, dynamic>? productResult;
    if (matchedLocal != null) {
      productResult = {
        'is_match_found': true,
        'matched_product_name': matchedLocal['produit'] ?? matchedLocal['nom'] ?? 'Médicament',
        'code_barre': rawCode,
        'dci': matchedLocal['dci'] ?? matchedLocal['dosage'] ?? matchedLocal['composition'],
        'indication': matchedLocal['indication'] ?? matchedLocal['contre_indication'],
        'classes': matchedLocal['classes'] ?? matchedLocal['forme'],
        'mode_voie_administration': matchedLocal['mode_voie_administration'] ?? matchedLocal['voie'],
        'prise_repas': matchedLocal['prise_repas'],
        'grossesse': matchedLocal['grossesse'],
        'allaitement': matchedLocal['allaitement'],
      };
    } else {
      // Query backend API getProduit
      final apiProduct = await patientProvider.getProduit(codeBarre: rawCode);
      if (apiProduct != null) {
        productResult = apiProduct;
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      _showProductResultSheet(productResult);
    }
  }

  /// Show product bottom sheet popup (100% identical to React CamPhotoPopup.jsx)
  void _showProductResultSheet(Map<String, dynamic>? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isMatchFound = product != null &&
            (product['is_match_found'] == true ||
                product['matched_product_name'] != null ||
                product['produit'] != null ||
                product['nom'] != null);

        final productName = product?['matched_product_name'] ??
            product?['produit'] ??
            product?['nom'] ??
            product?['detected_name_from_image'] ??
            'Médicament détecté';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EAF3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (isMatchFound) ...[
                // Match Found View
                Text(
                  productName.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),

                // Key-value specifications
                ...[
                  ['Composant (DCI)', product['dci']],
                  ['Contre-indication', product['indication']],
                  ['Classe', product['classes']],
                  ["Mode & voie d'administration", product['mode_voie_administration']],
                  ['Prise par rapport au repas', product['prise_repas']],
                  ['Grossesse', product['grossesse']],
                  ['Allaitement', product['allaitement']],
                ].where((row) => row[1] != null && row[1].toString().trim().isNotEmpty).map((row) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row[0]!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          row[1]!.toString(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const Divider(color: Color(0xFFF3F4F6), height: 12),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Close Button (Red Gradient)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.28),
                    ),
                    child: const Text(
                      'Fermer',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action Button: Ajouter une dispensation (Green Gradient)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.ajouterDispensation,
                        arguments: {
                          'medicament_name': productName,
                          'code_barre': product['code_barre'],
                          'product': product,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: const Color(0xFF244082).withValues(alpha: 0.28),
                    ),
                    child: const Text(
                      'Ajouter une dispensation',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ] else ...[
                // No Match Found View
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(LucideIcons.alertTriangle, color: Color(0xFFEF4444), size: 30),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Aucun produit trouvé',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Réessayez avec une autre photo ou un meilleur éclairage.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF), height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                            shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.28),
                          ),
                          child: const Text(
                            'Réessayer',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER SECTION (Exact React CamPhotoPopup.jsx) ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 30),
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
                    child: const Icon(LucideIcons.camera, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  const Text(
                    'Scanner un produit',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    'Identifiez vos médicaments instantanément',
                    style: TextStyle(
                      color: Color(0xFF4B6A3A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Wave Divider
            CustomPaint(
              size: const Size(double.infinity, 24),
              painter: WavePainter(),
            ),

            // ─── BODY SECTION (Cam Card or Processing Card) ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  // Processing State Card
                  if (_isProcessing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: _green,
                              strokeWidth: 3.5,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Analyse en cours…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Identification du médicament',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Camera Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF244082).withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Viewfinder Container wrapped in RepaintBoundary for instant on-screen capture
                          RepaintBoundary(
                            key: _viewfinderKey,
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.44,
                              color: const Color(0xFF0D1F3C),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Scanner view
                                  MobileScanner(
                                    controller: _scannerController,
                                    onDetect: (capture) {
                                      _lastFrameBytes = capture.image;
                                      final barcodes = capture.barcodes;
                                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                        final code = barcodes.first.rawValue!.trim();
                                        _handleBarcodeDetected(code);
                                      }
                                    },
                                  ),

                                  // 4 Green Corner Brackets
                                  // Top-Left
                                  Positioned(
                                    top: 14,
                                    left: 14,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: _green, width: 3.5),
                                          left: BorderSide(color: _green, width: 3.5),
                                        ),
                                        borderRadius: BorderRadius.only(topLeft: Radius.circular(5)),
                                      ),
                                    ),
                                  ),
                                  // Top-Right
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: _green, width: 3.5),
                                          right: BorderSide(color: _green, width: 3.5),
                                        ),
                                        borderRadius: BorderRadius.only(topRight: Radius.circular(5)),
                                      ),
                                    ),
                                  ),
                                  // Bottom-Left
                                  Positioned(
                                    bottom: 14,
                                    left: 14,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: _green, width: 3.5),
                                          left: BorderSide(color: _green, width: 3.5),
                                        ),
                                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(5)),
                                      ),
                                    ),
                                  ),
                                  // Bottom-Right
                                  Positioned(
                                    bottom: 14,
                                    right: 14,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: _green, width: 3.5),
                                          right: BorderSide(color: _green, width: 3.5),
                                        ),
                                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(5)),
                                      ),
                                    ),
                                  ),

                                  // Controls (Torch, Flip Camera)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _scannerController.toggleTorch(),
                                          borderRadius: BorderRadius.circular(30),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black45,
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: const Icon(LucideIcons.zap, color: Colors.white, size: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _scannerController.switchCamera(),
                                          borderRadius: BorderRadius.circular(30),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black45,
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: const Icon(LucideIcons.switchCamera, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Scan & Upload Buttons
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Main Action Button: Scanner le produit (Instantly scans the aimed product in the current viewfinder)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing ? null : _handleDirectScan,
                                    icon: const Icon(LucideIcons.scanLine, size: 20),
                                    label: const Text(
                                      'Scanner le produit',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 3,
                                      shadowColor: _green.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Secondary Action: Choisir depuis la galerie
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isProcessing ? null : _handleGalleryScan,
                                    icon: const Icon(LucideIcons.image, size: 18, color: _green),
                                    label: const Text(
                                      'Choisir depuis la galerie',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _green,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: _green, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
