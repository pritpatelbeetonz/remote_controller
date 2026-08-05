import 'dart:ui';

/// A service to manage and detect country-related information for the device
/// and the user.
///
/// Designed to be modular so future methods like `getSelectedCountry`,
/// `saveSelectedCountry`, and `getAvailableCountries` can be easily added.
class CountryManager {
  // Singleton pattern for consistency in service architectures.
  static final CountryManager _instance = CountryManager._internal();

  factory CountryManager() => _instance;

  CountryManager._internal();

  /// Detects and returns the ISO 3166-1 alpha-2 country code of the device
  /// based solely on the current system locale settings.
  ///
  /// If the system country code is unavailable, empty, or cannot be resolved,
  /// this method returns a sensible default ("US").
  ///
  /// The returned country code is normalized (trimmed and converted to uppercase).
  ///
  /// Example Usage:
  /// ```dart
  /// final country = await CountryManager().getDeviceCountryCode();
  /// ```
  Future<String> getDeviceCountryCode() async {
    final locale = PlatformDispatcher.instance.locale;
    final rawCountryCode = locale.countryCode;

    // Log the current raw device locale settings
    print('🌍 Device Locale: $locale');

    if (rawCountryCode == null || rawCountryCode.trim().isEmpty) {
      const defaultCountry = 'US';
      print('🌍 Country Code (Fallback): $defaultCountry');
      return defaultCountry;
    }

    final normalizedCountry = rawCountryCode.trim().toUpperCase();
    print('🌍 Country Code: $normalizedCountry');

    return normalizedCountry;
  }

  // TODO: Add support for selected country storage
  // Future<String?> getSelectedCountry() async { ... }
  // Future<void> saveSelectedCountry(String countryCode) async { ... }

  // TODO: Add support for retrieving list of available countries
  // Future<List<String>> getAvailableCountries() async { ... }
}
