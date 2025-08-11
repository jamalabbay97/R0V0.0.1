// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Application R0';

  @override
  String get home => 'Accueil';

  @override
  String get r0Report => 'Rapport R0';

  @override
  String get additionalData => 'Données supplémentaires';

  @override
  String get addReport => 'Ajouter un rapport';

  @override
  String get reportDetails => 'Détails du rapport';

  @override
  String get editReport => 'Modifier le rapport';

  @override
  String get reports => 'Rapports';

  @override
  String get settings => 'Paramètres';

  @override
  String get activityReport => 'Rapport d\'activité';

  @override
  String get dailyReport => 'Rapport journalier';

  @override
  String get truckTracking => 'Suivi des camions';

  @override
  String get machinesEquipmentStopped =>
      'Les machines et les engins sont à l\'arrêt';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get date => 'Date';

  @override
  String get time => 'Heure';

  @override
  String get description => 'Description';

  @override
  String get type => 'Type';

  @override
  String get group => 'Groupe';

  @override
  String get selectGroup => 'Sélectionner un groupe';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get noDataMessage => 'Aucune donnée disponible';

  @override
  String get reportSaved => 'Rapport enregistré avec succès';

  @override
  String get reportDeleted => 'Rapport supprimé avec succès';

  @override
  String get reportUpdated => 'Rapport mis à jour avec succès';

  @override
  String get errorSavingReport => 'Erreur lors de l\'enregistrement du rapport';

  @override
  String get errorDeletingReport => 'Erreur lors de la suppression du rapport';

  @override
  String get errorUpdatingReport => 'Erreur lors de la mise à jour du rapport';

  @override
  String get confirmDelete => 'Êtes-vous sûr de vouloir supprimer ce rapport ?';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get generalInformation => 'Informations générales';

  @override
  String get direction => 'Direction';

  @override
  String get division => 'Division';

  @override
  String get oibEe => 'OIB/EE';

  @override
  String get mine => 'Mine';

  @override
  String get exit => 'Sortie';

  @override
  String get distance => 'Distance';

  @override
  String get quality => 'Qualité';

  @override
  String get machinesEquipment => 'Machines/Engins';

  @override
  String get stopsExplanation => 'Explication des arrêts';

  @override
  String get addTruck => 'Ajouter un camion';

  @override
  String get addCount => 'Ajouter un comptage';

  @override
  String get truck => 'Camion';

  @override
  String get truckNumber => 'Numéro du camion';

  @override
  String get driver1 => 'Chauffeur 1';

  @override
  String get driver2 => 'Chauffeur 2';

  @override
  String get place => 'Lieu';

  @override
  String get total => 'Total';

  @override
  String get location => 'Emplacement';

  @override
  String get reportConfirmationTitle => 'Rapport enregistré';

  @override
  String get reportConfirmationMessage =>
      'Lorsque vous cliquez sur terminé, le rapport sera enregistré sur la page des rapports. Si vous souhaitez envoyer ce rapport à l\'entreprise, allez sur la page des rapports et envoyez-le à partir de là.';

  @override
  String get done => 'Terminé';

  @override
  String get pleaseSelectPoste => 'Veuillez sélectionner un poste';

  @override
  String get counter => 'Compteur';

  @override
  String get poste => 'Poste';

  @override
  String get start => 'Début';

  @override
  String get end => 'Fin';

  @override
  String operatingHoursExceeded(Object hours, Object maxHours) {
    return 'Heure de marche (${hours}h) dépasse la durée maximale autorisée pour ce poste (${maxHours}h).';
  }

  @override
  String get errorsDetected => 'Erreurs détectées';

  @override
  String get vibratorCounterErrors => '• Erreurs dans les compteurs vibreurs';

  @override
  String get liaisonCounterErrors => '• Erreurs dans les compteurs liaison';

  @override
  String get stockEntryErrors => '• Erreurs dans les entrées stock';

  @override
  String get addStop => 'Ajouter un arrêt';

  @override
  String get predefinedNature => 'Nature prédéfinie';

  @override
  String get customNature => 'Nature personnalisée';

  @override
  String get stopReason => 'Raison de l\'arrêt';

  @override
  String get enterStopReason => 'Entrez la raison de l\'arrêt...';

  @override
  String get equipmentStops => 'Arrêts d\'équipements';

  @override
  String get stoppedEquipment => 'Équipements arrêtés';

  @override
  String get equipmentType => 'Type d\'équipement';

  @override
  String get stopDuration => 'Durée de l\'arrêt';

  @override
  String get stopNature => 'Nature de l\'arrêt';

  @override
  String get addEquipment => 'Ajouter un équipement';

  @override
  String get removeEquipment => 'Supprimer l\'équipement';

  @override
  String get equipment => 'Équipement';

  @override
  String get duration => 'Durée';

  @override
  String get nature => 'Nature';

  @override
  String get reason => 'Raison';

  @override
  String get add => 'Ajouter';

  @override
  String get remove => 'Supprimer';

  @override
  String get missingProduct => 'Manque Produit';

  @override
  String get waitingSaturationSilo => 'Attente Saturation Silo';

  @override
  String get extraction2Drainage => 'Vidange Extraction 2';

  @override
  String get mechanicalStop => 'Arret Mécanique sur:';

  @override
  String get electricalFault => 'Dèfout Élèctrique sur:';

  @override
  String get installationStop => 'Arret d\'instalation sur:';

  @override
  String get mechanicalWork => 'Travoux Mècanique sur:';

  @override
  String get electricalWork => 'Travoux Elèctrique sur:';

  @override
  String get installationWork => 'Travoux dans l\'instalation sur:';

  @override
  String get other => 'Autre:';

  @override
  String get equipmentStopsTitle => 'Équipements - Arrêts';

  @override
  String get addEquipmentButton => 'Ajouter un équipement';

  @override
  String get viewEquipmentButton => 'Voir les équipements';

  @override
  String get verificationTitle => 'Vérification des informations';

  @override
  String get viewDetailsButton => 'Voir les détails';

  @override
  String equipmentReadyMessage(Object count) {
    return '$count équipement prêt à être soumis';
  }

  @override
  String get equipmentAddedMessage => 'Équipement ajouté';

  @override
  String get finishButton => 'Terminer';

  @override
  String get viewEquipmentList => 'Voir la liste des équipements';

  @override
  String get equipmentListTitle => 'Liste des équipements';

  @override
  String get noEquipmentMessage => 'Aucun équipement ajouté encore';

  @override
  String get equipmentDetails => 'Détails de l\'équipement';

  @override
  String get mainCategory => 'Catégorie principale';

  @override
  String get subCategory => 'Sous-catégorie';

  @override
  String get selectMainCategory => 'Sélectionner la catégorie principale';

  @override
  String get selectSubCategory => 'Sélectionner la sous-catégorie';

  @override
  String get selectEquipment => 'Sélectionner l\'équipement';

  @override
  String get addAtLeastOneEquipment =>
      'Ajoutez au moins un équipement avant de soumettre.';

  @override
  String get equipmentSelection => 'Sélection de l\'équipement';

  @override
  String get verification => 'Vérification';

  @override
  String get equipmentModified => 'Équipement modifié';

  @override
  String get noEquipmentAdded => 'Aucun équipement ajouté';

  @override
  String equipmentReadyToSubmit(Object count) {
    return '$count équipement prêt à être soumis';
  }

  @override
  String get editEquipment => 'Modifier l\'équipement';

  @override
  String get viewAllReports => 'Voir tous les rapports';

  @override
  String get viewAllDetails => 'Voir tous les details';

  @override
  String get dataVerification => 'Vérification des données';

  @override
  String get step6Verification => 'ÉTAPE 6: VÉRIFICATION';

  @override
  String get selectNature => 'Sélectionner une nature';

  @override
  String get stopsList => 'Liste des arrêts';

  @override
  String get countersList => 'Liste des compteurs';

  @override
  String get stockList => 'Liste des stocks';

  @override
  String get liaisonCountersList => 'Liste des compteurs liaison';

  @override
  String get addLiaisonCounter => 'Ajouter un compteur liaison';

  @override
  String get addStock => 'Ajouter un stock';

  @override
  String get addCounter => 'Ajouter un compteur';

  @override
  String get viewStops => 'Voir les arrêts';

  @override
  String get viewCounters => 'Voir les compteurs';

  @override
  String get viewStock => 'Voir les stocks';

  @override
  String get viewLiaisonCounters => 'Voir les compteurs liaison';

  @override
  String addStopForModule(Object module) {
    return 'Ajouter un arrêt - Module $module';
  }

  @override
  String get addInformation => 'Ajouter Informations';

  @override
  String get viewInformation => 'Voir Informations';

  @override
  String get viewTrips => 'Voir les voyages';

  @override
  String get tripDetails => 'Détails des voyages';

  @override
  String get truckList => 'Liste des camions';

  @override
  String get addTruckInfo => 'Ajouter un camion';

  @override
  String get viewTruckInfo => 'Voir les camions';

  @override
  String get category => 'Catégorie';
}
