import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorage {
  static const String _prefix = 'onboarding_showcase_';

  /// Returns true if a specific showcase tutorial has already been shown.
  Future<bool> isTutorialCompleted(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$tutorialId') ?? false;
  }

  /// Marks a specific showcase tutorial as completed.
  Future<void> markTutorialAsCompleted(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$tutorialId', true);
  }

  /// Resets the completion state of a specific tutorial (useful for debugging/testing).
  Future<void> resetTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$tutorialId');
  }
}
