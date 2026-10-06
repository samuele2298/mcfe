import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

/// Stato della sessione: null = non autenticato.
class AuthNotifier extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() {
    final api = ref.read(apiProvider);
    api.onSessionExpired = () => state = const AsyncValue.data(null);
    _restore();
    return const AsyncValue.loading();
  }

  ApiClient get _api => ref.read(apiProvider);

  Future<void> _restore() async {
    await _api.restore();
    if (!_api.hasSession) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      state = AsyncValue.data(User.fromJson(await _api.get('/me') as Map<String, dynamic>));
    } catch (_) {
      await _api.clearSession();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> _applySession(dynamic res) async {
    await _api.setSession(res['accessToken'] as String, res['refreshToken'] as String);
    state = AsyncValue.data(User.fromJson(res['user'] as Map<String, dynamic>));
  }

  Future<void> login(String email, String password) async {
    await _applySession(await _api.post('/auth/login', {'email': email, 'password': password}));
  }

  Future<void> register(String email, String password, String? displayName) async {
    await _applySession(await _api.post('/auth/register', {
      'email': email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
    }));
  }

  Future<void> refreshUser() async {
    state = AsyncValue.data(User.fromJson(await _api.get('/me') as Map<String, dynamic>));
  }

  Future<void> logout() async {
    final token = _api.refreshToken;
    if (token != null) {
      try {
        await _api.post('/auth/logout', {'refreshToken': token});
      } catch (_) {}
    }
    await _api.clearSession();
    state = const AsyncValue.data(null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<User?>>(AuthNotifier.new);

final themesProvider = FutureProvider<List<ThemeInfo>>((ref) async {
  final list = await ref.read(apiProvider).get('/puzzles/themes') as List;
  return list.map((e) => ThemeInfo.fromJson(e as Map<String, dynamic>)).toList();
});
