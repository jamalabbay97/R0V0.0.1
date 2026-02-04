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
  String operatingHoursExceeded(int hours, int maxHours) {
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
  String equipmentReadyMessage(int count) {
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
  String equipmentReadyToSubmit(int count) {
    return '$count équipement prêt à être soumis';
  }

  @override
  String get editEquipment => 'Modifier l\'équipement';

  @override
  String get viewAllReports => 'Voir tous les rapports';

  @override
  String get viewAllDetails => 'Voir tous les détails';

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
  String addStopForModule(String module) {
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

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get availableReports => 'Rapports disponibles';

  @override
  String get ocpReports => 'Rapports OCP';

  @override
  String get settingsTooltip => 'Paramètres';

  @override
  String get r0Description => 'Opération des équipements';

  @override
  String get activityReportDescription => 'Activités quotidiennes (TNB)';

  @override
  String get dailyReportDescription => 'Résumé du poste (TSUD)';

  @override
  String get truckTrackingDescription => 'Suivi des mouvements';

  @override
  String get machinesStoppedTitleShort => 'Machines à l\'arrêt';

  @override
  String get machinesStoppedDescription => 'Journal des arrêts';

  @override
  String get reportsArchive => 'Archives des rapports';

  @override
  String get reportsArchiveDescription => 'Historique et journaux';

  @override
  String get editTruckTracking => 'Modifier le suivi des camions';

  @override
  String get newTruckTracking => 'Nouveau suivi des camions';

  @override
  String get stepInfos => 'Infos';

  @override
  String get stepCamions => 'Camions';

  @override
  String get stepVoyages => 'Voyages';

  @override
  String get stepVerif => 'Vérification';

  @override
  String get previous => 'Précédent';

  @override
  String get submit => 'Soumettre';

  @override
  String get next => 'Suivant';

  @override
  String get newTruckLabel => 'Nouveau camion';

  @override
  String get driverLabel => 'Chauffeur';

  @override
  String get addTruckTitle => 'Ajouter un camion';

  @override
  String get truckNumberLabel => 'Numéro du camion';

  @override
  String get locationLabel => 'Lieu';

  @override
  String get addTrip => 'Ajouter un voyage';

  @override
  String get editTrip => 'Modifier le voyage';

  @override
  String get tripLabel => 'Voyage';

  @override
  String get viewDetails => 'Voir les détails';

  @override
  String tripsCountLabel(int count) {
    return '$count voyages';
  }

  @override
  String get summaryTitle => 'Récapitulatif';

  @override
  String get mineZoneLabel => 'Mine / Zone';

  @override
  String get tripsByEquipment => 'Voyages par équipement';

  @override
  String get tripsByTruck => 'Voyages par camion';

  @override
  String get tripDetailsTitle => 'Détails des voyages';

  @override
  String get success => 'Succès';

  @override
  String get unknownLabel => 'Inconnu';

  @override
  String get modifierR0 => 'Modifier le rapport R0';

  @override
  String get nouveauRapportR0 => 'Nouveau rapport R0';

  @override
  String get stepCompteur => 'Compteur';

  @override
  String get stepArrets => 'Arrêts';

  @override
  String get stepExploit => 'Exploitation';

  @override
  String get stepRepartition => 'Répartition';

  @override
  String get stepPersonnel => 'Personnel';

  @override
  String get stepConsom => 'Consommation';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get modelLabel => 'Modèle';

  @override
  String get selectPosteMessage => 'Veuillez choisir un poste.';

  @override
  String counterEntryTitle(String poste) {
    return 'Saisie Compteur - $poste Poste';
  }

  @override
  String get startCounterLabel => 'Début (Index)';

  @override
  String get endCounterLabel => 'Fin (Index)';

  @override
  String get noStopsRecorded => 'Aucun arrêt enregistré.';

  @override
  String get addArretTitle => 'Ajouter un arrêt';

  @override
  String get heuresMarche => 'H.M';

  @override
  String get heuresArret => 'H.A';

  @override
  String get tonnageLabel => 'Tonnage';

  @override
  String get metrageFore => 'Metrage Fore';

  @override
  String get nrTrousFores => 'Nr Tr.Fore';

  @override
  String get nrVoyages => 'Nr Voyages';

  @override
  String get m3Decapage => 'M³ Decapage';

  @override
  String get nombreTKU => 'Nr T.K.U';

  @override
  String get rendementSimple => 'Rendement';

  @override
  String get rendementLabel => 'Rendement %';

  @override
  String get chantierLabel => 'Chantier';

  @override
  String get gasoilLabel => 'Gasoil';

  @override
  String get modifierRTNB => 'Modifier le rapport TNB';

  @override
  String get infoLabel => 'Infos';

  @override
  String arretCount(int index) {
    return 'Arrêt $index';
  }

  @override
  String get dureeLabel => 'Durée';

  @override
  String get natureLabel => 'Nature';

  @override
  String get ajButton => 'Aj';

  @override
  String get cvibrLabel => 'C Vibr';

  @override
  String get cliaisonLabel => 'C Liaison';

  @override
  String get stockLabel => 'Stock';

  @override
  String get aucunArret => 'Aucun arrêt ajouté';

  @override
  String get aucunCompteurVibr => 'Aucun compteur vibreur ajouté';

  @override
  String get aucunCompteurLiaison => 'Aucun compteur liaison ajouté';

  @override
  String get aucuneEntreeStock => 'Aucune entrée de stock ajoutée';

  @override
  String get zone => 'Zone';

  @override
  String get operation => 'Opération';

  @override
  String get details => 'Détails';

  @override
  String get summary => 'Récapitulatif';

  @override
  String get synthesis => 'Synthèse';

  @override
  String synthesisModule(int module) {
    return 'Synthèse Module $module';
  }

  @override
  String get functioning => 'Fonctionnement';

  @override
  String get stops => 'Arrêts';

  @override
  String get complement => 'Nature (complément)';

  @override
  String get maxCharactersMessage => 'Maximum 20 caractères par ligne';

  @override
  String get engines => 'ENGINS';

  @override
  String get machines => 'MACHINES';

  @override
  String get normal => 'NORMAL';

  @override
  String get oceane => 'OCEANE';

  @override
  String get pb30 => 'PB30';

  @override
  String get premierPosteShort => '1er';

  @override
  String get deuxiemePosteShort => '2ème';

  @override
  String get troisiemePosteShort => '3ème';

  @override
  String get park1 => 'PARK 1';

  @override
  String get park2 => 'PARK 2';

  @override
  String get park3 => 'PARK 3';

  @override
  String get activityTnb => 'Activité TNB';

  @override
  String get editActivityTnb => 'Modifier Activité TNB';

  @override
  String get dailyTsud => 'Daily Report TSUD';

  @override
  String get editDailyTsud => 'Modifier Daily Report TSUD';

  @override
  String get repartitionTravail => 'Répartition du Travail';

  @override
  String get mineSortie => 'Mine/sortie';

  @override
  String get engin => 'Engin';

  @override
  String get detailsArrets => 'Détails des Arrêts';

  @override
  String get addCounterShort => 'Aj Compteur';

  @override
  String get vibratorCounterShort => 'Comp. Vibreur';

  @override
  String get liaisonCounterShort => 'Comp. Liaison';

  @override
  String get defeuitage => 'Défeutage';

  @override
  String get reprise => 'Reprise';

  @override
  String get sterile => 'Stérile';

  @override
  String get chargeuse992k => 'Chargeuse 992K';

  @override
  String get chargeuse994h => 'Chargeuse 994H';

  @override
  String get pelleHydraulique => 'Pelle hydraulique';

  @override
  String get pelleElectriqueB1 => 'Pelle electrique B1';

  @override
  String arretTitle(int index) {
    return 'Arrêt $index';
  }

  @override
  String cvibrTitle(int index) {
    return 'Compteur Vibreur $index';
  }

  @override
  String cliaisonTitle(int index) {
    return 'Compteur Liaison $index';
  }

  @override
  String stockEntryTitle(int index) {
    return 'Entrée de Stock $index';
  }

  @override
  String get poste1er => '1er';

  @override
  String get poste2eme => '2ème';

  @override
  String get poste3eme => '3ème';

  @override
  String get stockTypeNormal => 'NORMAL';

  @override
  String get stockTypeOceane => 'OCEANE';

  @override
  String get stockTypePb30 => 'PB30';

  @override
  String get sector => 'Secteur';

  @override
  String get reportNo => 'Rapport N°';

  @override
  String get machinesEquipment => 'Machines/Engins';

  @override
  String get poste => 'Poste';

  @override
  String get start => 'Début';

  @override
  String get end => 'Fin';

  @override
  String get editArret => 'Modifier l\'arrêt';

  @override
  String get deleteArret => 'Supprimer l\'arrêt';

  @override
  String get editCounter => 'Modifier le compteur';

  @override
  String get deleteCounter => 'Supprimer le compteur';

  @override
  String get editStock => 'Modifier le stock';

  @override
  String get deleteStock => 'Supprimer le stock';

  @override
  String get allPostes => 'Tous les postes';

  @override
  String get clearFilter => 'Effacer le filtre';

  @override
  String get refresh => 'Actualiser';

  @override
  String noReportsFoundForPoste(String poste) {
    return 'Aucun rapport trouvé pour le poste $poste';
  }

  @override
  String get seeAllReports => 'Voir tous les rapports';

  @override
  String reportsFound(int count, String poste) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rapports trouvés',
      one: '1 rapport trouvé',
      zero: 'Aucun rapport trouvé',
    );
    return '$_temp0 pour le poste $poste';
  }

  @override
  String get totalVoyages => 'Total Voyages';

  @override
  String get dataSummary => 'Résumé des données';

  @override
  String get stopDataNotAvailable => 'Données des arrêts non disponibles';

  @override
  String get vibratorCountersLabel => 'Compteurs Vibreurs';

  @override
  String get liaisonCountersLabel => 'Compteurs Liaison';

  @override
  String get parkLabel => 'Park';

  @override
  String get quantityLabel => 'Qte';

  @override
  String get operatingTime => 'Heure de marche';

  @override
  String get stopTime => 'Temps d\'arrêt';

  @override
  String get machinesStoppedLabel => 'Équipements arrêtés';

  @override
  String get noEquipmentStopped => 'Aucun équipement arrêté';

  @override
  String equipmentIndex(int index) {
    return 'Équipement $index';
  }

  @override
  String get module1Label => 'Module 1';

  @override
  String get module2Label => 'Module 2';

  @override
  String get stopsLabel => 'Arrêts';

  @override
  String get dateLabel => 'Date';

  @override
  String get repartitionLabel => 'Répartition';

  @override
  String get timeLabel => 'Temps';

  @override
  String get imputationLabel => 'Imputation';

  @override
  String get personnelLabel => 'Personnel';

  @override
  String get conductorLabel => 'Conducteur';

  @override
  String get graisseurLabel => 'Graisseur';

  @override
  String get matriculeLabel => 'Matricule';

  @override
  String get consommationLabel => 'Consommation';

  @override
  String get triconeLabel => 'Tricone';

  @override
  String get operationLabel => 'Opération';

  @override
  String get equipmentLabel => 'Equipement';

  @override
  String get qualityLabel => 'Qualité';

  @override
  String get camionsLabel => 'Camions';

  @override
  String get noteLabel => 'Note';

  @override
  String get deleteStopConfirm =>
      'Êtes-vous sûr de vouloir supprimer cet arrêt ?';

  @override
  String get calculatedAutoHint => 'Calculé automatiquement (Arrets, Compteur)';

  @override
  String get addWorkDistributionTitle => 'Ajouter une répartition de travail';

  @override
  String get editWorkDistributionTitle => 'Modifier la répartition de travail';

  @override
  String get deleteWorkDistributionTitle =>
      'Supprimer la répartition de travail';

  @override
  String get deleteWorkDistributionConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette répartition de travail ?';

  @override
  String get editPersonnelTitle => 'Modifier le personnel';

  @override
  String get editConsumptionTitle => 'Modifier la consommation';

  @override
  String get deleteCounterConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce compteur ?';

  @override
  String get startTimeLabel => 'Heure début';

  @override
  String get endTimeLabel => 'Heure fin';

  @override
  String get selectTimeTitle => 'Sélectionner l\'heure';

  @override
  String get selectCategoryStep => 'Sélection de la catégorie';

  @override
  String get selectStopTypeStep => 'Sélection du type d\'arrêt';

  @override
  String get enterDetailsStep => 'Saisie des détails';

  @override
  String get okButton => 'OK';

  @override
  String get deleteTruckTitle => 'Supprimer le camion';

  @override
  String get deleteTruckConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce camion ?';

  @override
  String get noCountersAdded => 'Aucun compteur ajouté';

  @override
  String get noStopsAdded => 'Aucun arrêt ajouté';

  @override
  String get noExploitationData => 'Aucune donnée d\'exploitation';

  @override
  String get noPersonnelData => 'Aucune donnée de personnel';

  @override
  String get noConsumptionData => 'Aucune donnée de consommation';

  @override
  String editReportType(String type) {
    return 'Modifier - $type';
  }

  @override
  String equipmentLabelWithIndex(int index) {
    return 'Équipement $index:';
  }

  @override
  String totalFor(String key, String value) {
    return 'Total pour $key: $value';
  }

  @override
  String tripLabelWithIndex(int index) {
    return 'v$index: ';
  }

  @override
  String workLabelWithIndex(int index) {
    return 'Travail $index';
  }

  @override
  String get voyagesLabel => 'Voyages';

  @override
  String get additionalDataLabel => 'Données supplémentaires';

  @override
  String get addStopTitle => 'Ajouter un arrêt';

  @override
  String get editStopTitle => 'Modifier l\'arrêt';

  @override
  String get deleteStopTitle => 'Supprimer l\'arrêt';

  @override
  String get addVibratorCounterTitle => 'Ajouter un compteur vibreur';

  @override
  String get editVibratorCounterTitle => 'Modifier le compteur vibreur';

  @override
  String get deleteVibratorCounterTitle => 'Supprimer le compteur vibreur';

  @override
  String get addLiaisonCounterTitle => 'Ajouter un compteur liaison';

  @override
  String get editLiaisonCounterTitle => 'Modifier le compteur liaison';

  @override
  String get deleteLiaisonCounterTitle => 'Supprimer le compteur liaison';

  @override
  String get addStockEntryTitle => 'Ajouter une entrée de stock';

  @override
  String get editStockEntryTitle => 'Modifier l\'entrée de stock';

  @override
  String get deleteStockEntryTitle => 'Supprimer l\'entrée de stock';

  @override
  String get addCounterTitle => 'Ajouter un compteur';

  @override
  String get editCounterTitle => 'Modifier le compteur';

  @override
  String get deleteCounterTitle => 'Supprimer le compteur';

  @override
  String get editExploitationTitle => 'Modifier l\'exploitation';

  @override
  String get predefinedNatureLabel => 'Nature prédéfinie';

  @override
  String get durationLabel => 'Durée (ex: 1h 30)';

  @override
  String get complementLabel => 'Nature (complément)';

  @override
  String get maxCharactersHint => 'Maximum 20 caractères par ligne';

  @override
  String get moduleLabel => 'Module';

  @override
  String get parkTypeLabel => 'Type de Park';

  @override
  String get hmLabel => 'H.M';

  @override
  String get haLabel => 'H.A';

  @override
  String get rendemeLabel => 'Rendeme';

  @override
  String get conductrLabel => 'Conductr';

  @override
  String get matriculesLabel => 'Matricules';

  @override
  String get noLiaisonCountersAdded => 'Aucun compteur liaison ajouté';

  @override
  String get noStockEntriesAdded => 'Aucune entrée de stock ajoutée';

  @override
  String get calculatedAutomatically =>
      'Calculé automatiquement (Arrets, Compteur)';

  @override
  String get stocksLabel => 'Stocks';

  @override
  String get exploitationLabel => 'Exploitation';

  @override
  String get tempsLabel => 'Temps';

  @override
  String get finishLabel => 'Terminer';

  @override
  String get infoOibEeLabel => 'Info OIB/EE';

  @override
  String get modifyLabel => 'Modifier';

  @override
  String get arretsLabel => 'Arrêts';

  @override
  String get deleteStockConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette entrée de stock ?';

  @override
  String editLabel(String label) {
    return 'Modifier $label';
  }

  @override
  String get noMachinesStopped => 'Aucun équipement arrêté';

  @override
  String get reportDateLabel => 'Date du rapport';

  @override
  String get mainCategoryLabel => 'Catégorie principale';

  @override
  String get subCategoryLabel => 'Sous-catégorie';

  @override
  String get stopReasonLabel => 'Raison de l\'arrêt';

  @override
  String get enterStopReasonHint => 'Entrez la raison de l\'arrêt...';

  @override
  String get groupLabel => 'Groupe';

  @override
  String get deleteEquipment => 'Supprimer l\'équipement';

  @override
  String get deleteEquipmentConfirm =>
      'Êtes-vous sûr de vouloir supprimer cet équipement ?';

  @override
  String get vibrTitle => 'Compteurs Vibreurs';

  @override
  String get liaisonTitle => 'Compteurs Liaison';

  @override
  String get workDistributionLabel => 'Répartition Travail';

  @override
  String get addButton => 'Ajouter';

  @override
  String get noTrucksAdded => 'Aucun camion ajouté';

  @override
  String get summaryLabel => 'Résumé';

  @override
  String get noStockAdded => 'Aucune entrée de stock ajoutée';

  @override
  String get stopsWithColon => 'Arrêts:';

  @override
  String get tripsWithColon => 'Voyages:';

  @override
  String get tripsSummary => 'Résumé des voyages';

  @override
  String get noActivityData => 'Aucune donnée d\'activité disponible.';

  @override
  String get noDailyData => 'Aucune donnée quotidienne disponible.';

  @override
  String get noTruckTrackingData => 'Aucune donnée de suivi camion disponible.';

  @override
  String get noR0Data => 'Aucune donnée R0 disponible.';

  @override
  String get noAdditionalData => 'Aucune donnée supplémentaire';

  @override
  String get noTripsAdded => 'Aucun voyage ajouté.';

  @override
  String updateError(String error) {
    return 'Erreur lors de la mise à jour: $error';
  }

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String stockTitleIndex(int index) {
    return 'Stock $index';
  }

  @override
  String get tripTime => 'Temps du voyage';

  @override
  String genericCounterTitle(int index) {
    return 'Compteur $index';
  }

  @override
  String workTitleIndex(int index) {
    return 'Travail $index';
  }

  @override
  String driverParam(String driver) {
    return 'Chauffeur: $driver';
  }

  @override
  String truckParam(String truck) {
    return 'Camion: $truck';
  }

  @override
  String typeParam(String type) {
    return 'Type: $type';
  }

  @override
  String reasonParam(String reason) {
    return 'Raison: $reason';
  }

  @override
  String endParam(String end) {
    return 'Fin: $end';
  }

  @override
  String trackingDescription(String date, String poste) {
    return 'Suivi - $date - $poste';
  }

  @override
  String get catBulldozers => 'BULLDOZERS';

  @override
  String get catTrucks => 'CAMIONS';

  @override
  String get catLoaders => 'CHARGEUSES';

  @override
  String get catGraders => 'NIVELEUSES';

  @override
  String get catPaydozers => 'PAYDOZERS';

  @override
  String get catHydraulicShovels => 'PELLE HYDRAULIQUE';

  @override
  String get catDraglines => 'DRAGLINES';

  @override
  String get catElectricShovels => 'PELLE ELECTRIQUE';

  @override
  String get catDrills => 'SONDEUSES';

  @override
  String get catExterior => 'EXTERIEURS';

  @override
  String get catMaterial => 'MATERIEL';

  @override
  String get catExploitation => 'EXPLOITATION';

  @override
  String get stopIndustrialArea => 'ARRET CARREAU INDUSTRIEL';

  @override
  String get stopPowerCut => 'COUPURE GENERALE DU COURANT';

  @override
  String get stopStrike => 'GREVE';

  @override
  String get stopWeather => 'INTEMPERIES';

  @override
  String get stopFullStocks => 'STOCKS PLEINS';

  @override
  String get stopHolidays => 'J. FERIES OU HEBDOMADAIRES';

  @override
  String get stopPowerPlant => 'ARRET PAR LA CENTRALE (M.ENERGIE)';

  @override
  String get stopControl => 'CONTROLE';

  @override
  String get stopElecFault => 'DEFAUT ELEC. (C.CRAME, RESEAU)';

  @override
  String get stopMechBreakdown => 'PANNE MECANIQUE';

  @override
  String get stopElecBreakdown => 'PANNE ELECTRIQUE';

  @override
  String get stopTireWorkshop => 'INTERVENTION ATELIER PNEUMATIQUE';

  @override
  String get stopMaintenance => 'ENTRETIEN SYSTEMATIQUE';

  @override
  String get stopRefill => 'APPOINT (HUILE, GAZOL, EAU)';

  @override
  String get stopGreasing => 'GRAISSAGE';

  @override
  String get stopFixedInstallElec => 'ARRET ELEC. INSTALATION FIXES';

  @override
  String get stopNoTrucks => 'MANQUE CAMIONS';

  @override
  String get stopNoBull => 'MANQUE BULL';

  @override
  String get stopNoMechanic => 'MANQUE MECANICIEN';

  @override
  String get stopNoTools => 'MANQUE D\'OUTILS DE TRAVAIL';

  @override
  String get stopMachineStopped => 'MACHINE A L\'ARRET';

  @override
  String get stopBreakdownFront => 'PANNE ENGIN DEVANT MACHINE';

  @override
  String get stopShiftChange => 'RELEVE';

  @override
  String get stopPlatformExec => 'EXECUTION PLATE FORME';

  @override
  String get stopMove => 'DEPLACEMENT';

  @override
  String get stopBlasting => 'TIR ET SAUTAGE';

  @override
  String get stopCableMove => 'MOUV. DE CABLE';

  @override
  String get stopDecidedStop => 'ARRET DECIDE';

  @override
  String get stopNoDriver => 'MANQUE CONDUCTEUR';

  @override
  String get stopBreak => 'BRIQUET';

  @override
  String get stopTracks => 'PISTES (INTEMPERIES EXCLUES)';

  @override
  String get stopFixedInstallMech => 'ARRETS MECA. INSTALATIONS FIXES';

  @override
  String get stopTelescoping => 'TELESCOPAGE';

  @override
  String get stopPureExcavation => 'EXCAVATION PURE';

  @override
  String get stopPureEarthworks => 'TERASSEMENT PUR';

  @override
  String get trackingType => 'Suivi';

  @override
  String reportDescriptionPattern(String type, String date, String poste) {
    return '$type - $date - $poste';
  }

  @override
  String get deleteCounterTooltip => 'Supprimer le compteur';

  @override
  String get editCounterTooltip => 'Modifier le compteur';

  @override
  String stopIndex(int index) {
    return 'Arrêt $index';
  }

  @override
  String get loader992k => 'Chargeuse 992K';

  @override
  String get loader994h => 'Chargeuse 994H';

  @override
  String get hydraulicShovel => 'Pelle hydraulique';

  @override
  String get electricShovelB1 => 'Pelle électrique B1';

  @override
  String get selectTruckLabel => 'Sélectionner un camion';

  @override
  String get truckLabel => 'Camion';

  @override
  String get driverInfoLabel => 'Informations du chauffeur';

  @override
  String get editR0Title => 'Modifier le rapport R0';

  @override
  String get editTruckTitle => 'Modifier le camion';

  @override
  String get newTruckTitle => 'Nouveau camion';

  @override
  String get machinesEquipmentStoppedTitleShort => 'Machines/Engins arrêtés';

  @override
  String get conducteurLabel => 'Conducteur';

  @override
  String get reasonLabel => 'Raison';
}
