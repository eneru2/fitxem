import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/services/session_events.dart';

class AuthState {
  const AuthState({this.isAuthenticated = false, this.role, this.email});
  final bool isAuthenticated;
  final String? role;
  final String? email;

  bool get isAdmin => role == 'owner' || role == 'admin';

  AuthState copyWith({bool? isAuthenticated, String? role, String? email}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      email: email ?? this.email,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage, this._api) : super(const AuthState()) {
    _load();
    _sessionExpiredSub = sessionExpiredController.stream.listen((_) {
      state = const AuthState();
    });
  }

  final FlutterSecureStorage _storage;
  final ApiClient _api;
  late final StreamSubscription<void> _sessionExpiredSub;

  @override
  void dispose() {
    _sessionExpiredSub.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await _storage.read(key: 'access_token');
    final role = await _storage.read(key: 'role');
    final email = await _storage.read(key: 'email');
    if (token != null) {
      state = AuthState(isAuthenticated: true, role: role, email: email);
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.login(email, password);
    await _storage.write(key: 'access_token', value: data['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: data['refresh_token'] as String);
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'role', value: data['role'] as String? ?? 'employee');
    state = AuthState(
      isAuthenticated: true,
      email: email,
      role: data['role'] as String? ?? 'employee',
    );
  }

  Future<void> registerOrg(Map<String, dynamic> data) async {
    final res = await _api.registerOrg(data);
    await _storage.write(key: 'access_token', value: res['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: res['refresh_token'] as String);
    await _storage.write(key: 'email', value: data['owner_email'] as String);
    await _storage.write(key: 'role', value: 'owner');
    state = AuthState(isAuthenticated: true, role: 'owner', email: data['owner_email'] as String);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(secureStorageProvider),
    ref.watch(apiClientProvider),
  );
});
