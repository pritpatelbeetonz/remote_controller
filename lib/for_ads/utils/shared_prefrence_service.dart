import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefService {
  static SharedPreferences? _sharedPreferences;

  static const String isFirstTimeLaunch = 'isFirstTimeLaunch';

  // Initialize SharedPreferences (must be called before any SeaArt methods)
  static Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  // Getter with null check
  static SharedPreferences get sharedPreferences  {
    if (_sharedPreferences == null) {
      throw Exception('SharedPreferences not initialized. Call init() first.');
    }
    return _sharedPreferences!;
  }

  static Future<void> setIsFirstTime(bool value) async {
    await sharedPreferences.setBool(isFirstTimeLaunch, value);
  }

  static bool getIsFirstTime() {
    return sharedPreferences.getBool(isFirstTimeLaunch) ?? true;
  }

  static Future<void> setUsedFreePlan(bool value) async {
    await sharedPreferences.setBool('usedFreePlan', value);
  }

  static Future<bool> hasUsedFreePlan() async {
    return sharedPreferences.getBool('usedFreePlan') ?? false;
  }

}