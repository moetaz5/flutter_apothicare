import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String storeVersion;
  final String? storeUrl;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.storeVersion,
    this.storeUrl,
    this.releaseNotes,
  });
}

class AppUpdateService {
  static bool _hasCheckedThisSession = false;

  /// Automatically checks for updates on App Store (iOS) / Play Store (Android)
  /// without requiring any backend modification.
  static Future<void> checkForUpdate(BuildContext context, {bool forceCheck = false}) async {
    if (_hasCheckedThisSession && !forceCheck) return;
    _hasCheckedThisSession = true;

    try {
      final updateInfo = await checkStoreVersion();
      if (updateInfo != null && updateInfo.hasUpdate && context.mounted) {
        showUpdateDialog(context, updateInfo);
      }
    } catch (_) {
      // Fail silently without interrupting user experience
    }
  }

  /// Checks the official store (App Store / Play Store) for latest published version
  static Future<AppUpdateInfo?> checkStoreVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final packageName = packageInfo.packageName;

      if (Platform.isIOS) {
        // iOS: Query Apple iTunes Lookup API
        final url = Uri.parse('https://itunes.apple.com/lookup?bundleId=$packageName');
        final response = await http.get(url).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['resultCount'] != null && data['resultCount'] > 0) {
            final result = data['results'][0];
            final storeVersion = (result['version'] ?? '').toString();
            final storeUrl = (result['trackViewUrl'] ?? '').toString();
            final releaseNotes = (result['releaseNotes'] ?? '').toString();

            if (storeVersion.isNotEmpty && _isVersionOlder(currentVersion, storeVersion)) {
              return AppUpdateInfo(
                hasUpdate: true,
                currentVersion: currentVersion,
                storeVersion: storeVersion,
                storeUrl: storeUrl.isNotEmpty ? storeUrl : 'https://apps.apple.com/app/id$packageName',
                releaseNotes: releaseNotes,
              );
            }
          }
        }
      } else if (Platform.isAndroid) {
        // Android: Query Play Store details or metadata
        final storeUrl = 'https://play.google.com/store/apps/details?id=$packageName';
        // Note: For Android, if Play Store returns updated version string in public page
        final url = Uri.parse(storeUrl);
        final response = await http.get(url, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final match = RegExp(r'\[\[\["([0-9]+\.[0-9]+(\.[0-9]+)?)"\]\]').firstMatch(response.body);
          if (match != null && match.groupCount >= 1) {
            final storeVersion = match.group(1) ?? '';
            if (storeVersion.isNotEmpty && _isVersionOlder(currentVersion, storeVersion)) {
              return AppUpdateInfo(
                hasUpdate: true,
                currentVersion: currentVersion,
                storeVersion: storeVersion,
                storeUrl: storeUrl,
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Displays the update modal popup
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Icon Badge with Glow
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF86EFAC), Color(0xFF71A246)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: Colors.white,
                  size: 32,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Mise à jour disponible !',
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163820),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Version pill comparison
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Text(
                  'Version ${info.storeVersion} (actuelle: ${info.currentVersion})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Description
              Text(
                info.releaseNotes?.isNotEmpty == true
                    ? info.releaseNotes!
                    : 'Une nouvelle version d\'Apothicare est disponible sur le store avec des améliorations de sécurité, de navigation et de nouvelles fonctionnalités.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4B5563),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 22),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Plus tard',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (info.storeUrl != null && info.storeUrl!.isNotEmpty) {
                          final uri = Uri.parse(info.storeUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(LucideIcons.downloadCloud, size: 16),
                      label: const Text(
                        'Mettre à jour',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compares semantic version numbers (e.g. "1.0.0" vs "1.0.2")
  static bool _isVersionOlder(String current, String target) {
    try {
      final cleanCurrent = current.split('+').first.trim();
      final cleanTarget = target.split('+').first.trim();

      List<int> cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> tParts = cleanTarget.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = cParts.length > tParts.length ? cParts.length : tParts.length;
      while (cParts.length < maxLen) {
        cParts.add(0);
      }
      while (tParts.length < maxLen) {
        tParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (cParts[i] < tParts[i]) return true;
        if (cParts[i] > tParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}
