import 'package:dio/dio.dart';
import 'package:fitxem/l10n/app_localizations.dart';

/// Turns API/network failures into short, user-facing messages.
String apiErrorMessage(AppLocalizations l10n, Object error) {
  if (error is! DioException) {
    return l10n.errorGeneric;
  }

  final apiMessage = _extractApiMessage(error);
  if (apiMessage != null) {
    return _friendlyApiMessage(l10n, apiMessage);
  }

  return _dioTypeMessage(l10n, error);
}

String? _extractApiMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['error'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
  }
  return null;
}

String _friendlyApiMessage(AppLocalizations l10n, String raw) {
  final normalized = raw.replaceFirst(RegExp(r'^create org:\s*'), '');
  final lower = normalized.toLowerCase();

  if (lower.contains('invalid credentials')) {
    return l10n.invalidCredentials;
  }
  if (lower.contains('invalid json')) {
    return l10n.errorInvalidData;
  }
  if (lower.contains('organizations_cif') ||
      (lower.contains('duplicate') && lower.contains('cif'))) {
    return l10n.errorCifTaken;
  }
  if (lower.contains('duplicate') &&
      (lower.contains('email') || lower.contains('users'))) {
    return l10n.errorEmailTaken;
  }
  if (lower.contains('duplicate') &&
      (lower.contains('nif') || lower.contains('employees'))) {
    return l10n.errorNifTaken;
  }
  if (_looksLikeInfrastructureError(lower)) {
    return l10n.errorServiceUnavailable;
  }
  if (_looksLikeInternalError(lower)) {
    return l10n.errorGeneric;
  }

  return normalized;
}

bool _looksLikeInfrastructureError(String lower) {
  return lower.contains('connection refused') ||
      lower.contains('dial tcp') ||
      lower.contains('failed to connect') ||
      lower.contains('connect: connection') ||
      lower.contains('no connection') ||
      lower.contains('network is unreachable') ||
      lower.contains('no such host') ||
      lower.contains('connection reset');
}

bool _looksLikeInternalError(String lower) {
  return lower.contains('sqlstate') ||
      lower.contains('violates') ||
      lower.contains('pq:') ||
      lower.startsWith('error:');
}

String _dioTypeMessage(AppLocalizations l10n, DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return l10n.errorTimeout;
    case DioExceptionType.connectionError:
      return l10n.errorConnection;
    case DioExceptionType.badResponse:
      if (error.response?.statusCode == 401) {
        return l10n.invalidCredentials;
      }
      final status = error.response?.statusCode ?? 0;
      if (status >= 500) {
        return l10n.errorServiceUnavailable;
      }
      return l10n.errorGeneric;
    default:
      return l10n.errorGeneric;
  }
}
