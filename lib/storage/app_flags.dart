import 'package:shared_preferences/shared_preferences.dart';

class AppFlags {
  static const _kAutoRefreshed = 'auto_refreshed_once';

  static Future<bool> getAutoRefreshedOnce() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAutoRefreshed) ?? false;
  }

  static Future<void> setAutoRefreshedOnce() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoRefreshed, true);
  }
}

