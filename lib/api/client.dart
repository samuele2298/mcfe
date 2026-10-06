import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Client HTTP verso mcbe: JSON, bearer token e rinnovo automatico della sessione.
class ApiClient {
  ApiClient({SessionStore? store, http.Client? http_})
      : _store = store ?? SessionStore(),
        _http = http_ ?? http.Client();

  final SessionStore _store;
  final http.Client _http;
  String? _access;
  String? _refresh;
  Future<bool>? _refreshing;

  /// Chiamato quando la sessione non è più rinnovabile.
  void Function()? onSessionExpired;

  bool get hasSession => _refresh != null;

  Future<void> restore() async {
    final (a, r) = await _store.load();
    _access = a;
    _refresh = r;
  }

  Future<void> setSession(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _store.save(access, refresh);
  }

  Future<void> clearSession() async {
    _access = null;
    _refresh = null;
    await _store.clear();
  }

  String? get refreshToken => _refresh;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = query == null
        ? null
        : {for (final e in query.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final base = Uri.parse(apiUrl.startsWith('/') ? '${Uri.base.origin}$apiUrl' : apiUrl);
    return base.replace(
      path: '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path',
      queryParameters: q == null || q.isEmpty ? null : q,
    );
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    bool retried = false,
  }) async {
    final req = http.Request(method, _uri(path, query));
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (_access != null) req.headers['authorization'] = 'Bearer $_access';

    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 401 && !retried && _refresh != null && !path.startsWith('/auth/')) {
      if (await _refreshSession()) {
        return _send(method, path, query: query, body: body, retried: true);
      }
      onSessionExpired?.call();
    }
    final text = utf8.decode(res.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final code = json is Map && json['error'] is String ? json['error'] as String : 'http_${res.statusCode}';
      throw ApiException(res.statusCode, code);
    }
    return json;
  }

  Future<bool> _refreshSession() {
    return _refreshing ??= () async {
      try {
        final res = await post('/auth/refresh', {'refreshToken': _refresh});
        await setSession(res['accessToken'] as String, res['refreshToken'] as String);
        return true;
      } catch (_) {
        await clearSession();
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }
}
