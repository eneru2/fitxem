import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fitxem/config.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/models/incident_request.dart';
import 'package:fitxem/services/session_events.dart';

final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final dioProvider = Provider((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  Completer<void>? refreshCompleter;

  Future<bool> refreshTokens() async {
    if (refreshCompleter != null) {
      try {
        await refreshCompleter!.future;
        return true;
      } catch (_) {
        return false;
      }
    }

    refreshCompleter = Completer<void>();
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        throw StateError('missing refresh token');
      }

      final bare = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));
      final res = await bare.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      await storage.write(
        key: 'access_token',
        value: data['access_token'] as String,
      );
      await storage.write(
        key: 'refresh_token',
        value: data['refresh_token'] as String,
      );
      refreshCompleter!.complete();
      return true;
    } catch (e) {
      refreshCompleter!.completeError(e);
      await storage.deleteAll();
      sessionExpiredController.add(null);
      return false;
    } finally {
      refreshCompleter = null;
    }
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      final status = error.response?.statusCode;
      final path = error.requestOptions.path;
      if (status != 401 || path.startsWith('/auth/')) {
        handler.next(error);
        return;
      }

      if (await refreshTokens()) {
        final token = await storage.read(key: 'access_token');
        final opts = error.requestOptions;
        if (token != null) {
          opts.headers['Authorization'] = 'Bearer $token';
        }
        try {
          handler.resolve(await dio.fetch(opts));
          return;
        } catch (_) {
          // Fall through to propagate the original error.
        }
      }

      handler.next(error);
    },
  ));
  return dio;
});

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(dioProvider)));

class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> registerOrg(Map<String, dynamic> data) async {
    final res = await _dio.post('/auth/register-org', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> todayStatus() async {
    final res = await _dio.get('/me/today');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<ClockEvent>> myRecords({String? from, String? to}) async {
    final res = await _dio.get('/me/records', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['events'] as List? ?? []);
    return raw
        .map((e) => ClockEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> clock(
    String endpoint, {
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{};
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }
    final res = await _dio.post('/clock/$endpoint', data: data.isEmpty ? null : data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getOrg() async {
    final res = await _dio.get('/me/org');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> listEmployees() async {
    final res = await _dio.get('/admin/employees');
    final data = res.data as Map<String, dynamic>;
    return List<dynamic>.from(data['employees'] as List? ?? []);
  }

  Future<List<dynamic>> dailyReport({String? from, String? to}) async {
    final res = await _dio.get('/admin/reports/daily', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    final data = res.data as Map<String, dynamic>;
    return List<dynamic>.from(data['records'] as List? ?? []);
  }

  Future<List<int>> exportData(String format, {String? from, String? to}) async {
    final res = await _dio.get<List<int>>(
      '/admin/exports',
      queryParameters: {
        'format': format,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? [];
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final res = await _dio.post('/admin/employees', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<IncidentRequest>> listMyIncidents() async {
    final res = await _dio.get('/me/corrections');
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['corrections'] as List? ?? []);
    return raw
        .map((e) => IncidentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<IncidentRequest>> listCorrections() async {
    final res = await _dio.get('/admin/corrections');
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['corrections'] as List? ?? []);
    return raw
        .map((e) => IncidentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> reviewCorrection(String id, bool approve) async {
    await _dio.patch('/admin/corrections/$id', data: {'approve': approve});
  }

  Future<IncidentRequest> createCorrection({
    required String employeeId,
    required String eventType,
    required DateTime proposedAt,
    required String reason,
    String incidentType = 'other',
    String? relatedEventId,
  }) async {
    final res = await _dio.post('/corrections', data: {
      'employee_id': employeeId,
      'event_type': eventType,
      'proposed_at': proposedAt.toUtc().toIso8601String(),
      'reason': reason,
      'incident_type': incidentType,
      if (relatedEventId != null) 'related_event_id': relatedEventId,
    });
    return IncidentRequest.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<AbsenceRequest>> listMyAbsences() async {
    final res = await _dio.get('/me/absences');
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['absences'] as List? ?? []);
    return raw
        .map((e) => AbsenceRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AbsenceRequest>> listAbsencesInRange({
    required String from,
    required String to,
  }) async {
    final res = await _dio.get('/me/absences/range', queryParameters: {
      'from': from,
      'to': to,
    });
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['absences'] as List? ?? []);
    return raw
        .map((e) => AbsenceRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AbsenceRequest>> listAbsences() async {
    final res = await _dio.get('/admin/absences');
    final data = res.data as Map<String, dynamic>;
    final raw = List<dynamic>.from(data['absences'] as List? ?? []);
    return raw
        .map((e) => AbsenceRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> reviewAbsence(String id, bool approve) async {
    await _dio.patch('/admin/absences/$id', data: {'approve': approve});
  }

  Future<AbsenceRequest> createAbsence({
    required String employeeId,
    required String absenceType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _dio.post('/absences', data: {
      'employee_id': employeeId,
      'absence_type': absenceType,
      'start_date': fmt(startDate),
      'end_date': fmt(endDate),
      'reason': reason,
    });
    return AbsenceRequest.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
