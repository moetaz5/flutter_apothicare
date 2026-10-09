import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/providers/actualite_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/conge_provider.dart';
import 'core/providers/garde_provider.dart';
import 'core/providers/medicament_provider.dart';
import 'core/providers/messagerie_provider.dart';
import 'core/providers/patient_provider.dart';
import 'core/providers/procedure_provider.dart';
import 'core/providers/traitement_provider.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_toast.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/home_patient/presentation/home_patient_screen.dart';
import 'features/home_pharmacien/presentation/home_pharmacien_screen.dart';

import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/providers/admin_provider.dart';
import 'features/admin/presentation/home_admin_screen.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Storage Service (SharedPreferences)
  try {
    await StorageService.init().timeout(const Duration(seconds: 3));
  } catch (_) {}

  // Initialize Local Notifications (iOS & Android) and sync FCM token
  try {
    await NotificationService.initialize(navKey: AppToast.navigatorKey);
    if (StorageService.getToken() != null) {
      NotificationService.syncFcmToken(ApiClient());
    }
  } catch (_) {}

  // Initialize Android WebView Platform
  try {
    WebViewPlatform.instance ??= AndroidWebViewPlatform();
  } catch (_) {}

  // Initialize Android Google Maps hardware-accelerated renderer asynchronously without blocking runApp
  try {
    final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest).catchError((_) => AndroidMapRenderer.latest);
    }
  } catch (_) {}

  // Set system UI style (transparent status bar with dark icons)
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (_) {}

  runApp(const ApothicareApp());
}

class ApothicareApp extends StatelessWidget {
  const ApothicareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => GardeProvider()),
        ChangeNotifierProvider(create: (_) => ActualiteProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => TraitementProvider()),
        ChangeNotifierProvider(create: (_) => MessagerieProvider()),
        ChangeNotifierProvider(create: (_) => ProcedureProvider()),
        ChangeNotifierProvider(create: (_) => CongeProvider()),
        ChangeNotifierProvider(create: (_) => MedicamentProvider()),
      ],
      child: MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        title: 'Apothicare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('fr'),
          Locale('en', 'US'),
          Locale('en'),
          Locale('ar'),
        ],
        locale: const Locale('fr', 'FR'),
        routes: AppRoutes.routes,
        home: const SplashScreen(),
        builder: (context, child) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      precacheImage(const AssetImage('assets/images/back-mobile.png'), context);
      precacheImage(const AssetImage('assets/images/logo.png'), context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return const SignInScreen();
    }

    final user = auth.currentUser;
    final int roleId = user?.idRole ?? 0;
    if (user?.isAdmin == true || roleId == 1) {
      return const HomeAdminScreen();
    } else if (user?.isPatient == true || roleId == 3) {
      return const HomePatientScreen();
    } else if (user?.isPharmacien == true ||
        user?.isJeunePharmacie == true ||
        roleId == 2 ||
        roleId == 4 ||
        roleId == 7 ||
        roleId == 8) {
      return const HomePharmacienScreen();
    } else {
      return const SignInScreen();
    }
  }
}
