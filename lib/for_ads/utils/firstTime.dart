import 'package:shared_preferences/shared_preferences.dart';

class Check{
  static late SharedPreferences _prefs;

  // Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Store a boolean value
  static Future<void> setFirstTime(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  // Retrieve a boolean value, return true if not found
  static bool isFirstTime(String key) {
    return _prefs.getBool(key) ?? true;
  }
}