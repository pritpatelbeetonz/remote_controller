import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'onboarding_storage.dart';

class OnboardingService {
  final OnboardingStorage _storage = OnboardingStorage();

  void initialize() {
    ShowcaseView.register(
      // Configure default settings for all showcases globally.
      enableShowcase: true,
      autoPlay: false,
      enableAutoScroll: true,
      blurValue: 4.0,
      overlayColor: const Color(0xFF070B19),
      overlayOpacity: 0.6,
    );
  }

  /// Checks if a tutorial should be displayed, and starts it if it hasn't been shown before.
  Future<void> startTutorialIfNeeded(
    BuildContext context, {
    required String tutorialId,
    required List<GlobalKey> keys,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    final isCompleted = await _storage.isTutorialCompleted(tutorialId);
    if (!isCompleted && keys.isNotEmpty) {
      // Start showcase using the recommended ShowCaseWidget context helper
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(keys);
      });
      // Mark as completed so it is only shown once
      await _storage.markTutorialAsCompleted(tutorialId);
    }
  }

  /// Forces starting a tutorial regardless of whether it was shown before.
  void forceStartTutorial(BuildContext context, List<GlobalKey> keys) {
    if (keys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(keys);
      });
    }
  }
}
