import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'R0 App'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @r0Report.
  ///
  /// In en, this message translates to:
  /// **'R0 Report'**
  String get r0Report;

  /// No description provided for @additionalData.
  ///
  /// In en, this message translates to:
  /// **'Additional Data'**
  String get additionalData;

  /// No description provided for @addReport.
  ///
  /// In en, this message translates to:
  /// **'Add Report'**
  String get addReport;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Report Details'**
  String get reportDetails;

  /// No description provided for @editReport.
  ///
  /// In en, this message translates to:
  /// **'Edit Report'**
  String get editReport;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @activityReport.
  ///
  /// In en, this message translates to:
  /// **'Activity Report'**
  String get activityReport;

  /// No description provided for @dailyReport.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get dailyReport;

  /// No description provided for @truckTracking.
  ///
  /// In en, this message translates to:
  /// **'Truck Tracking'**
  String get truckTracking;

  /// No description provided for @machinesEquipmentStopped.
  ///
  /// In en, this message translates to:
  /// **'Machines & Equipment Stopped'**
  String get machinesEquipmentStopped;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @selectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get selectGroup;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @noDataMessage.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataMessage;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report saved successfully'**
  String get reportSaved;

  /// No description provided for @reportDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report deleted successfully'**
  String get reportDeleted;

  /// No description provided for @reportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Report updated successfully'**
  String get reportUpdated;

  /// No description provided for @errorSavingReport.
  ///
  /// In en, this message translates to:
  /// **'Error saving report'**
  String get errorSavingReport;

  /// No description provided for @errorDeletingReport.
  ///
  /// In en, this message translates to:
  /// **'Error deleting report'**
  String get errorDeletingReport;

  /// No description provided for @errorUpdatingReport.
  ///
  /// In en, this message translates to:
  /// **'Error updating report'**
  String get errorUpdatingReport;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this report?'**
  String get confirmDelete;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @generalInformation.
  ///
  /// In en, this message translates to:
  /// **'General Information'**
  String get generalInformation;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @division.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get division;

  /// No description provided for @oibEe.
  ///
  /// In en, this message translates to:
  /// **'OIB/EE'**
  String get oibEe;

  /// No description provided for @mine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get mine;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @machinesEquipment.
  ///
  /// In en, this message translates to:
  /// **'Machines/Equipment'**
  String get machinesEquipment;

  /// No description provided for @stopsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Stops Explanation'**
  String get stopsExplanation;

  /// No description provided for @addTruck.
  ///
  /// In en, this message translates to:
  /// **'Add Truck'**
  String get addTruck;

  /// No description provided for @addCount.
  ///
  /// In en, this message translates to:
  /// **'Add Count'**
  String get addCount;

  /// No description provided for @truck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get truck;

  /// No description provided for @truckNumber.
  ///
  /// In en, this message translates to:
  /// **'Truck Number'**
  String get truckNumber;

  /// No description provided for @driver1.
  ///
  /// In en, this message translates to:
  /// **'Driver 1'**
  String get driver1;

  /// No description provided for @driver2.
  ///
  /// In en, this message translates to:
  /// **'Driver 2'**
  String get driver2;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @reportConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Saved'**
  String get reportConfirmationTitle;

  /// No description provided for @reportConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'When you click done, the report will be saved on the reports page. If you want to send this report to the company, go to the reports page and send it from there.'**
  String get reportConfirmationMessage;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @pleaseSelectPoste.
  ///
  /// In en, this message translates to:
  /// **'Please select a poste'**
  String get pleaseSelectPoste;

  /// No description provided for @counter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counter;

  /// No description provided for @poste.
  ///
  /// In en, this message translates to:
  /// **'Poste'**
  String get poste;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @operatingHoursExceeded.
  ///
  /// In en, this message translates to:
  /// **'Operating hours ({hours}h) exceed the maximum allowed duration for this poste ({maxHours}h).'**
  String operatingHoursExceeded(Object hours, Object maxHours);

  /// No description provided for @errorsDetected.
  ///
  /// In en, this message translates to:
  /// **'Errors detected'**
  String get errorsDetected;

  /// No description provided for @vibratorCounterErrors.
  ///
  /// In en, this message translates to:
  /// **'• Errors in vibrator counters'**
  String get vibratorCounterErrors;

  /// No description provided for @liaisonCounterErrors.
  ///
  /// In en, this message translates to:
  /// **'• Errors in liaison counters'**
  String get liaisonCounterErrors;

  /// No description provided for @stockEntryErrors.
  ///
  /// In en, this message translates to:
  /// **'• Errors in stock entries'**
  String get stockEntryErrors;

  /// No description provided for @addStop.
  ///
  /// In en, this message translates to:
  /// **'Add Stop'**
  String get addStop;

  /// No description provided for @predefinedNature.
  ///
  /// In en, this message translates to:
  /// **'Predefined nature'**
  String get predefinedNature;

  /// No description provided for @customNature.
  ///
  /// In en, this message translates to:
  /// **'Custom nature'**
  String get customNature;

  /// No description provided for @stopReason.
  ///
  /// In en, this message translates to:
  /// **'Stop reason'**
  String get stopReason;

  /// No description provided for @enterStopReason.
  ///
  /// In en, this message translates to:
  /// **'Enter the stop reason...'**
  String get enterStopReason;

  /// No description provided for @equipmentStops.
  ///
  /// In en, this message translates to:
  /// **'Equipment Stops'**
  String get equipmentStops;

  /// No description provided for @stoppedEquipment.
  ///
  /// In en, this message translates to:
  /// **'Stopped equipment'**
  String get stoppedEquipment;

  /// No description provided for @equipmentType.
  ///
  /// In en, this message translates to:
  /// **'Equipment type'**
  String get equipmentType;

  /// No description provided for @stopDuration.
  ///
  /// In en, this message translates to:
  /// **'Stop duration'**
  String get stopDuration;

  /// No description provided for @stopNature.
  ///
  /// In en, this message translates to:
  /// **'Stop nature'**
  String get stopNature;

  /// No description provided for @addEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get addEquipment;

  /// No description provided for @removeEquipment.
  ///
  /// In en, this message translates to:
  /// **'Remove Equipment'**
  String get removeEquipment;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @missingProduct.
  ///
  /// In en, this message translates to:
  /// **'Missing Product'**
  String get missingProduct;

  /// No description provided for @waitingSaturationSilo.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Silo Saturation'**
  String get waitingSaturationSilo;

  /// No description provided for @extraction2Drainage.
  ///
  /// In en, this message translates to:
  /// **'Extraction 2 Drainage'**
  String get extraction2Drainage;

  /// No description provided for @mechanicalStop.
  ///
  /// In en, this message translates to:
  /// **'Mechanical Stop on:'**
  String get mechanicalStop;

  /// No description provided for @electricalFault.
  ///
  /// In en, this message translates to:
  /// **'Electrical Fault on:'**
  String get electricalFault;

  /// No description provided for @installationStop.
  ///
  /// In en, this message translates to:
  /// **'Installation Stop on:'**
  String get installationStop;

  /// No description provided for @mechanicalWork.
  ///
  /// In en, this message translates to:
  /// **'Mechanical Work on:'**
  String get mechanicalWork;

  /// No description provided for @electricalWork.
  ///
  /// In en, this message translates to:
  /// **'Electrical Work on:'**
  String get electricalWork;

  /// No description provided for @installationWork.
  ///
  /// In en, this message translates to:
  /// **'Work in Installation on:'**
  String get installationWork;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other:'**
  String get other;

  /// No description provided for @equipmentStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment - Stops'**
  String get equipmentStopsTitle;

  /// No description provided for @addEquipmentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get addEquipmentButton;

  /// No description provided for @viewEquipmentButton.
  ///
  /// In en, this message translates to:
  /// **'View Equipment'**
  String get viewEquipmentButton;

  /// No description provided for @verificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Information Verification'**
  String get verificationTitle;

  /// No description provided for @viewDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetailsButton;

  /// No description provided for @equipmentReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} equipment ready to be submitted'**
  String equipmentReadyMessage(Object count);

  /// No description provided for @equipmentAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Equipment added'**
  String get equipmentAddedMessage;

  /// No description provided for @finishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishButton;

  /// No description provided for @viewEquipmentList.
  ///
  /// In en, this message translates to:
  /// **'View Equipment List'**
  String get viewEquipmentList;

  /// No description provided for @equipmentListTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment List'**
  String get equipmentListTitle;

  /// No description provided for @noEquipmentMessage.
  ///
  /// In en, this message translates to:
  /// **'No equipment added yet'**
  String get noEquipmentMessage;

  /// No description provided for @equipmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Equipment Details'**
  String get equipmentDetails;

  /// No description provided for @mainCategory.
  ///
  /// In en, this message translates to:
  /// **'Main Category'**
  String get mainCategory;

  /// No description provided for @subCategory.
  ///
  /// In en, this message translates to:
  /// **'Sub Category'**
  String get subCategory;

  /// No description provided for @selectMainCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Main Category'**
  String get selectMainCategory;

  /// No description provided for @selectSubCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Sub Category'**
  String get selectSubCategory;

  /// No description provided for @selectEquipment.
  ///
  /// In en, this message translates to:
  /// **'Select Equipment'**
  String get selectEquipment;

  /// No description provided for @addAtLeastOneEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add at least one equipment before submitting.'**
  String get addAtLeastOneEquipment;

  /// No description provided for @equipmentSelection.
  ///
  /// In en, this message translates to:
  /// **'Equipment Selection'**
  String get equipmentSelection;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @equipmentModified.
  ///
  /// In en, this message translates to:
  /// **'Equipment modified'**
  String get equipmentModified;

  /// No description provided for @noEquipmentAdded.
  ///
  /// In en, this message translates to:
  /// **'No equipment added'**
  String get noEquipmentAdded;

  /// No description provided for @equipmentReadyToSubmit.
  ///
  /// In en, this message translates to:
  /// **'{count} equipment ready to be submitted'**
  String equipmentReadyToSubmit(Object count);

  /// No description provided for @editEquipment.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment'**
  String get editEquipment;

  /// No description provided for @viewAllReports.
  ///
  /// In en, this message translates to:
  /// **'View all reports'**
  String get viewAllReports;

  /// No description provided for @viewAllDetails.
  ///
  /// In en, this message translates to:
  /// **'View All Details'**
  String get viewAllDetails;

  /// No description provided for @dataVerification.
  ///
  /// In en, this message translates to:
  /// **'Data Verification'**
  String get dataVerification;

  /// No description provided for @step6Verification.
  ///
  /// In en, this message translates to:
  /// **'STEP 6: VERIFICATION'**
  String get step6Verification;

  /// No description provided for @selectNature.
  ///
  /// In en, this message translates to:
  /// **'Select nature'**
  String get selectNature;

  /// No description provided for @stopsList.
  ///
  /// In en, this message translates to:
  /// **'Stops List'**
  String get stopsList;

  /// No description provided for @countersList.
  ///
  /// In en, this message translates to:
  /// **'Counters List'**
  String get countersList;

  /// No description provided for @stockList.
  ///
  /// In en, this message translates to:
  /// **'Stock List'**
  String get stockList;

  /// No description provided for @liaisonCountersList.
  ///
  /// In en, this message translates to:
  /// **'Liaison Counters List'**
  String get liaisonCountersList;

  /// No description provided for @addLiaisonCounter.
  ///
  /// In en, this message translates to:
  /// **'Add Liaison Counter'**
  String get addLiaisonCounter;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @addCounter.
  ///
  /// In en, this message translates to:
  /// **'Add Counter'**
  String get addCounter;

  /// No description provided for @viewStops.
  ///
  /// In en, this message translates to:
  /// **'View Stops'**
  String get viewStops;

  /// No description provided for @viewCounters.
  ///
  /// In en, this message translates to:
  /// **'View Counters'**
  String get viewCounters;

  /// No description provided for @viewStock.
  ///
  /// In en, this message translates to:
  /// **'View Stock'**
  String get viewStock;

  /// No description provided for @viewLiaisonCounters.
  ///
  /// In en, this message translates to:
  /// **'View Liaison Counters'**
  String get viewLiaisonCounters;

  /// No description provided for @addStopForModule.
  ///
  /// In en, this message translates to:
  /// **'Add Stop - Module {module}'**
  String addStopForModule(Object module);

  /// No description provided for @addInformation.
  ///
  /// In en, this message translates to:
  /// **'Add Information'**
  String get addInformation;

  /// No description provided for @viewInformation.
  ///
  /// In en, this message translates to:
  /// **'View Information'**
  String get viewInformation;

  /// No description provided for @viewTrips.
  ///
  /// In en, this message translates to:
  /// **'View Trips'**
  String get viewTrips;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get tripDetails;

  /// No description provided for @truckList.
  ///
  /// In en, this message translates to:
  /// **'Truck List'**
  String get truckList;

  /// No description provided for @addTruckInfo.
  ///
  /// In en, this message translates to:
  /// **'Add Truck Information'**
  String get addTruckInfo;

  /// No description provided for @viewTruckInfo.
  ///
  /// In en, this message translates to:
  /// **'View Truck Information'**
  String get viewTruckInfo;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
