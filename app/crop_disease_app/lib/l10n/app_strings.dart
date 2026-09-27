import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/settings_service.dart';

/// Lightweight English/French localization without codegen or ARB files.
///
/// The active language is read from [SettingsService] reactively (watch),
/// so the whole UI re-translates the moment the user changes the preference.
/// Falls back to English when the app is used without providers (widget tests).
class AppStrings {
  final bool isFrench;
  const AppStrings(this.isFrench);

  static const AppStrings english = AppStrings(false);
  static const AppStrings french = AppStrings(true);

  static AppStrings of(BuildContext context) {
    try {
      final settings = context.watch<SettingsService>();
      return settings.language == 'fr' ? french : english;
    } catch (_) {
      return english;
    }
  }

  String _t(String en, String fr) => isFrench ? fr : en;

  /// TTS language code matching the current UI language.
  String get ttsLanguageCode => isFrench ? 'fr-FR' : 'en-US';

  // --- Onboarding ---
  String get welcomeTitle => _t(
      "Welcome! Let's set up your farm", 'Bienvenue ! Configurons votre ferme');
  String get welcomeSubtitle => _t(
      'Enter your details once. Everything is saved on your phone and works offline.',
      'Saisissez vos informations une seule fois. Tout est enregistré sur votre téléphone et fonctionne hors ligne.');
  String get nameLabel => _t('Name', 'Nom');
  String get nameHint => _t('e.g. Musa', 'p. ex. Musa');
  String get phoneLabel => _t('Phone Number', 'Numéro de téléphone');
  String get phoneHint => _t('e.g. 07 12 34 56 78', 'p. ex. 07 12 34 56 78');
  String get villageLabel => _t('Village', 'Village');
  String get villageHint => _t('Where is your farm?', 'Où se trouve votre ferme ?');
  String get languageLabel => _t('Preferred language', 'Langue préférée');
  String get englishName => 'English';
  String get frenchName => 'Français';
  String get consentLabel => _t(
      'I agree to share my data to help other farmers',
      "J'accepte de partager mes données pour aider d'autres agriculteurs");
  String get getStarted => _t('Get Started', 'Commencer');
  String get autoFarmerIdNote => _t(
      'A Farmer ID is created automatically for you.',
      'Un identifiant agriculteur est créé automatiquement pour vous.');

  // --- Onboarding validation ---
  String get nameRequired => _t('Please enter your name', 'Veuillez saisir votre nom');
  String get phoneRequired =>
      _t('Please enter your phone number', 'Veuillez saisir votre numéro de téléphone');
  String get villageRequired =>
      _t('Please enter your village', 'Veuillez saisir votre village');
  String get consentRequired => _t(
      'Please agree to share data to continue',
      'Veuillez accepter le partage des données pour continuer');

  // --- Home ---
  String get appTitle => _t('AgroDiag', 'AgroDiag');
  String get hello => _t('Hello', 'Bonjour');
  String get scanNewLeaf => _t('SCAN NEW LEAF', 'SCANNER UNE FEUILLE');
  String get takePhoto => _t('Take a photo', 'Prendre une photo');
  String get myHistory => _t('MY HISTORY', 'MON HISTORIQUE');
  String get tipTitle => _t('Tip for today', 'Conseil du jour');
  String get farmerIdLabel => _t('Farmer ID', 'Identifiant agriculteur');
  String get tapToScan => _t('Tap to scan a leaf', 'Appuyez pour scanner une feuille');
  String get autoDetectsCrop => _t(
      'Automatically detects the crop and the disease. Works fully offline.',
      'Détecte automatiquement la culture et la maladie. Fonctionne entièrement hors ligne.');

