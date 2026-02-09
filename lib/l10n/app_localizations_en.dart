// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'R0 App';

  @override
  String get home => 'Home';

  @override
  String get r0Report => 'R0 Report';

  @override
  String get additionalData => 'Additional Data';

  @override
  String get addReport => 'Add Report';

  @override
  String get reportDetails => 'Report Details';

  @override
  String get editReport => 'Edit Report';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get activityReport => 'Activity Report';

  @override
  String get dailyReport => 'Daily Report';

  @override
  String get truckTracking => 'Truck Tracking';

  @override
  String get machinesEquipmentStopped => 'Machines & Equipment Stopped';

  @override
  String get noData => 'No Data';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get description => 'Description';

  @override
  String get type => 'Type';

  @override
  String get group => 'Group';

  @override
  String get selectGroup => 'Select Group';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get noDataMessage => 'No data available';

  @override
  String get reportSaved => 'Report saved successfully';

  @override
  String get reportDeleted => 'Report deleted successfully';

  @override
  String get reportUpdated => 'Report updated successfully';

  @override
  String get errorSavingReport => 'Error saving report';

  @override
  String get errorDeletingReport => 'Error deleting report';

  @override
  String get errorUpdatingReport => 'Error updating report';

  @override
  String get confirmDelete => 'Are you sure you want to delete this report?';

  @override
  String get confirm => 'Confirm';

  @override
  String get sendToSheets => 'Send';

  @override
  String get sendToSheetsTitle => 'Send to Google Sheets?';

  @override
  String get sendToSheetsMessage =>
      'This will save the report to Google Sheets and lock editing on this device. You can still view it, and deleting it locally will not remove it from Google Sheets.';

  @override
  String get reportSentToSheets => 'Report saved to Google Sheets.';

  @override
  String get reportAlreadySentToSheets =>
      'This report is already saved in Google Sheets.';

  @override
  String get reportSendToSheetsFailed =>
      'Unable to save the report to Google Sheets.';

  @override
  String get reportSentToSheetsReadOnly =>
      'This report is read-only after being saved to Google Sheets.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get generalInformation => 'General Information';

  @override
  String get direction => 'Direction';

  @override
  String get division => 'Division';

  @override
  String get oibEe => 'OIB/EE';

  @override
  String get mine => 'Mine';

  @override
  String get exit => 'Exit';

  @override
  String get distance => 'Distance';

  @override
  String get quality => 'Quality';

  @override
  String get stopsExplanation => 'Stops Explanation';

  @override
  String get addTruck => 'Add Truck';

  @override
  String get addCount => 'Add Count';

  @override
  String get truck => 'Truck';

  @override
  String get truckNumber => 'Truck Number';

  @override
  String get driver1 => 'Driver 1';

  @override
  String get driver2 => 'Driver 2';

  @override
  String get place => 'Place';

  @override
  String get total => 'Total';

  @override
  String get location => 'Location';

  @override
  String get reportConfirmationTitle => 'Report Saved';

  @override
  String get reportConfirmationMessage =>
      'When you click done, the report will be saved on the reports page. If you want to send this report to the company, go to the reports page and send it from there.';

  @override
  String get done => 'Done';

  @override
  String get pleaseSelectPoste => 'Please select a poste';

  @override
  String get counter => 'Counter';

  @override
  String operatingHoursExceeded(int hours, int maxHours) {
    return 'Operating hours (${hours}h) exceed the maximum allowed duration for this poste (${maxHours}h).';
  }

  @override
  String get carryOver => 'Carry-over';

  @override
  String carriedOverFrom(String poste) {
    return 'Carried over from $poste';
  }

  @override
  String get errorsDetected => 'Errors detected';

  @override
  String get vibratorCounterErrors => '• Errors in vibrator counters';

  @override
  String get liaisonCounterErrors => '• Errors in liaison counters';

  @override
  String get stockEntryErrors => '• Errors in stock entries';

  @override
  String get defautLabel => 'Defect';

  @override
  String get addStop => 'Add Stop';

  @override
  String get predefinedNature => 'Predefined nature';

  @override
  String get customNature => 'Custom nature';

  @override
  String get stopReason => 'Stop reason';

  @override
  String get enterStopReason => 'Enter the stop reason...';

  @override
  String get equipmentStops => 'Equipment Stops';

  @override
  String get stoppedEquipment => 'Stopped equipment';

  @override
  String get equipmentType => 'Equipment type';

  @override
  String get stopDuration => 'Stop duration';

  @override
  String get stopNature => 'Stop nature';

  @override
  String get addEquipment => 'Add Equipment';

  @override
  String get removeEquipment => 'Remove Equipment';

  @override
  String get equipment => 'Equipment';

  @override
  String get duration => 'Duration';

  @override
  String get nature => 'Nature';

  @override
  String get reason => 'Reason';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get missingProduct => 'Missing Product';

  @override
  String get waitingSaturationSilo => 'Waiting for Silo Saturation';

  @override
  String get extraction2Drainage => 'Extraction 2 Drainage';

  @override
  String get mechanicalStop => 'Mechanical Stop on:';

  @override
  String get electricalFault => 'Electrical Fault on:';

  @override
  String get installationStop => 'Installation Stop on:';

  @override
  String get mechanicalWork => 'Mechanical Work on:';

  @override
  String get electricalWork => 'Electrical Work on:';

  @override
  String get installationWork => 'Work in Installation on:';

  @override
  String get other => 'Other:';

  @override
  String get equipmentStopsTitle => 'Equipment - Stops';

  @override
  String get addEquipmentButton => 'Add Equipment';

  @override
  String get viewEquipmentButton => 'View Equipment';

  @override
  String get verificationTitle => 'Information Verification';

  @override
  String get viewDetailsButton => 'View Details';

  @override
  String equipmentReadyMessage(int count) {
    return '$count equipment ready to be submitted';
  }

  @override
  String get equipmentAddedMessage => 'Equipment added';

  @override
  String get finishButton => 'Finish';

  @override
  String get viewEquipmentList => 'View Equipment List';

  @override
  String get equipmentListTitle => 'Equipment List';

  @override
  String get noEquipmentMessage => 'No equipment added yet';

  @override
  String get equipmentDetails => 'Equipment Details';

  @override
  String get mainCategory => 'Main Category';

  @override
  String get subCategory => 'Sub Category';

  @override
  String get selectMainCategory => 'Select Main Category';

  @override
  String get selectSubCategory => 'Select Sub Category';

  @override
  String get selectEquipment => 'Select Equipment';

  @override
  String get addAtLeastOneEquipment =>
      'Add at least one equipment before submitting.';

  @override
  String get equipmentSelection => 'Equipment Selection';

  @override
  String get verification => 'Verification';

  @override
  String get equipmentModified => 'Equipment modified';

  @override
  String get noEquipmentAdded => 'No equipment added';

  @override
  String equipmentReadyToSubmit(int count) {
    return '$count equipment ready to be submitted';
  }

  @override
  String get editEquipment => 'Edit Equipment';

  @override
  String get viewAllReports => 'View all reports';

  @override
  String get viewAllDetails => 'View all details';

  @override
  String get dataVerification => 'Data Verification';

  @override
  String get step6Verification => 'STEP 6: VERIFICATION';

  @override
  String get selectNature => 'Select nature';

  @override
  String get stopsList => 'Stops List';

  @override
  String get countersList => 'Counters List';

  @override
  String get stockList => 'Stock List';

  @override
  String get liaisonCountersList => 'Liaison Counters List';

  @override
  String get addLiaisonCounter => 'Add Liaison Counter';

  @override
  String get addStock => 'Add Stock';

  @override
  String get addCounter => 'Add Counter';

  @override
  String get viewStops => 'View Stops';

  @override
  String get viewCounters => 'View Counters';

  @override
  String get viewStock => 'View Stock';

  @override
  String get viewLiaisonCounters => 'View Liaison Counters';

  @override
  String addStopForModule(String module) {
    return 'Add Stop - Module $module';
  }

  @override
  String get addInformation => 'Add Information';

  @override
  String get viewInformation => 'View Information';

  @override
  String get viewTrips => 'View Trips';

  @override
  String get tripDetails => 'Trip Details';

  @override
  String get truckList => 'Truck List';

  @override
  String get addTruckInfo => 'Add Truck Information';

  @override
  String get viewTruckInfo => 'View Truck Information';

  @override
  String get category => 'Category';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get availableReports => 'Available Reports';

  @override
  String get ocpReports => 'OCP Reports';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get r0Description => 'Equipment operation';

  @override
  String get activityReportDescription => 'Daily activities (TNB)';

  @override
  String get dailyReportDescription => 'Shift summary (TSUD)';

  @override
  String get truckTrackingDescription => 'Movement monitoring';

  @override
  String get machinesStoppedTitleShort => 'Machines Stopped';

  @override
  String get machinesStoppedDescription => 'Downtime log';

  @override
  String get reportsArchive => 'Reports Archive';

  @override
  String get reportsArchiveDescription => 'History & Logs';

  @override
  String get editTruckTracking => 'Edit Truck Tracking';

  @override
  String get newTruckTracking => 'New Truck Tracking';

  @override
  String get stepInfos => 'Infos';

  @override
  String get stepCamions => 'Trucks';

  @override
  String get stepVoyages => 'Trips';

  @override
  String get stepVerif => 'Verification';

  @override
  String get previous => 'Previous';

  @override
  String get submit => 'Submit';

  @override
  String get next => 'Next';

  @override
  String get newTruckLabel => 'New Truck';

  @override
  String get driverLabel => 'Driver';

  @override
  String get addTruckTitle => 'Add Truck';

  @override
  String get truckNumberLabel => 'Truck Number';

  @override
  String get locationLabel => 'Location';

  @override
  String get addTrip => 'Add Trip';

  @override
  String get editTrip => 'Edit Trip';

  @override
  String get tripLabel => 'Trip';

  @override
  String get viewDetails => 'View Details';

  @override
  String tripsCountLabel(int count) {
    return '$count trips';
  }

  @override
  String get summaryTitle => 'Summary';

  @override
  String get mineZoneLabel => 'Mine / Zone';

  @override
  String get tripsByEquipment => 'Trips per Equipment';

  @override
  String get tripsByTruck => 'Trips per Truck';

  @override
  String get tripDetailsTitle => 'Trip Details';

  @override
  String get invalidStopStartTimeForPoste =>
      'Start time must fall within the selected shift time range.';

  @override
  String get success => 'Success';

  @override
  String get longStopCarryOverNotice =>
      'Long stop detected. Reports were created for the subsequent shifts/day. Please start a new report if the stop continues.';

  @override
  String get unknownLabel => 'Unknown';

  @override
  String get modifierR0 => 'Edit R0 Report';

  @override
  String get nouveauRapportR0 => 'New R0 Report';

  @override
  String get stepCompteur => 'Counter';

  @override
  String get stepArrets => 'Stops';

  @override
  String get stepExploit => 'Exploitation';

  @override
  String get stepRepartition => 'Repartition';

  @override
  String get stepPersonnel => 'Personnel';

  @override
  String get stepConsom => 'Consumption';

  @override
  String get categoryLabel => 'Category';

  @override
  String get modelLabel => 'Model';

  @override
  String get selectPosteMessage => 'Please choose a poste.';

  @override
  String counterEntryTitle(String poste) {
    return 'Counter Entry - $poste Poste';
  }

  @override
  String get startCounterLabel => 'Start (Index)';

  @override
  String get endCounterLabel => 'End (Index)';

  @override
  String get noStopsRecorded => 'No stops recorded.';

  @override
  String get addArretTitle => 'Add Stop';

  @override
  String get heuresMarche => 'H.M';

  @override
  String get heuresArret => 'H.A';

  @override
  String get tonnageLabel => 'Tonnage';

  @override
  String get metrageFore => 'Drilling m';

  @override
  String get nrTrousFores => 'Nr Drilled';

  @override
  String get nrVoyages => 'Nr Trips';

  @override
  String get m3Decapage => 'M³ Strippe';

  @override
  String get nombreTKU => 'Nr T.K.U';

  @override
  String get rendementSimple => 'Yield';

  @override
  String get rendementLabel => 'Efficiency';

  @override
  String get chantierLabel => 'Worksite';

  @override
  String get gasoilLabel => 'Diesel';

  @override
  String get modifierRTNB => 'Edit TNB Report';

  @override
  String get infoLabel => 'Info';

  @override
  String arretCount(int index) {
    return 'Stop $index';
  }

  @override
  String get dureeLabel => 'Duration';

  @override
  String get natureLabel => 'Nature';

  @override
  String get ajButton => 'Add';

  @override
  String get cvibrLabel => 'Vibrator Counter';

  @override
  String get cliaisonLabel => 'Liaison Counter';

  @override
  String get stockLabel => 'Stock';

  @override
  String get aucunArret => 'No stops added';

  @override
  String get aucunCompteurVibr => 'No vibrator counter added';

  @override
  String get aucunCompteurLiaison => 'No liaison counter added';

  @override
  String get aucuneEntreeStock => 'No stock entry added';

  @override
  String get zone => 'Zone';

  @override
  String get operation => 'Operation';

  @override
  String get details => 'Details';

  @override
  String get summary => 'Summary';

  @override
  String get synthesis => 'Synthesis';

  @override
  String synthesisModule(int module) {
    return 'Synthesis Module $module';
  }

  @override
  String get functioning => 'Functioning';

  @override
  String get stops => 'Stops';

  @override
  String get complement => 'Nature (complement)';

  @override
  String get maxCharactersMessage => 'Maximum 20 characters per line';

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
  String get premierPosteShort => '1st';

  @override
  String get deuxiemePosteShort => '2nd';

  @override
  String get troisiemePosteShort => '3rd';

  @override
  String get park1 => 'PARK 1';

  @override
  String get park2 => 'PARK 2';

  @override
  String get park3 => 'PARK 3';

  @override
  String get activityTnb => 'Activity TNB';

  @override
  String get editActivityTnb => 'Edit Activity TNB';

  @override
  String get dailyTsud => 'Daily Report TSUD';

  @override
  String get editDailyTsud => 'Edit Daily Report TSUD';

  @override
  String get repartitionTravail => 'Work Repartition';

  @override
  String get mineSortie => 'Mine/Exit';

  @override
  String get engin => 'Engine';

  @override
  String get detailsArrets => 'Stops Details';

  @override
  String get addCounterShort => 'Add Count';

  @override
  String get vibratorCounterShort => 'Vibr. Counter';

  @override
  String get liaisonCounterShort => 'Liais. Counter';

  @override
  String get defeuitage => 'Defeuilltage';

  @override
  String get reprise => 'Reprise';

  @override
  String get sterile => 'Sterile';

  @override
  String get chargeuse992k => 'Loader 992K';

  @override
  String get chargeuse994h => 'Loader 994H';

  @override
  String get pelleHydraulique => 'Hydraulic Shovel';

  @override
  String get pelleElectriqueB1 => 'Electric Shovel B1';

  @override
  String arretTitle(int index) {
    return 'Stop $index';
  }

  @override
  String cvibrTitle(int index) {
    return 'Vibr. Counter $index';
  }

  @override
  String cliaisonTitle(int index) {
    return 'Liais. Counter $index';
  }

  @override
  String stockEntryTitle(int index) {
    return 'Stock Entry $index';
  }

  @override
  String get poste1er => '1st Shift';

  @override
  String get poste2eme => '2nd Shift';

  @override
  String get poste3eme => '3rd Shift';

  @override
  String get stockTypeNormal => 'NORMAL';

  @override
  String get stockTypeOceane => 'OCEANE';

  @override
  String get stockTypePb30 => 'PB30';

  @override
  String get sector => 'Sector';

  @override
  String get reportNo => 'Report N°';

  @override
  String get machinesEquipment => 'Machines/Equipment';

  @override
  String get poste => 'Shift';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get editArret => 'Edit Stop';

  @override
  String get deleteArret => 'Delete Stop';

  @override
  String get editCounter => 'Edit Counter';

  @override
  String get catMiniLoaders => 'Mini Loaders';

  @override
  String get catTruckLoaders => 'Truck Loaders';

  @override
  String get deleteCounter => 'Delete Counter';

  @override
  String get editStock => 'Edit Stock';

  @override
  String get deleteStock => 'Delete Stock';

  @override
  String get allPostes => 'All Shifts';

  @override
  String get clearFilter => 'Clear Filter';

  @override
  String get refresh => 'Refresh';

  @override
  String noReportsFoundForPoste(String poste) {
    return 'No reports found for shift $poste';
  }

  @override
  String get seeAllReports => 'See all reports';

  @override
  String reportsFound(int count, String poste) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
      zero: 'No reports',
    );
    return '$_temp0 found for shift $poste';
  }

  @override
  String get totalVoyages => 'Total Trips';

  @override
  String get dataSummary => 'Data Summary';

  @override
  String get stopDataNotAvailable => 'Stoppage data not available';

  @override
  String get vibratorCountersLabel => 'Vibrator Counters';

  @override
  String get liaisonCountersLabel => 'Liaison Counters';

  @override
  String get parkLabel => 'Park';

  @override
  String get quantityLabel => 'Qty';

  @override
  String get operatingTime => 'Operating Time';

  @override
  String get stopTime => 'Stop Time';

  @override
  String get machinesStoppedLabel => 'Stopped Machines/Equipment';

  @override
  String get noEquipmentStopped => 'No equipment stopped';

  @override
  String equipmentIndex(int index) {
    String _temp0 = intl.Intl.pluralLogic(
      index,
      locale: localeName,
      other: 'Equipment $index',
      one: 'Equipment 1',
    );
    return '$_temp0';
  }

  @override
  String get module1Label => 'Module 1';

  @override
  String get module2Label => 'Module 2';

  @override
  String get stopsLabel => 'Stops';

  @override
  String get dateLabel => 'Date';

  @override
  String get repartitionLabel => 'Repartition';

  @override
  String get timeLabel => 'Time';

  @override
  String get imputationLabel => 'Imputation';

  @override
  String get personnelLabel => 'Personnel';

  @override
  String get conductorLabel => 'Driver';

  @override
  String get graisseurLabel => 'Greaser';

  @override
  String get matriculeLabel => 'Serial Number';

  @override
  String get consommationLabel => 'Consumption';

  @override
  String get triconeLabel => 'Tricone';

  @override
  String get operationLabel => 'Operation';

  @override
  String get equipmentLabel => 'Equipment';

  @override
  String get qualityLabel => 'Quality';

  @override
  String get camionsLabel => 'Trucks';

  @override
  String get noteLabel => 'Note';

  @override
  String get deleteStopConfirm => 'Are you sure you want to delete this stop?';

  @override
  String get calculatedAutoHint => 'Calculated automatically (Stops, Counter)';

  @override
  String get addWorkDistributionTitle => 'Add a work distribution';

  @override
  String get editWorkDistributionTitle => 'Edit work distribution';

  @override
  String get deleteWorkDistributionTitle => 'Delete work distribution';

  @override
  String get deleteWorkDistributionConfirm =>
      'Are you sure you want to delete this work distribution?';

  @override
  String get editPersonnelTitle => 'Edit personnel';

  @override
  String get editConsumptionTitle => 'Edit consumption';

  @override
  String get deleteCounterConfirm =>
      'Are you sure you want to delete this counter?';

  @override
  String get startTimeLabel => 'Start time';

  @override
  String get endTimeLabel => 'End time';

  @override
  String get selectTimeTitle => 'Select time';

  @override
  String get selectCategoryStep => 'Select category';

  @override
  String get selectStopTypeStep => 'Select stop type';

  @override
  String get enterDetailsStep => 'Enter details';

  @override
  String get okButton => 'OK';

  @override
  String get deleteTruckTitle => 'Delete the truck';

  @override
  String get deleteTruckConfirm =>
      'Are you sure you want to delete this truck?';

  @override
  String get noCountersAdded => 'No counters added';

  @override
  String get noStopsAdded => 'No stops added';

  @override
  String get noExploitationData => 'No exploitation data';

  @override
  String get noPersonnelData => 'No personnel data';

  @override
  String get noConsumptionData => 'No consumption data';

  @override
  String editReportType(String type) {
    return 'Edit - $type';
  }

  @override
  String equipmentLabelWithIndex(int index) {
    return 'Equipment $index:';
  }

  @override
  String totalFor(String key, String value) {
    return 'Total for $key: $value';
  }

  @override
  String tripLabelWithIndex(int index) {
    return 'v$index: ';
  }

  @override
  String workLabelWithIndex(int index) {
    return 'Work $index';
  }

  @override
  String get voyagesLabel => 'Voyages';

  @override
  String get additionalDataLabel => 'Additional data';

  @override
  String get addStopTitle => 'Add Stop';

  @override
  String get editStopTitle => 'Edit Stop';

  @override
  String get deleteStopTitle => 'Delete Stop';

  @override
  String get addVibratorCounterTitle => 'Add Vibrator Counter';

  @override
  String get editVibratorCounterTitle => 'Edit Vibrator Counter';

  @override
  String get deleteVibratorCounterTitle => 'Delete Vibrator Counter';

  @override
  String get addLiaisonCounterTitle => 'Add Liaison Counter';

  @override
  String get editLiaisonCounterTitle => 'Edit Liaison Counter';

  @override
  String get deleteLiaisonCounterTitle => 'Delete Liaison Counter';

  @override
  String get addStockEntryTitle => 'Add Stock Entry';

  @override
  String get editStockEntryTitle => 'Edit Stock Entry';

  @override
  String get deleteStockEntryTitle => 'Delete Stock Entry';

  @override
  String get addCounterTitle => 'Add Counter';

  @override
  String get editCounterTitle => 'Edit Counter';

  @override
  String get deleteCounterTitle => 'Delete Counter';

  @override
  String get editExploitationTitle => 'Edit Exploitation';

  @override
  String get predefinedNatureLabel => 'Predefined nature';

  @override
  String get durationLabel => 'Duration (e.g., 1h 30)';

  @override
  String get complementLabel => 'Nature (complement)';

  @override
  String get maxCharactersHint => 'Maximum 20 characters per line';

  @override
  String get moduleLabel => 'Module';

  @override
  String get parkTypeLabel => 'Park Type';

  @override
  String get hmLabel => 'H.M';

  @override
  String get haLabel => 'H.A';

  @override
  String get rendemeLabel => 'Efficiency';

  @override
  String get conductrLabel => 'Driver';

  @override
  String get matriculesLabel => 'Serial Numbers';

  @override
  String get noLiaisonCountersAdded => 'No liaison counter added';

  @override
  String get noStockEntriesAdded => 'No stock entry added';

  @override
  String get calculatedAutomatically =>
      'Calculated automatically (Stops, Counter)';

  @override
  String get stocksLabel => 'Stocks';

  @override
  String get exploitationLabel => 'Exploitation';

  @override
  String get tempsLabel => 'Time';

  @override
  String get finishLabel => 'Finish';

  @override
  String get infoOibEeLabel => 'Info OIB/EE';

  @override
  String get modifyLabel => 'Modify';

  @override
  String get arretsLabel => 'Stops';

  @override
  String get deleteStockConfirm =>
      'Are you sure you want to delete this stock entry?';

  @override
  String editLabel(String label) {
    return 'Edit $label';
  }

  @override
  String get noMachinesStopped => 'No machines stopped';

  @override
  String get reportDateLabel => 'Report Date';

  @override
  String get mainCategoryLabel => 'Main Category';

  @override
  String get subCategoryLabel => 'Sub Category';

  @override
  String get stopReasonLabel => 'Stop Reason';

  @override
  String get enterStopReasonHint => 'Enter stop reason...';

  @override
  String get groupLabel => 'Group';

  @override
  String get deleteEquipment => 'Delete Equipment';

  @override
  String get deleteEquipmentConfirm =>
      'Are you sure you want to delete this equipment?';

  @override
  String get vibrTitle => 'Vibrator Counters';

  @override
  String get liaisonTitle => 'Liaison Counters';

  @override
  String get workDistributionLabel => 'Work Distribution';

  @override
  String get addButton => 'Add';

  @override
  String get noTrucksAdded => 'No trucks added';

  @override
  String get summaryLabel => 'Summary';

  @override
  String get noStockAdded => 'No stock added';

  @override
  String get stopsWithColon => 'Stops:';

  @override
  String get tripsWithColon => 'Trips:';

  @override
  String get tripsSummary => 'Trips Summary';

  @override
  String get noActivityData => 'No activity data available.';

  @override
  String get noDailyData => 'No daily data available.';

  @override
  String get noTruckTrackingData => 'No truck tracking data available.';

  @override
  String get noR0Data => 'No R0 data available.';

  @override
  String get noAdditionalData => 'No additional data';

  @override
  String get noTripsAdded => 'No trips added.';

  @override
  String updateError(String error) {
    return 'Error updating: $error';
  }

  @override
  String get saveChanges => 'Save Changes';

  @override
  String stockTitleIndex(int index) {
    return 'Stock $index';
  }

  @override
  String get tripTime => 'Trip Time';

  @override
  String genericCounterTitle(int index) {
    return 'Counter $index';
  }

  @override
  String workTitleIndex(int index) {
    return 'Work $index';
  }

  @override
  String driverParam(String driver) {
    return 'Driver: $driver';
  }

  @override
  String truckParam(String truck) {
    return 'Truck: $truck';
  }

  @override
  String typeParam(String type) {
    return 'Type: $type';
  }

  @override
  String reasonParam(String reason) {
    return 'Reason: $reason';
  }

  @override
  String endParam(String end) {
    return 'End: $end';
  }

  @override
  String trackingDescription(String date, String poste) {
    return 'Tracking - $date - $poste';
  }

  @override
  String get catBulldozers => 'BULLDOZERS';

  @override
  String get catTrucks => 'TRUCKS';

  @override
  String get catLoaders => 'LOADERS';

  @override
  String get catGraders => 'GRADERS';

  @override
  String get catPaydozers => 'PAYDOZERS';

  @override
  String get catHydraulicShovels => 'HYDRAULIC SHOVELS';

  @override
  String get catDraglines => 'DRAGLINES';

  @override
  String get catElectricShovels => 'ELECTRIC SHOVELS';

  @override
  String get catDrills => 'DRILLS';

  @override
  String get catExterior => 'EXTERNAL';

  @override
  String get catMaterial => 'MATERIAL';

  @override
  String get catExploitation => 'EXPLOITATION';

  @override
  String get stopIndustrialArea => 'INDUSTRIAL AREA STOP';

  @override
  String get stopPowerCut => 'GENERAL POWER CUT';

  @override
  String get stopStrike => 'STRIKE';

  @override
  String get stopWeather => 'BAD WEATHER';

  @override
  String get stopFullStocks => 'FULL STOCKS';

  @override
  String get stopHolidays => 'HOLIDAYS OR WEEKLY';

  @override
  String get stopPowerPlant => 'POWER PLANT STOP';

  @override
  String get stopControl => 'CONTROL';

  @override
  String get stopElecFault => 'ELEC FAULT (CABLE, NETWORK)';

  @override
  String get stopMechBreakdown => 'MECHANICAL BREAKDOWN';

  @override
  String get stopElecBreakdown => 'ELECTRICAL BREAKDOWN';

  @override
  String get stopTireWorkshop => 'TIRE WORKSHOP INTERVENTION';

  @override
  String get stopMaintenance => 'SYSTEMATIC MAINTENANCE';

  @override
  String get stopRefill => 'REFILL (OIL, DIESEL, WATER)';

  @override
  String get stopGreasing => 'GREASING';

  @override
  String get stopFixedInstallElec => 'FIXED INSTALLATION ELEC STOP';

  @override
  String get stopNoTrucks => 'NO TRUCKS';

  @override
  String get stopNoBull => 'NO BULLDOZER';

  @override
  String get stopNoMechanic => 'NO MECHANIC';

  @override
  String get stopNoTools => 'NO WORK TOOLS';

  @override
  String get stopMachineStopped => 'MACHINE STOPPED';

  @override
  String get stopBreakdownFront => 'EQUIPMENT BREAKDOWN IN FRONT';

  @override
  String get stopShiftChange => 'SHIFT CHANGE';

  @override
  String get stopPlatformExec => 'PLATFORM EXECUTION';

  @override
  String get stopMove => 'MOVE';

  @override
  String get stopBlasting => 'BLASTING';

  @override
  String get stopCableMove => 'CABLE MOVE';

  @override
  String get stopDecidedStop => 'DECIDED STOP';

  @override
  String get stopNoDriver => 'NO DRIVER';

  @override
  String get stopBreak => 'BREAK';

  @override
  String get stopTracks => 'TRACKS (EXCL. WEATHER)';

  @override
  String get stopFixedInstallMech => 'FIXED INSTALLATION MECH STOP';

  @override
  String get stopTelescoping => 'TELESCOPING';

  @override
  String get stopPureExcavation => 'PURE EXCAVATION';

  @override
  String get stopPureEarthworks => 'PURE EARTHWORKS';

  @override
  String get trackingType => 'Tracking';

  @override
  String reportDescriptionPattern(String type, String date, String poste) {
    return '$type - $date - $poste';
  }

  @override
  String get deleteCounterTooltip => 'Delete counter';

  @override
  String get editCounterTooltip => 'Edit counter';

  @override
  String stopIndex(int index) {
    return 'Stop $index';
  }

  @override
  String get loader992k => 'Loader 992K';

  @override
  String get loader994h => 'Loader 994H';

  @override
  String get hydraulicShovel => 'Hydraulic Shovel';

  @override
  String get electricShovelB1 => 'Electric Shovel B1';

  @override
  String get selectTruckLabel => 'Select truck';

  @override
  String get truckLabel => 'Truck';

  @override
  String get driverInfoLabel => 'Driver information';

  @override
  String get editR0Title => 'Edit R0 Report';

  @override
  String get editTruckTitle => 'Edit Truck';

  @override
  String get newTruckTitle => 'New Truck';

  @override
  String get machinesEquipmentStoppedTitleShort => 'Machines/Equipment Stopped';

  @override
  String get conducteurLabel => 'Conductor';

  @override
  String get reasonLabel => 'Reason';
}
