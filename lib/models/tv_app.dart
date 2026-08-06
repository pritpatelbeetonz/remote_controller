/// Represents a curated TV application in the catalog.
class TVApp {
  /// The Android package name / app identifier (e.g. 'com.netflix.ninja')
  final String id;

  /// The display name of the application (e.g. 'Netflix')
  final String name;

  /// The category of the app (e.g. 'Entertainment', 'Music')
  final String category;

  /// The image asset or internet URL for the logo
  final String iconAsset;

  /// List of ISO 3166-1 alpha-2 country codes that support this application.
  /// If [isGlobal] is true, this list can be empty.
  final List<String> supportedCountries;

  /// Whether the app is available globally across all regions.
  final bool isGlobal;

  const TVApp({
    required this.id,
    required this.name,
    required this.category,
    required this.iconAsset,
    required this.supportedCountries,
    required this.isGlobal,
  });

  /// Factory constructor to construct a [TVApp] from JSON/map data.
  /// This supports dynamic configuration from Firestore or Firebase Remote Config.
  factory TVApp.fromJson(Map<String, dynamic> json) {
    return TVApp(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      iconAsset: json['iconAsset'] as String,
      supportedCountries: List<String>.from(json['supportedCountries'] ?? []),
      isGlobal: json['isGlobal'] as bool? ?? false,
    );
  }

  /// Converts the [TVApp] instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'iconAsset': iconAsset,
      'supportedCountries': supportedCountries,
      'isGlobal': isGlobal,
    };
  }
}