  List<String> get tips => isFrench
      ? [
          'Vérifiez le maïs pour la chenille légionnaire — cherchez de petits trous et de la sciure dans le cornet.',
          'Retirez les mauvaises herbes autour des jeunes plants pour qu\'elles ne volent pas l\'eau.',
          'Regardez sous les feuilles pour les œufs et les jeunes insectes.',
          'Arrosez tôt le matin pour que les feuilles sèchent avant la nuit.',
          'Vérifiez les feuilles de bananier pour les stries jaunes (Sigatoka) — photographiez-les ici.',
          'Gardez le champ propre — retirez les feuilles mortes après la récolte.',
          'Vous voyez quelque chose d\'étrange ? Prenez une photo avec cette application tout de suite.',
        ]
      : [
          'Check maize for Fall Armyworm — look for small holes and sawdust in the funnel.',
          'Remove weeds around young plants so they don\'t steal water and nutrients.',
          'Look under the leaves for eggs and young insects.',
          'Water early in the morning so leaves dry before nightfall.',
          'Check banana leaves for yellow streaks (Sigatoka) — photo them here.',
          'Keep the field clean — remove dead leaves after harvest.',
          'See something strange? Take a photo with this app right away.',
        ];

  // --- Capture ---
  String get scanTitle => _t('Leaf Scan', 'Analyse de feuille');
  String get placeLeafInFrame => _t('Place leaf in frame', 'Placez la feuille dans le cadre');
  String get takingPhoto => _t('Taking photo…', 'Photo en cours…');
  String get detectingCrop => _t('Detecting crop…', 'Détection de la culture…');
  String loadingModel(String crop) =>
      _t('Loading $crop model…', 'Chargement du modèle $crop…');
  String get analyzingLeaf => _t('Analyzing leaf…', 'Analyse de la feuille…');
  String get noCamera =>
      _t('No camera found on this device.', 'Aucune caméra trouvée sur cet appareil.');
  String get timeoutAnalyzing => _t(
      'Timed out analyzing the photo. Please try again.',
      'Délai dépassé lors de l\'analyse de la photo. Veuillez réessayer.');
  String analyzeError(String e) =>
      _t('Could not analyze the photo: $e', 'Impossible d\'analyser la photo : $e');

  String get retakePhoto => _t('Retake photo', 'Reprendre la photo');

  // --- Location (mandatory) ---
  String get locationRequired => _t(
      'A GPS location is required to complete a scan. Please turn on location services (GPS) and try again.',
      'Une position GPS est requise pour terminer une analyse. Veuillez activer les services de localisation (GPS) et réessayer.');
  String get locationPermissionRequired => _t(
      'Location permission is required to complete a scan. Please allow location access for this app in your phone settings, then try again.',
      'L\'autorisation de localisation est requise pour terminer une analyse. Veuillez autoriser l\'accès à la localisation pour cette application dans les paramètres de votre téléphone, puis réessayer.');
  String get locationNoFix => _t(
      'We could not get a GPS fix right now. Please make sure GPS is turned on and move to an open area, then try again.',
      'Impossible d\'obtenir une position GPS pour le moment. Veuillez vous assurer que le GPS est activé et vous déplacer dans une zone dégagée, puis réessayer.');

  // --- Auto-rejection (no user confirmation) ---
  String get notLeafRejected => _t(
      'This does not appear to be a crop leaf. Please point the camera at a plant leaf.',
      'Cela ne semble pas être une feuille de culture. Veuillez diriger l\'appareil photo vers une feuille de plante.');
  String get notCropRejected => _t(
      'This is not a recognized crop. Supported crops: Banana, Cacao, Cassava, Maize.',
      'Ce n\'est pas une culture reconnue. Cultures prises en charge : banane, cacao, manioc, maïs.');
  String uncertainCropWarning(String crop) => _t(
      'Uncertain crop detection — using $crop',
      'Détection de culture incertaine — utilisation de $crop');

