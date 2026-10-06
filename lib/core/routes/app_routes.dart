import 'package:flutter/material.dart';
import '../../features/actualites/presentation/actualites_screen.dart';
import '../../features/admin/presentation/admin_actualites_screen.dart';
import '../../features/admin/presentation/admin_annees_screen.dart';
import '../../features/admin/presentation/admin_annonces_screen.dart';
import '../../features/admin/presentation/admin_categories_screen.dart';
import '../../features/admin/presentation/admin_gardes_list_screen.dart';
import '../../features/admin/presentation/admin_jours_screen.dart';
import '../../features/admin/presentation/admin_list_jours_screen.dart';
import '../../features/admin/presentation/admin_profile_screen.dart';
import '../../features/admin/presentation/admin_semaine_garde_screen.dart';
import '../../features/admin/presentation/admin_services_screen.dart';
import '../../features/admin/presentation/admin_tb_gardes_screen.dart';
import '../../features/admin/presentation/admin_themes_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/home_admin_screen.dart';
import '../../features/auth/presentation/qr_scanner_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';
import '../../features/conges/presentation/list_conge_screen.dart';
import '../../features/gardes/presentation/gardes_map_screen.dart';
import '../../features/home_patient/presentation/home_patient_screen.dart';
import '../../features/home_pharmacien/presentation/home_pharmacien_screen.dart';
import '../../features/home_pharmacien/presentation/messagerie_screen.dart';
import '../../features/home_pharmacien/presentation/recherche_medicaments_screen.dart';
import '../../features/patient/presentation/ajouter_dispensation_screen.dart';
import '../../features/patient/presentation/carte_soin_screen.dart';
import '../../features/patient/presentation/details_traitement_screen.dart';
import '../../features/patient/presentation/dossier_patient_screen.dart';
import '../../features/patient/presentation/education_therapeutique_screen.dart';
import '../../features/patient/presentation/observance_screen.dart';
import '../../features/patient/presentation/quiz_screen.dart';
import '../../features/procedures/presentation/procedures_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/pharmacien_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/gardes/presentation/screen_calendrier_de_garde_pharmacien.dart';
import '../../features/splash/presentation/splash_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String qrScanner = '/qr-scanner';
  static const String homePatient = '/home-patient';
  static const String homePharmacien = '/home-pharmacien';
  static const String homeJeune = '/home-jeune';
  static const String homeAdmin = '/home-admin';
  static const String adminAnnees = '/admin-annees';
  static const String adminUsers = '/admin-users';
  static const String adminServices = '/admin-services';
  static const String adminTbGardes = '/admin-tb-gardes';
  static const String adminJours = '/admin-jours';
  static const String adminListeJours = '/admin-liste-jours';
  static const String adminGardesJours = '/admin-gardes-jours';
  static const String adminSemaineGarde = '/admin-semaine-garde';
  static const String adminCategories = '/admin-categories';
  static const String adminAnnonces = '/admin-annonces';
  static const String adminThemes = '/admin-themes';
  static const String adminActualites = '/admin-actualites';
  static const String adminGardes = '/admin-gardes';
  static const String adminProfile = '/admin-profile';
  static const String pharmacienProfile = '/pharmacien-profile';
  static const String gardesMap = '/gardes-map';
  static const String calendarGardes = '/calendar-gardes';
  static const String screenCalendrierDeGardePharmacien = '/screen-calendrier-de-garde-pharmacien';
  static const String screenClandrierDeGardePharmacien = '/screen-clandrier-de-garde-pharmacien';
  static const String messagerie = '/messagerie';
  static const String chatbot = '/chatbot';
  static const String ibnJezzar = '/ibn-jezzar';
  static const String procedures = '/procedures';
  static const String conges = '/conges';
  static const String demandeConge = '/demande-conge';
  static const String actualites = '/actualites';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String userEdit = '/user-edit';
  static const String carteSoin = '/carte-soin';
  static const String observance = '/observance';
  static const String dossierPatient = '/dossier-patient';
  static const String ajouterDispensation = '/ajouter-dispensation';
  static const String educationTherapeutique = '/education-therapeutique';
  static const String detailsTraitement = '/traitement-details';
  static const String quizTraitement = '/traitement-quiz';
  static const String medicaments = '/medicaments';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        signIn: (context) => const SignInScreen(),
        signUp: (context) => const SignUpScreen(),
        qrScanner: (context) => const QrScannerScreen(),
        homePatient: (context) => const HomePatientScreen(),
        homePharmacien: (context) => const HomePharmacienScreen(),
        homeJeune: (context) => const HomePharmacienScreen(),
        homeAdmin: (context) => const HomeAdminScreen(),
        adminAnnees: (context) => const AdminAnneesScreen(),
        adminUsers: (context) => const AdminUsersScreen(),
        adminServices: (context) => const AdminServicesScreen(),
        adminTbGardes: (context) => const AdminTbGardesScreen(),
        adminJours: (context) => const AdminJoursScreen(),
        adminListeJours: (context) => const AdminListJoursScreen(),
        adminGardesJours: (context) => const AdminJoursScreen(),
        adminSemaineGarde: (context) => const AdminSemaineGardeScreen(),
        adminCategories: (context) => const AdminCategoriesScreen(),
        adminAnnonces: (context) => const AdminAnnoncesScreen(),
        adminThemes: (context) => const AdminThemesScreen(),
        adminActualites: (context) => const AdminActualitesScreen(),
        adminGardes: (context) => const AdminGardesListScreen(),
        adminProfile: (context) => const AdminProfileScreen(),
        pharmacienProfile: (context) => const PharmacienProfileScreen(),
        editProfile: (context) => const EditProfileScreen(),
        userEdit: (context) => const EditProfileScreen(),
        gardesMap: (context) => const GardesMapScreen(),
        calendarGardes: (context) => const ScreenCalendrierDeGardePharmacien(),
        screenCalendrierDeGardePharmacien: (context) => const ScreenCalendrierDeGardePharmacien(),
        screenClandrierDeGardePharmacien: (context) => const ScreenCalendrierDeGardePharmacien(),
        messagerie: (context) => const MessagerieScreen(),
        chatbot: (context) => const ChatbotScreen(),
        ibnJezzar: (context) => const ChatbotScreen(),
        procedures: (context) => const ProceduresScreen(),
        conges: (context) => const ListCongeScreen(),
        demandeConge: (context) => const ListCongeScreen(),
        actualites: (context) => const ActualitesScreen(),
        profile: (context) => const ProfileScreen(),
        carteSoin: (context) => const CarteSoinScreen(),
        observance: (context) => const ObservanceScreen(),
        dossierPatient: (context) => const DossierPatientScreen(),
        ajouterDispensation: (context) => const AjouterDispensationScreen(),
        educationTherapeutique: (context) => const EducationTherapeutiqueScreen(),
        detailsTraitement: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map) {
            return DetailsTraitementScreen(traitement: args);
          }
          return const DetailsTraitementScreen();
        },
        quizTraitement: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map) {
            return QuizScreen(traitement: args);
          }
          return const QuizScreen();
        },
        medicaments: (context) => const RechercheMedicamentsScreen(),
      };
}



