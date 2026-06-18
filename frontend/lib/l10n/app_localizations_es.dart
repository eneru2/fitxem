// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Fitxem';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get clockIn => 'Fichar entrada';

  @override
  String get clockOut => 'Fichar salida';

  @override
  String get breakStart => 'Iniciar pausa';

  @override
  String get breakEnd => 'Fin pausa';

  @override
  String get history => 'Historial';

  @override
  String get admin => 'Administración';

  @override
  String get employees => 'Empleados';

  @override
  String get export => 'Exportar';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get today => 'Hoy';

  @override
  String get todayActivity => 'Actividad de hoy';

  @override
  String get inProgress => 'En curso';

  @override
  String get noEvents => 'Sin fichajes hoy';

  @override
  String get settings => 'Ajustes';

  @override
  String get corrections => 'Incidencias';

  @override
  String get incidents => 'Incidencias';

  @override
  String get myIncidents => 'Mis incidencias';

  @override
  String get newIncident => 'Nueva incidencia';

  @override
  String get requestAbsence => 'Solicitar ausencia';

  @override
  String get myAbsences => 'Mis ausencias';

  @override
  String get ausencias => 'Ausencias';

  @override
  String get approve => 'Aprobar';

  @override
  String get reject => 'Rechazar';

  @override
  String get registerOrg => 'Registrar empresa';

  @override
  String get legalName => 'Razón social';

  @override
  String get cif => 'CIF';

  @override
  String get ownerName => 'Nombre del responsable';

  @override
  String get ownerNif => 'NIF del responsable';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get errorGeneric => 'Ha ocurrido un error. Inténtalo de nuevo.';

  @override
  String get errorConnection => 'No se pudo conectar con el servidor.';

  @override
  String get errorServiceUnavailable =>
      'El servicio no está disponible en este momento. Inténtalo más tarde.';

  @override
  String get errorTimeout =>
      'La solicitud tardó demasiado. Inténtalo de nuevo.';

  @override
  String get errorInvalidData => 'Revisa los datos introducidos.';

  @override
  String get errorCifTaken => 'Ya existe una empresa registrada con ese CIF.';

  @override
  String get errorEmailTaken =>
      'Ya existe una cuenta con ese correo electrónico.';

  @override
  String get errorNifTaken => 'Ya existe un empleado con ese NIF.';

  @override
  String get invalidCredentials => 'Correo o contraseña incorrectos';

  @override
  String get lastEvent => 'Último fichaje';

  @override
  String get statusWorking => 'Trabajando';

  @override
  String get statusBreak => 'En pausa';

  @override
  String get statusOut => 'Fuera';

  @override
  String get dailyReport => 'Informe diario';

  @override
  String clockInAt(String time) {
    return 'Entrada a las $time';
  }

  @override
  String totalWorked(int minutes) {
    return 'Total: $minutes min';
  }

  @override
  String get debug => 'DEBUG';

  @override
  String get correctionRequest => 'Nueva incidencia';

  @override
  String get correctionRequestSubtitle => 'Indica qué pasó y la hora correcta.';

  @override
  String get incidentForgotClock => 'Olvidé fichar';

  @override
  String get incidentForgotClockDesc =>
      'Falta un marcaje de entrada, salida o pausa.';

  @override
  String get incidentWrongTime => 'La hora no es correcta';

  @override
  String get incidentWrongTimeDesc =>
      'Corregir la hora de un marcaje existente.';

  @override
  String get incidentOther => 'Otro';

  @override
  String get incidentOtherDesc => 'Otro motivo relacionado con un fichaje.';

  @override
  String get incidentScenario => '¿Qué ha pasado?';

  @override
  String get incidentSummary => 'Resumen';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusApproved => 'Aprobada';

  @override
  String get statusRejected => 'Rechazada';

  @override
  String get normalRecord => 'Registro normal';

  @override
  String get workedTime => 'Tiempo trabajado';

  @override
  String get approvedIncidentBadge => 'Incidencia aprobada';

  @override
  String get correctionDay => 'Día';

  @override
  String get correctionTime => 'Hora';

  @override
  String get eventType => 'Tipo de fichaje';

  @override
  String get proposedTime => 'Fecha y hora correcta';

  @override
  String get reason => 'Motivo';

  @override
  String get reasonHint => 'Ej. olvidé fichar al salir';

  @override
  String get submitCorrection => 'Enviar solicitud';

  @override
  String get correctionSubmitted =>
      'Solicitud enviada. Pendiente de aprobación.';

  @override
  String get selectDateTime => 'Seleccionar fecha y hora';

  @override
  String get timeRecords => 'Registros horarios';

  @override
  String get marcajes => 'Marcajes';

  @override
  String get noIncidentMinutes => 'Tiempo trabajado';

  @override
  String get noIncident => 'Registro normal';

  @override
  String get correctionBadge => 'Incidencia aprobada';

  @override
  String get absenceVacation => 'Vacaciones';

  @override
  String get absenceSick => 'Baja / enfermedad';

  @override
  String get absencePersonal => 'Permiso retribuido';

  @override
  String get absenceUnpaid => 'Permiso no retribuido';

  @override
  String get absenceType => 'Tipo de ausencia';

  @override
  String get absenceStart => 'Desde';

  @override
  String get absenceEnd => 'Hasta';

  @override
  String get absenceSubmitted => 'Solicitud de ausencia enviada.';

  @override
  String get absenceDayLabel => 'Ausencia';

  @override
  String get submitAbsence => 'Enviar solicitud';

  @override
  String get originalTime => 'Hora registrada';

  @override
  String get proposedTimeLabel => 'Hora correcta';

  @override
  String get forgotClockThisDay => 'Olvidé fichar este día';

  @override
  String get fixTime => 'Corregir hora';

  @override
  String get fixTimeSubtitle => 'Indica la hora correcta y el motivo.';

  @override
  String get tapFichajeHint => 'Corregir';

  @override
  String get noRecordsForDay => 'Sin fichajes';

  @override
  String get dayNotYetOccurred => 'Este día aún no ha ocurrido';

  @override
  String get calendar => 'Calendario';

  @override
  String get month => 'Mes';

  @override
  String get year => 'Año';

  @override
  String get daySummary => 'Resumen del día';

  @override
  String get goToDay => 'Ir a este día';

  @override
  String get gpsNotRecorded => 'Ubicación GPS no registrada';

  @override
  String get locationUnavailableGeoClue =>
      'La ubicación no está disponible en este equipo: GeoClue no está instalado o en ejecución. Los fichajes se registrarán sin GPS.';

  @override
  String get locationDisabledLinux =>
      'La ubicación está desactivada en el sistema. Actívala en Ajustes → Privacidad → Ubicación. Los fichajes se registrarán sin GPS.';

  @override
  String get locationDesktopUnreliableLinux =>
      'En Linux de escritorio la ubicación suele ser muy imprecisa (WiFi/IP). Usa el móvil o el navegador para registrar GPS fiable. Los fichajes desde aquí no incluirán coordenadas.';

  @override
  String get locationSkippedImprecise =>
      'Fichaje registrado sin ubicación: la precisión GPS es insuficiente.';
}
