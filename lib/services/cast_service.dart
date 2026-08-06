class CastService {
  static final CastService _instance = CastService._internal();

  factory CastService() {
    return _instance;
  }

  CastService._internal();

  void initialize() {
    // The current app uses the widget-based ChromeCast flow from
    // `flutter_cast_video`. Keep this method as a safe no-op so existing
    // callers do not break if they still invoke initialization.
  }

  Future<void> startDiscovery() async {
    // Discovery is handled by the package's platform widget/controller.
  }

  Future<void> castMedia(String url, String title) async {
    // Media casting is triggered from `CastMediaButton`, which owns the
    // platform controller instance required by the package.
  }
}
