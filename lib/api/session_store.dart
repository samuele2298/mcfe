import 'package:shared_preferences/shared_preferences.dart';

/// Salva i token di sessione nel browser (localStorage).
class SessionStore {
  static const _access = 'cm.access';
  static const _refresh = 'cm.refresh';

  Future<(String?, String?)> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_access), p.getString(_refresh));
  }

  Future<void> save(String access, String refresh) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_access, access);
    await p.setString(_refresh, refresh);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_access);
    await p.remove(_refresh);
  }
}