  // --- Result ---
  String get diagnosis => _t('Diagnosis', 'Diagnostic');
  String get confident => _t('Confident', 'Confiant');
  String get lowConfidence => _t('Low confidence', 'Faible confiance');
  String get about => _t('About', 'À propos');
  String get whatToDo => _t('What to do', 'Que faire');
  String get scanAnother => _t('Scan Another', 'Scanner une autre');
  String get done => _t('Done', 'Terminer');
  String confidencePercent(double p) =>
      _t('Confidence: ${(p * 100).toStringAsFixed(0)}%', 'Confiance : ${(p * 100).toStringAsFixed(0)}%');
  String get listen => _t('Listen to result', 'Écouter le résultat');
  String get stopListening => _t('Stop', 'Arrêter');
  String lowConfidenceBanner(String alternatives) => _t(
      'Not fully sure about this one. Other possibilities: $alternatives. Consider a local agricultural agent if the leaf still looks off.',
      'Pas tout à fait sûr pour celle-ci. Autres possibilités : $alternatives. Consultez un agent agricole local si la feuille semble toujours anormale.');
  String get recordedAt => _t('Recorded on', 'Enregistré le');
  String locationText(double lat, double lng) =>
      _t('Location: $lat, $lng', 'Position : $lat, $lng');
  String get noLocation => _t('No location captured', 'Position non capturée');

  // --- History ---
  String get historyTitle => _t('Scan history', 'Historique des analyses');
  String get noScansYet => _t('No scans yet.', 'Aucune analyse pour l\'instant.');

  // --- New-design shell / branding ---
  String get brandTagline => _t('Diagnose your crops today, for a healthier tomorrow.',
      'Diagnostiquez vos cultures aujourd\'hui, pour un demain plus sain.');
  String get login => _t('Log in', 'Se connecter');
  String get navHome => _t('Home', 'Accueil');
  String get navHistory => _t('History', 'Historique');
  String get navScanner => _t('Scanner', 'Scanner');
  String get navAdvice => _t('Advice', 'Conseils');
  String get navProfile => _t('Profile', 'Profil');
  String get scanPageTitle => _t('Scan a plant', 'Scanner une plante');
  String get placeLeafWellLit => _t('Place the leaf on a flat surface and make sure it\'s well lit.',
      'Placez la feuille sur une surface plane et assurez-vous qu\'elle est bien éclairée.');
  String get resultPageTitle => _t('Analysis result', 'Résultat de l\'analyse');
  String get severityLabel => _t('Severity', 'Gravité');
  String get severityHigh => _t('High', 'Élevée');
  String get severityMedium => _t('Medium', 'Moyenne');
  String get severityLow => _t('Low', 'Faible');
  String get descriptionTitle => _t('Description', 'Description');
  String get recommendationsTitle => _t('Recommendations', 'Recommandations');
  String get listenRecommendation => _t('Listen to the recommendation', 'Écouter la recommandation');
  String get healthyStatus => _t('Healthy', 'Saine');
  String get viewHistory => _t('View history', 'Voir l\'historique');
  String get quickActions => _t('Quick actions', 'Actions rapides');
  String get welcomeBack => _t('Welcome back', 'Bon retour');
  String get recentScans => _t('Recent scans', 'Analyses récentes');
  String get seeAll => _t('See all', 'Tout voir');
  String get adviceTitle => _t('Crop advice', 'Conseils agricoles');
  String get adviceSubtitle => _t('Daily tips to keep your fields healthy',
      'Conseils quotidiens pour garder vos champs en bonne santé');
  String get profileTitle => _t('Profile', 'Profil');
  String get farmerInfo => _t('Farmer information', 'Informations agriculteur');
  String get notSet => _t('Not set', 'Non renseigné');
  String get appLanguage => _t('App language', 'Langue de l\'application');
  String get dataSharing => _t('Data sharing consent', 'Consentement au partage des données');
  String get granted => _t('Granted', 'Accordé');
  String get notGranted => _t('Not granted', 'Non accordé');
  String get dataNote => _t('Your scans are stored on your phone and shared only with your consent.',
      'Vos analyses sont stockées sur votre téléphone et partagées uniquement avec votre consentement.');

  /// Severity word derived from a confidence-like score 0..1. Kept simple:
  /// high confidence of a disease == high severity; 'healthy' labels are
  /// handled by the caller.
  String severityWord(bool isHealthy, double confidence) {
    if (isHealthy) return severityLow;
    if (confidence >= 0.85) return severityHigh;
    if (confidence >= 0.6) return severityMedium;
    return severityLow;
  }

}
