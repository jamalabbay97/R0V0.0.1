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
  String get machinesEquipment => 'Machines/Equipment';

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
  String get poste => 'Poste';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String operatingHoursExceeded(Object hours, Object maxHours) {
    return 'Operating hours (${hours}h) exceed the maximum allowed duration for this poste (${maxHours}h).';
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
  String equipmentReadyMessage(Object count) {
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
  String equipmentReadyToSubmit(Object count) {
    return '$count equipment ready to be submitted';
  }

  @override
  String get editEquipment => 'Edit Equipment';

  @override
  String get viewAllReports => 'View all reports';

  @override
  String get viewAllDetails => 'View All Details';

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
  String addStopForModule(Object module) {
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
}
