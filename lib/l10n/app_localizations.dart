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

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @sendToSheets.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendToSheets;

  /// No description provided for @sendToSheetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to Google Sheets?'**
  String get sendToSheetsTitle;

  /// No description provided for @sendToSheetsMessage.
  ///
  /// In en, this message translates to:
  /// **'This will save the report to Google Sheets and lock editing on this device. You can still view it, and deleting it locally will not remove it from Google Sheets.'**
  String get sendToSheetsMessage;

  /// No description provided for @reportSentToSheets.
  ///
  /// In en, this message translates to:
  /// **'Report saved to Google Sheets.'**
  String get reportSentToSheets;

  /// No description provided for @reportAlreadySentToSheets.
  ///
  /// In en, this message translates to:
  /// **'This report is already saved in Google Sheets.'**
  String get reportAlreadySentToSheets;

  /// No description provided for @reportSendToSheetsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the report to Google Sheets.'**
  String get reportSendToSheetsFailed;

  /// No description provided for @reportSentToSheetsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This report is read-only after being saved to Google Sheets.'**
  String get reportSentToSheetsReadOnly;

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

  /// No description provided for @operatingHoursExceeded.
  ///
  /// In en, this message translates to:
  /// **'Operating hours ({hours}h) exceed the maximum allowed duration for this poste ({maxHours}h).'**
  String operatingHoursExceeded(int hours, int maxHours);

  /// No description provided for @carryOver.
  ///
  /// In en, this message translates to:
  /// **'Carry-over'**
  String get carryOver;

  /// No description provided for @carriedOverFrom.
  ///
  /// In en, this message translates to:
  /// **'Carried over from {poste}'**
  String carriedOverFrom(String poste);

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

  /// No description provided for @defautLabel.
  ///
  /// In en, this message translates to:
  /// **'Defect'**
  String get defautLabel;

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
  String equipmentReadyMessage(int count);

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
  String equipmentReadyToSubmit(int count);

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
  /// **'View all details'**
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
  String addStopForModule(String module);

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

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @availableReports.
  ///
  /// In en, this message translates to:
  /// **'Available Reports'**
  String get availableReports;

  /// No description provided for @ocpReports.
  ///
  /// In en, this message translates to:
  /// **'OCP Reports'**
  String get ocpReports;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @r0Description.
  ///
  /// In en, this message translates to:
  /// **'Equipment operation'**
  String get r0Description;

  /// No description provided for @activityReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily activities (TNB)'**
  String get activityReportDescription;

  /// No description provided for @dailyReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Shift summary (TSUD)'**
  String get dailyReportDescription;

  /// No description provided for @truckTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Movement monitoring'**
  String get truckTrackingDescription;

  /// No description provided for @machinesStoppedTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Machines Stopped'**
  String get machinesStoppedTitleShort;

  /// No description provided for @machinesStoppedDescription.
  ///
  /// In en, this message translates to:
  /// **'Downtime log'**
  String get machinesStoppedDescription;

  /// No description provided for @reportsArchive.
  ///
  /// In en, this message translates to:
  /// **'Reports Archive'**
  String get reportsArchive;

  /// No description provided for @reportsArchiveDescription.
  ///
  /// In en, this message translates to:
  /// **'History & Logs'**
  String get reportsArchiveDescription;

  /// No description provided for @editTruckTracking.
  ///
  /// In en, this message translates to:
  /// **'Edit Truck Tracking'**
  String get editTruckTracking;

  /// No description provided for @newTruckTracking.
  ///
  /// In en, this message translates to:
  /// **'New Truck Tracking'**
  String get newTruckTracking;

  /// No description provided for @stepInfos.
  ///
  /// In en, this message translates to:
  /// **'Infos'**
  String get stepInfos;

  /// No description provided for @stepCamions.
  ///
  /// In en, this message translates to:
  /// **'Trucks'**
  String get stepCamions;

  /// No description provided for @stepVoyages.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get stepVoyages;

  /// No description provided for @stepVerif.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get stepVerif;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @newTruckLabel.
  ///
  /// In en, this message translates to:
  /// **'New Truck'**
  String get newTruckLabel;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @addTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Truck'**
  String get addTruckTitle;

  /// No description provided for @truckNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck Number'**
  String get truckNumberLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @addTrip.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get addTrip;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get editTrip;

  /// No description provided for @tripLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get tripLabel;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @tripsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String tripsCountLabel(int count);

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// No description provided for @mineZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mine / Zone'**
  String get mineZoneLabel;

  /// No description provided for @tripsByEquipment.
  ///
  /// In en, this message translates to:
  /// **'Trips per Equipment'**
  String get tripsByEquipment;

  /// No description provided for @tripsByTruck.
  ///
  /// In en, this message translates to:
  /// **'Trips per Truck'**
  String get tripsByTruck;

  /// No description provided for @tripDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get tripDetailsTitle;

  /// No description provided for @invalidStopStartTimeForPoste.
  ///
  /// In en, this message translates to:
  /// **'Start time must fall within the selected shift time range.'**
  String get invalidStopStartTimeForPoste;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @longStopCarryOverNotice.
  ///
  /// In en, this message translates to:
  /// **'Long stop detected. Reports were created for the subsequent shifts/day. Please start a new report if the stop continues.'**
  String get longStopCarryOverNotice;

  /// No description provided for @unknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownLabel;

  /// No description provided for @modifierR0.
  ///
  /// In en, this message translates to:
  /// **'Edit R0 Report'**
  String get modifierR0;

  /// No description provided for @nouveauRapportR0.
  ///
  /// In en, this message translates to:
  /// **'New R0 Report'**
  String get nouveauRapportR0;

  /// No description provided for @stepCompteur.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get stepCompteur;

  /// No description provided for @stepArrets.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stepArrets;

  /// No description provided for @stepExploit.
  ///
  /// In en, this message translates to:
  /// **'Exploitation'**
  String get stepExploit;

  /// No description provided for @stepRepartition.
  ///
  /// In en, this message translates to:
  /// **'Repartition'**
  String get stepRepartition;

  /// No description provided for @stepPersonnel.
  ///
  /// In en, this message translates to:
  /// **'Personnel'**
  String get stepPersonnel;

  /// No description provided for @stepConsom.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get stepConsom;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @selectPosteMessage.
  ///
  /// In en, this message translates to:
  /// **'Please choose a poste.'**
  String get selectPosteMessage;

  /// No description provided for @counterEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Counter Entry - {poste} Poste'**
  String counterEntryTitle(String poste);

  /// No description provided for @startCounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Start (Index)'**
  String get startCounterLabel;

  /// No description provided for @endCounterLabel.
  ///
  /// In en, this message translates to:
  /// **'End (Index)'**
  String get endCounterLabel;

  /// No description provided for @noStopsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No stops recorded.'**
  String get noStopsRecorded;

  /// No description provided for @addArretTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Stop'**
  String get addArretTitle;

  /// No description provided for @heuresMarche.
  ///
  /// In en, this message translates to:
  /// **'H.M'**
  String get heuresMarche;

  /// No description provided for @heuresArret.
  ///
  /// In en, this message translates to:
  /// **'H.A'**
  String get heuresArret;

  /// No description provided for @tonnageLabel.
  ///
  /// In en, this message translates to:
  /// **'Tonnage'**
  String get tonnageLabel;

  /// No description provided for @metrageFore.
  ///
  /// In en, this message translates to:
  /// **'Drilling m'**
  String get metrageFore;

  /// No description provided for @nrTrousFores.
  ///
  /// In en, this message translates to:
  /// **'Nr Drilled'**
  String get nrTrousFores;

  /// No description provided for @nrVoyages.
  ///
  /// In en, this message translates to:
  /// **'Nr Trips'**
  String get nrVoyages;

  /// No description provided for @m3Decapage.
  ///
  /// In en, this message translates to:
  /// **'M³ Strippe'**
  String get m3Decapage;

  /// No description provided for @nombreTKU.
  ///
  /// In en, this message translates to:
  /// **'Nr T.K.U'**
  String get nombreTKU;

  /// No description provided for @rendementSimple.
  ///
  /// In en, this message translates to:
  /// **'Yield'**
  String get rendementSimple;

  /// No description provided for @rendementLabel.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get rendementLabel;

  /// No description provided for @chantierLabel.
  ///
  /// In en, this message translates to:
  /// **'Worksite'**
  String get chantierLabel;

  /// No description provided for @gasoilLabel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get gasoilLabel;

  /// No description provided for @modifierRTNB.
  ///
  /// In en, this message translates to:
  /// **'Edit TNB Report'**
  String get modifierRTNB;

  /// No description provided for @infoLabel.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoLabel;

  /// No description provided for @arretCount.
  ///
  /// In en, this message translates to:
  /// **'Stop {index}'**
  String arretCount(int index);

  /// No description provided for @dureeLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get dureeLabel;

  /// No description provided for @natureLabel.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get natureLabel;

  /// No description provided for @ajButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ajButton;

  /// No description provided for @cvibrLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibrator Counter'**
  String get cvibrLabel;

  /// No description provided for @cliaisonLabel.
  ///
  /// In en, this message translates to:
  /// **'Liaison Counter'**
  String get cliaisonLabel;

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockLabel;

  /// No description provided for @aucunArret.
  ///
  /// In en, this message translates to:
  /// **'No stops added'**
  String get aucunArret;

  /// No description provided for @aucunCompteurVibr.
  ///
  /// In en, this message translates to:
  /// **'No vibrator counter added'**
  String get aucunCompteurVibr;

  /// No description provided for @aucunCompteurLiaison.
  ///
  /// In en, this message translates to:
  /// **'No liaison counter added'**
  String get aucunCompteurLiaison;

  /// No description provided for @aucuneEntreeStock.
  ///
  /// In en, this message translates to:
  /// **'No stock entry added'**
  String get aucuneEntreeStock;

  /// No description provided for @zone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zone;

  /// No description provided for @operation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operation;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @synthesis.
  ///
  /// In en, this message translates to:
  /// **'Synthesis'**
  String get synthesis;

  /// No description provided for @synthesisModule.
  ///
  /// In en, this message translates to:
  /// **'Synthesis Module {module}'**
  String synthesisModule(int module);

  /// No description provided for @functioning.
  ///
  /// In en, this message translates to:
  /// **'Functioning'**
  String get functioning;

  /// No description provided for @stops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stops;

  /// No description provided for @complement.
  ///
  /// In en, this message translates to:
  /// **'Nature (complement)'**
  String get complement;

  /// No description provided for @maxCharactersMessage.
  ///
  /// In en, this message translates to:
  /// **'Maximum 20 characters per line'**
  String get maxCharactersMessage;

  /// No description provided for @engines.
  ///
  /// In en, this message translates to:
  /// **'ENGINS'**
  String get engines;

  /// No description provided for @machines.
  ///
  /// In en, this message translates to:
  /// **'MACHINES'**
  String get machines;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get normal;

  /// No description provided for @oceane.
  ///
  /// In en, this message translates to:
  /// **'OCEANE'**
  String get oceane;

  /// No description provided for @pb30.
  ///
  /// In en, this message translates to:
  /// **'PB30'**
  String get pb30;

  /// No description provided for @premierPosteShort.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get premierPosteShort;

  /// No description provided for @deuxiemePosteShort.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get deuxiemePosteShort;

  /// No description provided for @troisiemePosteShort.
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get troisiemePosteShort;

  /// No description provided for @park1.
  ///
  /// In en, this message translates to:
  /// **'PARK 1'**
  String get park1;

  /// No description provided for @park2.
  ///
  /// In en, this message translates to:
  /// **'PARK 2'**
  String get park2;

  /// No description provided for @park3.
  ///
  /// In en, this message translates to:
  /// **'PARK 3'**
  String get park3;

  /// No description provided for @activityTnb.
  ///
  /// In en, this message translates to:
  /// **'Activity TNB'**
  String get activityTnb;

  /// No description provided for @editActivityTnb.
  ///
  /// In en, this message translates to:
  /// **'Edit Activity TNB'**
  String get editActivityTnb;

  /// No description provided for @dailyTsud.
  ///
  /// In en, this message translates to:
  /// **'Daily Report TSUD'**
  String get dailyTsud;

  /// No description provided for @editDailyTsud.
  ///
  /// In en, this message translates to:
  /// **'Edit Daily Report TSUD'**
  String get editDailyTsud;

  /// No description provided for @repartitionTravail.
  ///
  /// In en, this message translates to:
  /// **'Work Repartition'**
  String get repartitionTravail;

  /// No description provided for @mineSortie.
  ///
  /// In en, this message translates to:
  /// **'Mine/Exit'**
  String get mineSortie;

  /// No description provided for @engin.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engin;

  /// No description provided for @detailsArrets.
  ///
  /// In en, this message translates to:
  /// **'Stops Details'**
  String get detailsArrets;

  /// No description provided for @addCounterShort.
  ///
  /// In en, this message translates to:
  /// **'Add Count'**
  String get addCounterShort;

  /// No description provided for @vibratorCounterShort.
  ///
  /// In en, this message translates to:
  /// **'Vibr. Counter'**
  String get vibratorCounterShort;

  /// No description provided for @liaisonCounterShort.
  ///
  /// In en, this message translates to:
  /// **'Liais. Counter'**
  String get liaisonCounterShort;

  /// No description provided for @defeuitage.
  ///
  /// In en, this message translates to:
  /// **'Defeuilltage'**
  String get defeuitage;

  /// No description provided for @reprise.
  ///
  /// In en, this message translates to:
  /// **'Reprise'**
  String get reprise;

  /// No description provided for @sterile.
  ///
  /// In en, this message translates to:
  /// **'Sterile'**
  String get sterile;

  /// No description provided for @chargeuse992k.
  ///
  /// In en, this message translates to:
  /// **'Loader 992K'**
  String get chargeuse992k;

  /// No description provided for @chargeuse994h.
  ///
  /// In en, this message translates to:
  /// **'Loader 994H'**
  String get chargeuse994h;

  /// No description provided for @pelleHydraulique.
  ///
  /// In en, this message translates to:
  /// **'Hydraulic Shovel'**
  String get pelleHydraulique;

  /// No description provided for @pelleElectriqueB1.
  ///
  /// In en, this message translates to:
  /// **'Electric Shovel B1'**
  String get pelleElectriqueB1;

  /// No description provided for @arretTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop {index}'**
  String arretTitle(int index);

  /// No description provided for @cvibrTitle.
  ///
  /// In en, this message translates to:
  /// **'Vibr. Counter {index}'**
  String cvibrTitle(int index);

  /// No description provided for @cliaisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Liais. Counter {index}'**
  String cliaisonTitle(int index);

  /// No description provided for @stockEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Entry {index}'**
  String stockEntryTitle(int index);

  /// No description provided for @poste1er.
  ///
  /// In en, this message translates to:
  /// **'1st Shift'**
  String get poste1er;

  /// No description provided for @poste2eme.
  ///
  /// In en, this message translates to:
  /// **'2nd Shift'**
  String get poste2eme;

  /// No description provided for @poste3eme.
  ///
  /// In en, this message translates to:
  /// **'3rd Shift'**
  String get poste3eme;

  /// No description provided for @stockTypeNormal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get stockTypeNormal;

  /// No description provided for @stockTypeOceane.
  ///
  /// In en, this message translates to:
  /// **'OCEANE'**
  String get stockTypeOceane;

  /// No description provided for @stockTypePb30.
  ///
  /// In en, this message translates to:
  /// **'PB30'**
  String get stockTypePb30;

  /// No description provided for @sector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get sector;

  /// No description provided for @reportNo.
  ///
  /// In en, this message translates to:
  /// **'Report N°'**
  String get reportNo;

  /// No description provided for @machinesEquipment.
  ///
  /// In en, this message translates to:
  /// **'Machines/Equipment'**
  String get machinesEquipment;

  /// No description provided for @poste.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
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

  /// No description provided for @editArret.
  ///
  /// In en, this message translates to:
  /// **'Edit Stop'**
  String get editArret;

  /// No description provided for @deleteArret.
  ///
  /// In en, this message translates to:
  /// **'Delete Stop'**
  String get deleteArret;

  /// No description provided for @editCounter.
  ///
  /// In en, this message translates to:
  /// **'Edit Counter'**
  String get editCounter;

  /// No description provided for @catMiniLoaders.
  ///
  /// In en, this message translates to:
  /// **'Mini Loaders'**
  String get catMiniLoaders;

  /// No description provided for @catTruckLoaders.
  ///
  /// In en, this message translates to:
  /// **'Truck Loaders'**
  String get catTruckLoaders;

  /// No description provided for @deleteCounter.
  ///
  /// In en, this message translates to:
  /// **'Delete Counter'**
  String get deleteCounter;

  /// No description provided for @editStock.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock'**
  String get editStock;

  /// No description provided for @deleteStock.
  ///
  /// In en, this message translates to:
  /// **'Delete Stock'**
  String get deleteStock;

  /// No description provided for @allPostes.
  ///
  /// In en, this message translates to:
  /// **'All Shifts'**
  String get allPostes;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get clearFilter;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noReportsFoundForPoste.
  ///
  /// In en, this message translates to:
  /// **'No reports found for shift {poste}'**
  String noReportsFoundForPoste(String poste);

  /// No description provided for @seeAllReports.
  ///
  /// In en, this message translates to:
  /// **'See all reports'**
  String get seeAllReports;

  /// No description provided for @reportsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reports} =1{1 report} other{{count} reports}} found for shift {poste}'**
  String reportsFound(int count, String poste);

  /// No description provided for @totalVoyages.
  ///
  /// In en, this message translates to:
  /// **'Total Trips'**
  String get totalVoyages;

  /// No description provided for @dataSummary.
  ///
  /// In en, this message translates to:
  /// **'Data Summary'**
  String get dataSummary;

  /// No description provided for @stopDataNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Stoppage data not available'**
  String get stopDataNotAvailable;

  /// No description provided for @vibratorCountersLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibrator Counters'**
  String get vibratorCountersLabel;

  /// No description provided for @liaisonCountersLabel.
  ///
  /// In en, this message translates to:
  /// **'Liaison Counters'**
  String get liaisonCountersLabel;

  /// No description provided for @parkLabel.
  ///
  /// In en, this message translates to:
  /// **'Park'**
  String get parkLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantityLabel;

  /// No description provided for @operatingTime.
  ///
  /// In en, this message translates to:
  /// **'Operating Time'**
  String get operatingTime;

  /// No description provided for @stopTime.
  ///
  /// In en, this message translates to:
  /// **'Stop Time'**
  String get stopTime;

  /// No description provided for @machinesStoppedLabel.
  ///
  /// In en, this message translates to:
  /// **'Stopped Machines/Equipment'**
  String get machinesStoppedLabel;

  /// No description provided for @noEquipmentStopped.
  ///
  /// In en, this message translates to:
  /// **'No equipment stopped'**
  String get noEquipmentStopped;

  /// No description provided for @equipmentIndex.
  ///
  /// In en, this message translates to:
  /// **'{index, plural, =1{Equipment 1} other{Equipment {index}}}'**
  String equipmentIndex(int index);

  /// No description provided for @module1Label.
  ///
  /// In en, this message translates to:
  /// **'Module 1'**
  String get module1Label;

  /// No description provided for @module2Label.
  ///
  /// In en, this message translates to:
  /// **'Module 2'**
  String get module2Label;

  /// No description provided for @stopsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stopsLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @repartitionLabel.
  ///
  /// In en, this message translates to:
  /// **'Repartition'**
  String get repartitionLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @imputationLabel.
  ///
  /// In en, this message translates to:
  /// **'Imputation'**
  String get imputationLabel;

  /// No description provided for @personnelLabel.
  ///
  /// In en, this message translates to:
  /// **'Personnel'**
  String get personnelLabel;

  /// No description provided for @conductorLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get conductorLabel;

  /// No description provided for @graisseurLabel.
  ///
  /// In en, this message translates to:
  /// **'Greaser'**
  String get graisseurLabel;

  /// No description provided for @matriculeLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get matriculeLabel;

  /// No description provided for @consommationLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get consommationLabel;

  /// No description provided for @triconeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tricone'**
  String get triconeLabel;

  /// No description provided for @operationLabel.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operationLabel;

  /// No description provided for @equipmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipmentLabel;

  /// No description provided for @qualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get qualityLabel;

  /// No description provided for @camionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Trucks'**
  String get camionsLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @deleteStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this stop?'**
  String get deleteStopConfirm;

  /// No description provided for @calculatedAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Calculated automatically (Stops, Counter)'**
  String get calculatedAutoHint;

  /// No description provided for @addWorkDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a work distribution'**
  String get addWorkDistributionTitle;

  /// No description provided for @editWorkDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit work distribution'**
  String get editWorkDistributionTitle;

  /// No description provided for @deleteWorkDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete work distribution'**
  String get deleteWorkDistributionTitle;

  /// No description provided for @deleteWorkDistributionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this work distribution?'**
  String get deleteWorkDistributionConfirm;

  /// No description provided for @editPersonnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit personnel'**
  String get editPersonnelTitle;

  /// No description provided for @editConsumptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit consumption'**
  String get editConsumptionTitle;

  /// No description provided for @deleteCounterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this counter?'**
  String get deleteCounterConfirm;

  /// No description provided for @startTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTimeLabel;

  /// No description provided for @endTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTimeLabel;

  /// No description provided for @selectTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTimeTitle;

  /// No description provided for @selectCategoryStep.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategoryStep;

  /// No description provided for @selectStopTypeStep.
  ///
  /// In en, this message translates to:
  /// **'Select stop type'**
  String get selectStopTypeStep;

  /// No description provided for @enterDetailsStep.
  ///
  /// In en, this message translates to:
  /// **'Enter details'**
  String get enterDetailsStep;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @deleteTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the truck'**
  String get deleteTruckTitle;

  /// No description provided for @deleteTruckConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this truck?'**
  String get deleteTruckConfirm;

  /// No description provided for @noCountersAdded.
  ///
  /// In en, this message translates to:
  /// **'No counters added'**
  String get noCountersAdded;

  /// No description provided for @noStopsAdded.
  ///
  /// In en, this message translates to:
  /// **'No stops added'**
  String get noStopsAdded;

  /// No description provided for @noExploitationData.
  ///
  /// In en, this message translates to:
  /// **'No exploitation data'**
  String get noExploitationData;

  /// No description provided for @noPersonnelData.
  ///
  /// In en, this message translates to:
  /// **'No personnel data'**
  String get noPersonnelData;

  /// No description provided for @noConsumptionData.
  ///
  /// In en, this message translates to:
  /// **'No consumption data'**
  String get noConsumptionData;

  /// No description provided for @editReportType.
  ///
  /// In en, this message translates to:
  /// **'Edit - {type}'**
  String editReportType(String type);

  /// No description provided for @equipmentLabelWithIndex.
  ///
  /// In en, this message translates to:
  /// **'Equipment {index}:'**
  String equipmentLabelWithIndex(int index);

  /// No description provided for @totalFor.
  ///
  /// In en, this message translates to:
  /// **'Total for {key}: {value}'**
  String totalFor(String key, String value);

  /// No description provided for @tripLabelWithIndex.
  ///
  /// In en, this message translates to:
  /// **'v{index}: '**
  String tripLabelWithIndex(int index);

  /// No description provided for @workLabelWithIndex.
  ///
  /// In en, this message translates to:
  /// **'Work {index}'**
  String workLabelWithIndex(int index);

  /// No description provided for @voyagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Voyages'**
  String get voyagesLabel;

  /// No description provided for @additionalDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional data'**
  String get additionalDataLabel;

  /// No description provided for @addStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Stop'**
  String get addStopTitle;

  /// No description provided for @editStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Stop'**
  String get editStopTitle;

  /// No description provided for @deleteStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Stop'**
  String get deleteStopTitle;

  /// No description provided for @addVibratorCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Vibrator Counter'**
  String get addVibratorCounterTitle;

  /// No description provided for @editVibratorCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vibrator Counter'**
  String get editVibratorCounterTitle;

  /// No description provided for @deleteVibratorCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Vibrator Counter'**
  String get deleteVibratorCounterTitle;

  /// No description provided for @addLiaisonCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Liaison Counter'**
  String get addLiaisonCounterTitle;

  /// No description provided for @editLiaisonCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Liaison Counter'**
  String get editLiaisonCounterTitle;

  /// No description provided for @deleteLiaisonCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Liaison Counter'**
  String get deleteLiaisonCounterTitle;

  /// No description provided for @addStockEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Stock Entry'**
  String get addStockEntryTitle;

  /// No description provided for @editStockEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock Entry'**
  String get editStockEntryTitle;

  /// No description provided for @deleteStockEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Stock Entry'**
  String get deleteStockEntryTitle;

  /// No description provided for @addCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Counter'**
  String get addCounterTitle;

  /// No description provided for @editCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Counter'**
  String get editCounterTitle;

  /// No description provided for @deleteCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Counter'**
  String get deleteCounterTitle;

  /// No description provided for @editExploitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Exploitation'**
  String get editExploitationTitle;

  /// No description provided for @predefinedNatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Predefined nature'**
  String get predefinedNatureLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (e.g., 1h 30)'**
  String get durationLabel;

  /// No description provided for @complementLabel.
  ///
  /// In en, this message translates to:
  /// **'Nature (complement)'**
  String get complementLabel;

  /// No description provided for @maxCharactersHint.
  ///
  /// In en, this message translates to:
  /// **'Maximum 20 characters per line'**
  String get maxCharactersHint;

  /// No description provided for @moduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get moduleLabel;

  /// No description provided for @parkTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Park Type'**
  String get parkTypeLabel;

  /// No description provided for @hmLabel.
  ///
  /// In en, this message translates to:
  /// **'H.M'**
  String get hmLabel;

  /// No description provided for @haLabel.
  ///
  /// In en, this message translates to:
  /// **'H.A'**
  String get haLabel;

  /// No description provided for @rendemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get rendemeLabel;

  /// No description provided for @conductrLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get conductrLabel;

  /// No description provided for @matriculesLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial Numbers'**
  String get matriculesLabel;

  /// No description provided for @noLiaisonCountersAdded.
  ///
  /// In en, this message translates to:
  /// **'No liaison counter added'**
  String get noLiaisonCountersAdded;

  /// No description provided for @noStockEntriesAdded.
  ///
  /// In en, this message translates to:
  /// **'No stock entry added'**
  String get noStockEntriesAdded;

  /// No description provided for @calculatedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Calculated automatically (Stops, Counter)'**
  String get calculatedAutomatically;

  /// No description provided for @stocksLabel.
  ///
  /// In en, this message translates to:
  /// **'Stocks'**
  String get stocksLabel;

  /// No description provided for @exploitationLabel.
  ///
  /// In en, this message translates to:
  /// **'Exploitation'**
  String get exploitationLabel;

  /// No description provided for @tempsLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get tempsLabel;

  /// No description provided for @finishLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishLabel;

  /// No description provided for @infoOibEeLabel.
  ///
  /// In en, this message translates to:
  /// **'Info OIB/EE'**
  String get infoOibEeLabel;

  /// No description provided for @modifyLabel.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modifyLabel;

  /// No description provided for @arretsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get arretsLabel;

  /// No description provided for @deleteStockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this stock entry?'**
  String get deleteStockConfirm;

  /// No description provided for @editLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String editLabel(String label);

  /// No description provided for @noMachinesStopped.
  ///
  /// In en, this message translates to:
  /// **'No machines stopped'**
  String get noMachinesStopped;

  /// No description provided for @reportDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Report Date'**
  String get reportDateLabel;

  /// No description provided for @mainCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Main Category'**
  String get mainCategoryLabel;

  /// No description provided for @subCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub Category'**
  String get subCategoryLabel;

  /// No description provided for @stopReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop Reason'**
  String get stopReasonLabel;

  /// No description provided for @enterStopReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter stop reason...'**
  String get enterStopReasonHint;

  /// No description provided for @groupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// No description provided for @deleteEquipment.
  ///
  /// In en, this message translates to:
  /// **'Delete Equipment'**
  String get deleteEquipment;

  /// No description provided for @deleteEquipmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this equipment?'**
  String get deleteEquipmentConfirm;

  /// No description provided for @vibrTitle.
  ///
  /// In en, this message translates to:
  /// **'Vibrator Counters'**
  String get vibrTitle;

  /// No description provided for @liaisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Liaison Counters'**
  String get liaisonTitle;

  /// No description provided for @workDistributionLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Distribution'**
  String get workDistributionLabel;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @noTrucksAdded.
  ///
  /// In en, this message translates to:
  /// **'No trucks added'**
  String get noTrucksAdded;

  /// No description provided for @summaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryLabel;

  /// No description provided for @noStockAdded.
  ///
  /// In en, this message translates to:
  /// **'No stock added'**
  String get noStockAdded;

  /// No description provided for @stopsWithColon.
  ///
  /// In en, this message translates to:
  /// **'Stops:'**
  String get stopsWithColon;

  /// No description provided for @tripsWithColon.
  ///
  /// In en, this message translates to:
  /// **'Trips:'**
  String get tripsWithColon;

  /// No description provided for @tripsSummary.
  ///
  /// In en, this message translates to:
  /// **'Trips Summary'**
  String get tripsSummary;

  /// No description provided for @noActivityData.
  ///
  /// In en, this message translates to:
  /// **'No activity data available.'**
  String get noActivityData;

  /// No description provided for @noDailyData.
  ///
  /// In en, this message translates to:
  /// **'No daily data available.'**
  String get noDailyData;

  /// No description provided for @noTruckTrackingData.
  ///
  /// In en, this message translates to:
  /// **'No truck tracking data available.'**
  String get noTruckTrackingData;

  /// No description provided for @noR0Data.
  ///
  /// In en, this message translates to:
  /// **'No R0 data available.'**
  String get noR0Data;

  /// No description provided for @noAdditionalData.
  ///
  /// In en, this message translates to:
  /// **'No additional data'**
  String get noAdditionalData;

  /// No description provided for @noTripsAdded.
  ///
  /// In en, this message translates to:
  /// **'No trips added.'**
  String get noTripsAdded;

  /// No description provided for @updateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating: {error}'**
  String updateError(String error);

  /// No description provided for @stockTitleIndex.
  ///
  /// In en, this message translates to:
  /// **'Stock {index}'**
  String stockTitleIndex(int index);

  /// No description provided for @tripTime.
  ///
  /// In en, this message translates to:
  /// **'Trip Time'**
  String get tripTime;

  /// No description provided for @genericCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Counter {index}'**
  String genericCounterTitle(int index);

  /// No description provided for @workTitleIndex.
  ///
  /// In en, this message translates to:
  /// **'Work {index}'**
  String workTitleIndex(int index);

  /// No description provided for @driverParam.
  ///
  /// In en, this message translates to:
  /// **'Driver: {driver}'**
  String driverParam(String driver);

  /// No description provided for @truckParam.
  ///
  /// In en, this message translates to:
  /// **'Truck: {truck}'**
  String truckParam(String truck);

  /// No description provided for @typeParam.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String typeParam(String type);

  /// No description provided for @reasonParam.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonParam(String reason);

  /// No description provided for @endParam.
  ///
  /// In en, this message translates to:
  /// **'End: {end}'**
  String endParam(String end);

  /// No description provided for @trackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Tracking - {date} - {poste}'**
  String trackingDescription(String date, String poste);

  /// No description provided for @catBulldozers.
  ///
  /// In en, this message translates to:
  /// **'BULLDOZERS'**
  String get catBulldozers;

  /// No description provided for @catTrucks.
  ///
  /// In en, this message translates to:
  /// **'TRUCKS'**
  String get catTrucks;

  /// No description provided for @catLoaders.
  ///
  /// In en, this message translates to:
  /// **'LOADERS'**
  String get catLoaders;

  /// No description provided for @catGraders.
  ///
  /// In en, this message translates to:
  /// **'GRADERS'**
  String get catGraders;

  /// No description provided for @catPaydozers.
  ///
  /// In en, this message translates to:
  /// **'PAYDOZERS'**
  String get catPaydozers;

  /// No description provided for @catHydraulicShovels.
  ///
  /// In en, this message translates to:
  /// **'HYDRAULIC SHOVELS'**
  String get catHydraulicShovels;

  /// No description provided for @catDraglines.
  ///
  /// In en, this message translates to:
  /// **'DRAGLINES'**
  String get catDraglines;

  /// No description provided for @catElectricShovels.
  ///
  /// In en, this message translates to:
  /// **'ELECTRIC SHOVELS'**
  String get catElectricShovels;

  /// No description provided for @catDrills.
  ///
  /// In en, this message translates to:
  /// **'DRILLS'**
  String get catDrills;

  /// No description provided for @catExterior.
  ///
  /// In en, this message translates to:
  /// **'EXTERNAL'**
  String get catExterior;

  /// No description provided for @catMaterial.
  ///
  /// In en, this message translates to:
  /// **'MATERIAL'**
  String get catMaterial;

  /// No description provided for @catExploitation.
  ///
  /// In en, this message translates to:
  /// **'EXPLOITATION'**
  String get catExploitation;

  /// No description provided for @stopIndustrialArea.
  ///
  /// In en, this message translates to:
  /// **'INDUSTRIAL AREA STOP'**
  String get stopIndustrialArea;

  /// No description provided for @stopPowerCut.
  ///
  /// In en, this message translates to:
  /// **'GENERAL POWER CUT'**
  String get stopPowerCut;

  /// No description provided for @stopStrike.
  ///
  /// In en, this message translates to:
  /// **'STRIKE'**
  String get stopStrike;

  /// No description provided for @stopWeather.
  ///
  /// In en, this message translates to:
  /// **'BAD WEATHER'**
  String get stopWeather;

  /// No description provided for @stopFullStocks.
  ///
  /// In en, this message translates to:
  /// **'FULL STOCKS'**
  String get stopFullStocks;

  /// No description provided for @stopHolidays.
  ///
  /// In en, this message translates to:
  /// **'HOLIDAYS OR WEEKLY'**
  String get stopHolidays;

  /// No description provided for @stopPowerPlant.
  ///
  /// In en, this message translates to:
  /// **'POWER PLANT STOP'**
  String get stopPowerPlant;

  /// No description provided for @stopControl.
  ///
  /// In en, this message translates to:
  /// **'CONTROL'**
  String get stopControl;

  /// No description provided for @stopElecFault.
  ///
  /// In en, this message translates to:
  /// **'ELEC FAULT (CABLE, NETWORK)'**
  String get stopElecFault;

  /// No description provided for @stopMechBreakdown.
  ///
  /// In en, this message translates to:
  /// **'MECHANICAL BREAKDOWN'**
  String get stopMechBreakdown;

  /// No description provided for @stopElecBreakdown.
  ///
  /// In en, this message translates to:
  /// **'ELECTRICAL BREAKDOWN'**
  String get stopElecBreakdown;

  /// No description provided for @stopTireWorkshop.
  ///
  /// In en, this message translates to:
  /// **'TIRE WORKSHOP INTERVENTION'**
  String get stopTireWorkshop;

  /// No description provided for @stopMaintenance.
  ///
  /// In en, this message translates to:
  /// **'SYSTEMATIC MAINTENANCE'**
  String get stopMaintenance;

  /// No description provided for @stopRefill.
  ///
  /// In en, this message translates to:
  /// **'REFILL (OIL, DIESEL, WATER)'**
  String get stopRefill;

  /// No description provided for @stopGreasing.
  ///
  /// In en, this message translates to:
  /// **'GREASING'**
  String get stopGreasing;

  /// No description provided for @stopFixedInstallElec.
  ///
  /// In en, this message translates to:
  /// **'FIXED INSTALLATION ELEC STOP'**
  String get stopFixedInstallElec;

  /// No description provided for @stopNoTrucks.
  ///
  /// In en, this message translates to:
  /// **'NO TRUCKS'**
  String get stopNoTrucks;

  /// No description provided for @stopNoBull.
  ///
  /// In en, this message translates to:
  /// **'NO BULLDOZER'**
  String get stopNoBull;

  /// No description provided for @stopNoMechanic.
  ///
  /// In en, this message translates to:
  /// **'NO MECHANIC'**
  String get stopNoMechanic;

  /// No description provided for @stopNoTools.
  ///
  /// In en, this message translates to:
  /// **'NO WORK TOOLS'**
  String get stopNoTools;

  /// No description provided for @stopMachineStopped.
  ///
  /// In en, this message translates to:
  /// **'MACHINE STOPPED'**
  String get stopMachineStopped;

  /// No description provided for @stopBreakdownFront.
  ///
  /// In en, this message translates to:
  /// **'EQUIPMENT BREAKDOWN IN FRONT'**
  String get stopBreakdownFront;

  /// No description provided for @stopShiftChange.
  ///
  /// In en, this message translates to:
  /// **'SHIFT CHANGE'**
  String get stopShiftChange;

  /// No description provided for @stopPlatformExec.
  ///
  /// In en, this message translates to:
  /// **'PLATFORM EXECUTION'**
  String get stopPlatformExec;

  /// No description provided for @stopMove.
  ///
  /// In en, this message translates to:
  /// **'MOVE'**
  String get stopMove;

  /// No description provided for @stopBlasting.
  ///
  /// In en, this message translates to:
  /// **'BLASTING'**
  String get stopBlasting;

  /// No description provided for @stopCableMove.
  ///
  /// In en, this message translates to:
  /// **'CABLE MOVE'**
  String get stopCableMove;

  /// No description provided for @stopDecidedStop.
  ///
  /// In en, this message translates to:
  /// **'DECIDED STOP'**
  String get stopDecidedStop;

  /// No description provided for @stopNoDriver.
  ///
  /// In en, this message translates to:
  /// **'NO DRIVER'**
  String get stopNoDriver;

  /// No description provided for @stopBreak.
  ///
  /// In en, this message translates to:
  /// **'BREAK'**
  String get stopBreak;

  /// No description provided for @stopTracks.
  ///
  /// In en, this message translates to:
  /// **'TRACKS (EXCL. WEATHER)'**
  String get stopTracks;

  /// No description provided for @stopFixedInstallMech.
  ///
  /// In en, this message translates to:
  /// **'FIXED INSTALLATION MECH STOP'**
  String get stopFixedInstallMech;

  /// No description provided for @stopTelescoping.
  ///
  /// In en, this message translates to:
  /// **'TELESCOPING'**
  String get stopTelescoping;

  /// No description provided for @stopPureExcavation.
  ///
  /// In en, this message translates to:
  /// **'PURE EXCAVATION'**
  String get stopPureExcavation;

  /// No description provided for @stopPureEarthworks.
  ///
  /// In en, this message translates to:
  /// **'PURE EARTHWORKS'**
  String get stopPureEarthworks;

  /// No description provided for @trackingType.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get trackingType;

  /// No description provided for @reportDescriptionPattern.
  ///
  /// In en, this message translates to:
  /// **'{type} - {date} - {poste}'**
  String reportDescriptionPattern(String type, String date, String poste);

  /// No description provided for @deleteCounterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete counter'**
  String get deleteCounterTooltip;

  /// No description provided for @editCounterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit counter'**
  String get editCounterTooltip;

  /// No description provided for @stopIndex.
  ///
  /// In en, this message translates to:
  /// **'Stop {index}'**
  String stopIndex(int index);

  /// No description provided for @loader992k.
  ///
  /// In en, this message translates to:
  /// **'Loader 992K'**
  String get loader992k;

  /// No description provided for @loader994h.
  ///
  /// In en, this message translates to:
  /// **'Loader 994H'**
  String get loader994h;

  /// No description provided for @hydraulicShovel.
  ///
  /// In en, this message translates to:
  /// **'Hydraulic Shovel'**
  String get hydraulicShovel;

  /// No description provided for @electricShovelB1.
  ///
  /// In en, this message translates to:
  /// **'Electric Shovel B1'**
  String get electricShovelB1;

  /// No description provided for @selectTruckLabel.
  ///
  /// In en, this message translates to:
  /// **'Select truck'**
  String get selectTruckLabel;

  /// No description provided for @truckLabel.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get truckLabel;

  /// No description provided for @driverInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver information'**
  String get driverInfoLabel;

  /// No description provided for @editR0Title.
  ///
  /// In en, this message translates to:
  /// **'Edit R0 Report'**
  String get editR0Title;

  /// No description provided for @editTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Truck'**
  String get editTruckTitle;

  /// No description provided for @newTruckTitle.
  ///
  /// In en, this message translates to:
  /// **'New Truck'**
  String get newTruckTitle;

  /// No description provided for @machinesEquipmentStoppedTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Machines/Equipment Stopped'**
  String get machinesEquipmentStoppedTitleShort;

  /// No description provided for @conducteurLabel.
  ///
  /// In en, this message translates to:
  /// **'Conductor'**
  String get conducteurLabel;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @r0ValidationMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Date, model, and shift are required to save the R0 report.'**
  String get r0ValidationMissingFields;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorMessage(String message);

  /// No description provided for @errorUpdate.
  ///
  /// In en, this message translates to:
  /// **'Error during update: {message}'**
  String errorUpdate(String message);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @allSheets.
  ///
  /// In en, this message translates to:
  /// **'All sheets'**
  String get allSheets;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @stopMustRemainInWindow.
  ///
  /// In en, this message translates to:
  /// **'The stop must remain within the 22:30 → 22:30 window.'**
  String get stopMustRemainInWindow;

  /// No description provided for @stopFinishedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Stop finished successfully.'**
  String get stopFinishedSuccessfully;

  /// No description provided for @selectStopCategory.
  ///
  /// In en, this message translates to:
  /// **'Select stop category'**
  String get selectStopCategory;

  /// No description provided for @selectStopType.
  ///
  /// In en, this message translates to:
  /// **'Select stop type'**
  String get selectStopType;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get selectLocation;

  /// No description provided for @applyToBothModules.
  ///
  /// In en, this message translates to:
  /// **'Apply to both modules'**
  String get applyToBothModules;

  /// No description provided for @deleteSelectedReports.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected report(s)?'**
  String deleteSelectedReports(int count);

  /// No description provided for @posteValue.
  ///
  /// In en, this message translates to:
  /// **'Shift: {poste}'**
  String posteValue(String poste);

  /// No description provided for @gatTripsValue.
  ///
  /// In en, this message translates to:
  /// **'GAT Trips: {trips}'**
  String gatTripsValue(String trips);

  /// No description provided for @terexTripsValue.
  ///
  /// In en, this message translates to:
  /// **'TEREX Trips: {trips}'**
  String terexTripsValue(String trips);

  /// No description provided for @parkValue.
  ///
  /// In en, this message translates to:
  /// **'Park: {park}'**
  String parkValue(String park);

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete {label}'**
  String deleteLabel(String label);

  /// No description provided for @shiftHasStockAlready.
  ///
  /// In en, this message translates to:
  /// **'This shift already has a stock.'**
  String get shiftHasStockAlready;

  /// No description provided for @vModule.
  ///
  /// In en, this message translates to:
  /// **'v{index}'**
  String vModule(int index);

  /// No description provided for @workLabel.
  ///
  /// In en, this message translates to:
  /// **'Work {index}'**
  String workLabel(int index);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @finishModule1.
  ///
  /// In en, this message translates to:
  /// **'Finish M1 #{index}'**
  String finishModule1(int index);

  /// No description provided for @finishModule2.
  ///
  /// In en, this message translates to:
  /// **'Finish M2 #{index}'**
  String finishModule2(int index);

  /// No description provided for @reportsDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{count} report(s) deleted successfully'**
  String reportsDeletedSuccessfully(int count);

  /// No description provided for @firstPoste.
  ///
  /// In en, this message translates to:
  /// **'1st Shift'**
  String get firstPoste;

  /// No description provided for @secondPoste.
  ///
  /// In en, this message translates to:
  /// **'2nd Shift'**
  String get secondPoste;

  /// No description provided for @thirdPoste.
  ///
  /// In en, this message translates to:
  /// **'3rd Shift'**
  String get thirdPoste;

  /// No description provided for @global.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get global;

  /// No description provided for @qualityTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality Type'**
  String get qualityTypeLabel;

  /// No description provided for @trucksTitle.
  ///
  /// In en, this message translates to:
  /// **'Trucks Management'**
  String get trucksTitle;

  /// No description provided for @dailyReportTsudTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Report TSUD'**
  String get dailyReportTsudTitle;

  /// No description provided for @editDailyReportTsudTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Daily Report TSUD'**
  String get editDailyReportTsudTitle;

  /// No description provided for @stepArretsM1.
  ///
  /// In en, this message translates to:
  /// **'Stops M1'**
  String get stepArretsM1;

  /// No description provided for @stepArretsM2.
  ///
  /// In en, this message translates to:
  /// **'Stops M2'**
  String get stepArretsM2;

  /// No description provided for @stepStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stepStock;

  /// No description provided for @stopInProgress.
  ///
  /// In en, this message translates to:
  /// **'Stop in progress'**
  String get stopInProgress;

  /// No description provided for @actionsArret.
  ///
  /// In en, this message translates to:
  /// **'Stop actions'**
  String get actionsArret;

  /// No description provided for @addArretModule.
  ///
  /// In en, this message translates to:
  /// **'Add Stop (Module {index})'**
  String addArretModule(int index);

  /// No description provided for @catArretLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop category'**
  String get catArretLabel;

  /// No description provided for @typeArretLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop type'**
  String get typeArretLabel;

  /// No description provided for @lieuArretLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop location'**
  String get lieuArretLabel;

  /// No description provided for @detailArretLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop detail'**
  String get detailArretLabel;

  /// No description provided for @applyToBothModulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Apply to both modules 1 and 2.'**
  String get applyToBothModulesDesc;

  /// No description provided for @requiredFieldsTruckError.
  ///
  /// In en, this message translates to:
  /// **'The date, station and machine/engine are mandatory to save the report.'**
  String get requiredFieldsTruckError;

  /// No description provided for @dashboardTab.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTab;

  /// No description provided for @archiveTab.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTab;

  /// No description provided for @timelineTab.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTab;

  /// No description provided for @swipeLeftHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left (or tap Sheets above) to open reports'**
  String get swipeLeftHint;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;
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
