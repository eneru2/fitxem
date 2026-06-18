import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Fitxem'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get login;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @clockIn.
  ///
  /// In es, this message translates to:
  /// **'Fichar entrada'**
  String get clockIn;

  /// No description provided for @clockOut.
  ///
  /// In es, this message translates to:
  /// **'Fichar salida'**
  String get clockOut;

  /// No description provided for @breakStart.
  ///
  /// In es, this message translates to:
  /// **'Iniciar pausa'**
  String get breakStart;

  /// No description provided for @breakEnd.
  ///
  /// In es, this message translates to:
  /// **'Fin pausa'**
  String get breakEnd;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @admin.
  ///
  /// In es, this message translates to:
  /// **'Administración'**
  String get admin;

  /// No description provided for @employees.
  ///
  /// In es, this message translates to:
  /// **'Empleados'**
  String get employees;

  /// No description provided for @export.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @todayActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad de hoy'**
  String get todayActivity;

  /// No description provided for @inProgress.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get inProgress;

  /// No description provided for @noEvents.
  ///
  /// In es, this message translates to:
  /// **'Sin fichajes hoy'**
  String get noEvents;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @corrections.
  ///
  /// In es, this message translates to:
  /// **'Incidencias'**
  String get corrections;

  /// No description provided for @incidents.
  ///
  /// In es, this message translates to:
  /// **'Incidencias'**
  String get incidents;

  /// No description provided for @myIncidents.
  ///
  /// In es, this message translates to:
  /// **'Mis incidencias'**
  String get myIncidents;

  /// No description provided for @newIncident.
  ///
  /// In es, this message translates to:
  /// **'Nueva incidencia'**
  String get newIncident;

  /// No description provided for @requestAbsence.
  ///
  /// In es, this message translates to:
  /// **'Solicitar ausencia'**
  String get requestAbsence;

  /// No description provided for @myAbsences.
  ///
  /// In es, this message translates to:
  /// **'Mis ausencias'**
  String get myAbsences;

  /// No description provided for @ausencias.
  ///
  /// In es, this message translates to:
  /// **'Ausencias'**
  String get ausencias;

  /// No description provided for @approve.
  ///
  /// In es, this message translates to:
  /// **'Aprobar'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get reject;

  /// No description provided for @registerOrg.
  ///
  /// In es, this message translates to:
  /// **'Registrar empresa'**
  String get registerOrg;

  /// No description provided for @legalName.
  ///
  /// In es, this message translates to:
  /// **'Razón social'**
  String get legalName;

  /// No description provided for @cif.
  ///
  /// In es, this message translates to:
  /// **'CIF'**
  String get cif;

  /// No description provided for @ownerName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del responsable'**
  String get ownerName;

  /// No description provided for @ownerNif.
  ///
  /// In es, this message translates to:
  /// **'NIF del responsable'**
  String get ownerNif;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error. Inténtalo de nuevo.'**
  String get errorGeneric;

  /// No description provided for @errorConnection.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor.'**
  String get errorConnection;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El servicio no está disponible en este momento. Inténtalo más tarde.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorTimeout.
  ///
  /// In es, this message translates to:
  /// **'La solicitud tardó demasiado. Inténtalo de nuevo.'**
  String get errorTimeout;

  /// No description provided for @errorInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos introducidos.'**
  String get errorInvalidData;

  /// No description provided for @errorCifTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una empresa registrada con ese CIF.'**
  String get errorCifTaken;

  /// No description provided for @errorEmailTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese correo electrónico.'**
  String get errorEmailTaken;

  /// No description provided for @errorNifTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un empleado con ese NIF.'**
  String get errorNifTaken;

  /// No description provided for @invalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos'**
  String get invalidCredentials;

  /// No description provided for @lastEvent.
  ///
  /// In es, this message translates to:
  /// **'Último fichaje'**
  String get lastEvent;

  /// No description provided for @statusWorking.
  ///
  /// In es, this message translates to:
  /// **'Trabajando'**
  String get statusWorking;

  /// No description provided for @statusBreak.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get statusBreak;

  /// No description provided for @statusOut.
  ///
  /// In es, this message translates to:
  /// **'Fuera'**
  String get statusOut;

  /// No description provided for @dailyReport.
  ///
  /// In es, this message translates to:
  /// **'Informe diario'**
  String get dailyReport;

  /// No description provided for @clockInAt.
  ///
  /// In es, this message translates to:
  /// **'Entrada a las {time}'**
  String clockInAt(String time);

  /// No description provided for @totalWorked.
  ///
  /// In es, this message translates to:
  /// **'Total: {minutes} min'**
  String totalWorked(int minutes);

  /// No description provided for @debug.
  ///
  /// In es, this message translates to:
  /// **'DEBUG'**
  String get debug;

  /// No description provided for @correctionRequest.
  ///
  /// In es, this message translates to:
  /// **'Nueva incidencia'**
  String get correctionRequest;

  /// No description provided for @correctionRequestSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Indica qué pasó y la hora correcta.'**
  String get correctionRequestSubtitle;

  /// No description provided for @incidentForgotClock.
  ///
  /// In es, this message translates to:
  /// **'Olvidé fichar'**
  String get incidentForgotClock;

  /// No description provided for @incidentForgotClockDesc.
  ///
  /// In es, this message translates to:
  /// **'Falta un marcaje de entrada, salida o pausa.'**
  String get incidentForgotClockDesc;

  /// No description provided for @incidentWrongTime.
  ///
  /// In es, this message translates to:
  /// **'La hora no es correcta'**
  String get incidentWrongTime;

  /// No description provided for @incidentWrongTimeDesc.
  ///
  /// In es, this message translates to:
  /// **'Corregir la hora de un marcaje existente.'**
  String get incidentWrongTimeDesc;

  /// No description provided for @incidentOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get incidentOther;

  /// No description provided for @incidentOtherDesc.
  ///
  /// In es, this message translates to:
  /// **'Otro motivo relacionado con un fichaje.'**
  String get incidentOtherDesc;

  /// No description provided for @incidentScenario.
  ///
  /// In es, this message translates to:
  /// **'¿Qué ha pasado?'**
  String get incidentScenario;

  /// No description provided for @incidentSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get incidentSummary;

  /// No description provided for @statusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In es, this message translates to:
  /// **'Aprobada'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazada'**
  String get statusRejected;

  /// No description provided for @normalRecord.
  ///
  /// In es, this message translates to:
  /// **'Registro normal'**
  String get normalRecord;

  /// No description provided for @workedTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo trabajado'**
  String get workedTime;

  /// No description provided for @approvedIncidentBadge.
  ///
  /// In es, this message translates to:
  /// **'Incidencia aprobada'**
  String get approvedIncidentBadge;

  /// No description provided for @correctionDay.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get correctionDay;

  /// No description provided for @correctionTime.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get correctionTime;

  /// No description provided for @eventType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de fichaje'**
  String get eventType;

  /// No description provided for @proposedTime.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora correcta'**
  String get proposedTime;

  /// No description provided for @reason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get reason;

  /// No description provided for @reasonHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. olvidé fichar al salir'**
  String get reasonHint;

  /// No description provided for @submitCorrection.
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud'**
  String get submitCorrection;

  /// No description provided for @correctionSubmitted.
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada. Pendiente de aprobación.'**
  String get correctionSubmitted;

  /// No description provided for @selectDateTime.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha y hora'**
  String get selectDateTime;

  /// No description provided for @timeRecords.
  ///
  /// In es, this message translates to:
  /// **'Registros horarios'**
  String get timeRecords;

  /// No description provided for @marcajes.
  ///
  /// In es, this message translates to:
  /// **'Marcajes'**
  String get marcajes;

  /// No description provided for @noIncidentMinutes.
  ///
  /// In es, this message translates to:
  /// **'Tiempo trabajado'**
  String get noIncidentMinutes;

  /// No description provided for @noIncident.
  ///
  /// In es, this message translates to:
  /// **'Registro normal'**
  String get noIncident;

  /// No description provided for @correctionBadge.
  ///
  /// In es, this message translates to:
  /// **'Incidencia aprobada'**
  String get correctionBadge;

  /// No description provided for @absenceVacation.
  ///
  /// In es, this message translates to:
  /// **'Vacaciones'**
  String get absenceVacation;

  /// No description provided for @absenceSick.
  ///
  /// In es, this message translates to:
  /// **'Baja / enfermedad'**
  String get absenceSick;

  /// No description provided for @absencePersonal.
  ///
  /// In es, this message translates to:
  /// **'Permiso retribuido'**
  String get absencePersonal;

  /// No description provided for @absenceUnpaid.
  ///
  /// In es, this message translates to:
  /// **'Permiso no retribuido'**
  String get absenceUnpaid;

  /// No description provided for @absenceType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de ausencia'**
  String get absenceType;

  /// No description provided for @absenceStart.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get absenceStart;

  /// No description provided for @absenceEnd.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get absenceEnd;

  /// No description provided for @absenceSubmitted.
  ///
  /// In es, this message translates to:
  /// **'Solicitud de ausencia enviada.'**
  String get absenceSubmitted;

  /// No description provided for @absenceDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Ausencia'**
  String get absenceDayLabel;

  /// No description provided for @submitAbsence.
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud'**
  String get submitAbsence;

  /// No description provided for @originalTime.
  ///
  /// In es, this message translates to:
  /// **'Hora registrada'**
  String get originalTime;

  /// No description provided for @proposedTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Hora correcta'**
  String get proposedTimeLabel;

  /// No description provided for @forgotClockThisDay.
  ///
  /// In es, this message translates to:
  /// **'Olvidé fichar este día'**
  String get forgotClockThisDay;

  /// No description provided for @fixTime.
  ///
  /// In es, this message translates to:
  /// **'Corregir hora'**
  String get fixTime;

  /// No description provided for @fixTimeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Indica la hora correcta y el motivo.'**
  String get fixTimeSubtitle;

  /// No description provided for @tapFichajeHint.
  ///
  /// In es, this message translates to:
  /// **'Corregir'**
  String get tapFichajeHint;

  /// No description provided for @noRecordsForDay.
  ///
  /// In es, this message translates to:
  /// **'Sin fichajes'**
  String get noRecordsForDay;

  /// No description provided for @dayNotYetOccurred.
  ///
  /// In es, this message translates to:
  /// **'Este día aún no ha ocurrido'**
  String get dayNotYetOccurred;

  /// No description provided for @calendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get calendar;

  /// No description provided for @month.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get month;

  /// No description provided for @year.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get year;

  /// No description provided for @daySummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen del día'**
  String get daySummary;

  /// No description provided for @goToDay.
  ///
  /// In es, this message translates to:
  /// **'Ir a este día'**
  String get goToDay;

  /// No description provided for @gpsNotRecorded.
  ///
  /// In es, this message translates to:
  /// **'Ubicación GPS no registrada'**
  String get gpsNotRecorded;

  /// No description provided for @locationUnavailableGeoClue.
  ///
  /// In es, this message translates to:
  /// **'La ubicación no está disponible en este equipo: GeoClue no está instalado o en ejecución. Los fichajes se registrarán sin GPS.'**
  String get locationUnavailableGeoClue;

  /// No description provided for @locationDisabledLinux.
  ///
  /// In es, this message translates to:
  /// **'La ubicación está desactivada en el sistema. Actívala en Ajustes → Privacidad → Ubicación. Los fichajes se registrarán sin GPS.'**
  String get locationDisabledLinux;

  /// No description provided for @locationDesktopUnreliableLinux.
  ///
  /// In es, this message translates to:
  /// **'En Linux de escritorio la ubicación suele ser muy imprecisa (WiFi/IP). Usa el móvil o el navegador para registrar GPS fiable. Los fichajes desde aquí no incluirán coordenadas.'**
  String get locationDesktopUnreliableLinux;

  /// No description provided for @locationSkippedImprecise.
  ///
  /// In es, this message translates to:
  /// **'Fichaje registrado sin ubicación: la precisión GPS es insuficiente.'**
  String get locationSkippedImprecise;
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
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
