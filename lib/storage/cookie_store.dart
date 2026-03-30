import 'package:shared_preferences/shared_preferences.dart';

class CookieStore {
  static const _key = 'cookie';

  static Future<String?> getCookie() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_key);
    if (v == null) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  static Future<void> setCookie(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, value.trim());
  }
}

