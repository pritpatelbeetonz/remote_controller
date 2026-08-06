import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Handles downloading and caching application logos on-demand to save bandwidth.
class AppLogoCacheManager {
  static final AppLogoCacheManager _instance = AppLogoCacheManager._internal();

  factory AppLogoCacheManager() => _instance;

  AppLogoCacheManager._internal();

  /// Gets the local cached file for the given [appId] package name if it exists.
  /// Returns null if not cached yet.
  Future<File?> getCachedLogoFile(String appId) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/logos/$appId.png');
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('❌ [AppLogoCacheManager] Error checking cached file: $e');
    }
    return null;
  }

  /// Downloads the logo from [url] and caches it locally as `[appId].png`.
  /// Returns the saved [File] or null if download failed.
  Future<File?> downloadAndCacheLogo(String appId, String url) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final logoDir = Directory('${cacheDir.path}/logos');
      if (!await logoDir.exists()) {
        await logoDir.create(recursive: true);
      }

      final file = File('${logoDir.path}/$appId.png');

      print('🌐 [AppLogoCacheManager] Downloading logo for $appId from: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('💾 [AppLogoCacheManager] Successfully cached logo for $appId to local storage');
        return file;
      } else {
        print('❌ [AppLogoCacheManager] Failed to download logo. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AppLogoCacheManager] Error caching logo for $appId: $e');
    }
    return null;
  }
}
