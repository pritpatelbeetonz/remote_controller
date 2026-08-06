import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';
import '../../core/google_cast_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:remote_controller/for_ads/ads/ads_variable.dart';
import 'package:remote_controller/for_ads/utils/firebase_analysis.dart';
import 'package:remote_controller/for_ads/utils/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'discovery_screen.dart';
import 'brand_selection_screen.dart';
import '../../RatingScreen.dart';
import '../../PremiumCreditView.dart';
import '../../contact_support_view.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;

class RemoteScreen extends StatefulWidget {
  final TvRemoteManager manager;

  const RemoteScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _nativeChannel = MethodChannel('nativeChannel');
  late final TabController _tabController;
  int _currentTabIndex = 0;

  final TextEditingController _castUrlController = TextEditingController(
    text:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );
  String _selectedCastType = 'v'; // 'v' = Video, 'p' = Photo, 'm' = Music
  bool _isCasting = false;
  String? _activeCastName;
  String? _iptvPlaylistUrl;
  List<Map<String, String>> _parsedIptvChannels = [];
  bool _isLoadingIptv = false;

  final TextEditingController _keyboardController = TextEditingController();
  bool _sendCharByChar = true;

  bool _useTrackpad = false; // Default to swipe trackpad
  double _dragAccumulatorX = 0.0;
  double _dragAccumulatorY = 0.0;
  static const double _swipeThreshold = 40.0;

  bool _showConsole = false;
  bool _isLoadingApps = false;
  List<Map<String, String>> _installedApps = [];
  bool _isNavigating = false;
  late final List<String> _activeTabs;
  bool _wasConnected = false;
  bool _isVoiceRecording = false;

  final GoogleCastManager _castManager = GoogleCastManager();
  CastSessionState _castState = CastSessionState.IDLE;
  List<CastDevice> _castDevices = [];
  StreamSubscription? _castStateSub;
  StreamSubscription? _castDevicesSub;
  bool _isScanningCast = false;

  @override
  void initState() {
    FirebaseAnalyticsService.logEvent(eventName: 'REMOTE_SCREEN');
    super.initState();
    _loadIptvSettings();
    _activeTabs = ['control'];
    if (_supportsAppLauncher) _activeTabs.add('apps');
    if (_supportsCasting) _activeTabs.add('cast');
    _activeTabs.add('settings');

    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      if (_activeTabs[_tabController.index] == 'apps') {
        _loadApps();
      }
    });

    _wasConnected = widget.manager.connectionState == TvConnectionState.connected;
    widget.manager.addListener(_onConnectionStateChange);

    _castState = _castManager.currentState;
    _castDevices = _castManager.discoveredDevices;
    _castStateSub = _castManager.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _castState = state;
          _isCasting = (state == CastSessionState.CASTING ||
              state == CastSessionState.BUFFERING ||
              state == CastSessionState.PAUSED);
        });
      }
    });
    _castDevicesSub = _castManager.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _castDevices = devices;
        });
      }
    });
    _castManager.getSessionState();
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onConnectionStateChange);
    _castStateSub?.cancel();
    _castDevicesSub?.cancel();
    _tabController.dispose();
    _castUrlController.dispose();
    _keyboardController.dispose();
    super.dispose();
  }

  void _onConnectionStateChange() {
    if (widget.manager.connectionState == TvConnectionState.connected) {
      _wasConnected = true;
    } else if (widget.manager.connectionState != TvConnectionState.connected &&
        _wasConnected &&
        mounted) {
      _showNotConnectedSnackBar();
    }
  }

  void _sendAction(TvKey key) {
    if (widget.manager.connectionState != TvConnectionState.connected) {
      _showNotConnectedSnackBar();
      return;
    }
    widget.manager.sendPress(key);
  }

  Future<void> _startVoiceSession() async {
    if (widget.manager.connectionState != TvConnectionState.connected) {
      _showNotConnectedSnackBar();
      return;
    }
    if (!_isAndroidTv) {
      _showToast("Voice search is only supported on Android TV devices");
      return;
    }

    // Check & request microphone permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showToast("Microphone permission is required for voice search", backgroundColor: AppTheme.error);
        return;
      }
    }

    try {
      final res = await const MethodChannel('com.waysol.android_tv_remote_package/method')
          .invokeMethod('voiceStart');
      if (res != null && res['success'] == true) {
        setState(() {
          _isVoiceRecording = true;
        });
        HapticFeedback.heavyImpact();
        _showToast("🎙️ Listening... Speak now", backgroundColor: AppTheme.success);
      }
    } on PlatformException catch (e) {
      String errorMsg = "Failed to start voice search";
      switch (e.code) {
        case 'VOICE_NOT_SUPPORTED':
          errorMsg = "Voice search is not supported by this TV device.";
          break;
        case 'PERMISSION_DENIED':
          errorMsg = "Microphone permission is required.";
          break;
        case 'TIMEOUT':
          errorMsg = "TV did not respond. Please try again.";
          break;
        case 'CONNECTION_LOST':
          errorMsg = "TV connection lost.";
          break;
        case 'AUDIO_RECORD_ERROR':
          errorMsg = "Microphone hardware error.";
          break;
      }
      _showToast(errorMsg, backgroundColor: AppTheme.error);
    } catch (e) {
      _showToast("Error starting voice: $e", backgroundColor: AppTheme.error);
    }
  }

  Future<void> _stopVoiceSession() async {
    if (!_isVoiceRecording) return;
    try {
      await const MethodChannel('com.waysol.android_tv_remote_package/method')
          .invokeMethod('voiceStop');
    } catch (e) {
      // Ignore
    } finally {
      setState(() {
        _isVoiceRecording = false;
      });
      HapticFeedback.mediumImpact();
      _showToast("Recording sent to TV", backgroundColor: AppTheme.primary);
    }
  }

  void _showToast(String msg, {Color? backgroundColor}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor ?? const Color(0xFF1E1E22),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showNotConnectedSnackBar() {
    _showToast(
      'Device not connected. Redirecting to search...',
      backgroundColor: AppTheme.error,
    );
    AdsVariable.onShowAds(
      context,
      onComplete: () {
        Get.offAll(() => DiscoveryScreen(manager: widget.manager, selectedBrand: 'All'));
      },
    );
  }

  // Load Apps
  Future<void> _loadApps() async {
    if (widget.manager.connectionState != TvConnectionState.connected) return;
    setState(() {
      _isLoadingApps = true;
    });
    try {
      final apps = await widget.manager.getInstalledApps();
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      widget.manager.addLocalLog('ERROR', 'UI', 'Failed to load apps: $e');
      setState(() {
        _isLoadingApps = false;
      });
    }
  }

  // Launch App
  Future<void> _launchApp(String id, String name) async {
    final eventAppName = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
    FirebaseAnalyticsService.logEvent(
      eventName: 'APP_LAUNCHED_$eventAppName',
    );
    final success = await widget.manager.launchApp(id);
    if (success) {
      _showToast(
        'Successfully launched $name',
        backgroundColor: AppTheme.success,
      );
    } else {
      _showToast('Failed to launch $name', backgroundColor: AppTheme.error);
    }
  }

  Future<void> rateUs(BuildContext context) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String packageName = packageInfo.packageName;
      if (Platform.isIOS) {
        final String url = 'https://apps.apple.com/app/id$iosAppId';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch App Store.';
        }
      } else {
        final String url = 'market://details?id=$packageName';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          final String webUrl =
              'https://play.google.com/store/apps/details?id=$packageName';
          if (await canLaunchUrl(Uri.parse(webUrl))) {
            await launchUrl(Uri.parse(webUrl),
                mode: LaunchMode.externalApplication);
          } else {
            throw 'Could not launch Play Store.';
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(msg: 'Error: $e', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
      }
    }
  }

  Future<void> shareApp(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;

      if (Platform.isIOS) {
        final url = 'https://apps.apple.com/app/id$iosAppId';
        await Share.share(url);
      } else {
        final url =
            'https://play.google.com/store/apps/details?id=$packageName';
        await Share.share(url);
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(msg: 'Error: $e', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
      }
    }
  }

  // Cast URL
  Future<void> _startCast(String url, String type, {String? name}) async {
    if (!mounted) return;

    final isGoogleCastConnected = (_castState == CastSessionState.CONNECTED ||
        _castState == CastSessionState.CASTING ||
        _castState == CastSessionState.BUFFERING ||
        _castState == CastSessionState.PAUSED);

    if (!isGoogleCastConnected) {
      _showToast('Please connect to a Google Cast device first.', backgroundColor: AppTheme.warning);
      _startCastDiscovery();
      return;
    }

    setState(() {
      _isCasting = true;
      _activeCastName = name ?? 'Web Stream';
    });

    String? mime;
    if (type == 'p') mime = 'image/jpeg';
    if (type == 'v') mime = 'video/mp4';
    if (type == 'm') mime = 'audio/mpeg';

    try {
      final success = await _castManager.castMedia(
        url: url,
        mimeType: mime,
        title: name ?? 'Cast Media',
        subtitle: 'Streaming to Chromecast',
      );
      if (!mounted) return;
      if (!success) {
        setState(() {
          _isCasting = false;
          _activeCastName = null;
        });
        _showToast('Failed to cast to Google Cast device', backgroundColor: AppTheme.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCasting = false;
        _activeCastName = null;
      });
      _showToast('Unsupported media format.', backgroundColor: AppTheme.error);
    }
  }

  // Stop Cast
  Future<void> _stopCast() async {
    final isGoogleCastConnected = (_castState == CastSessionState.CONNECTED ||
        _castState == CastSessionState.CASTING ||
        _castState == CastSessionState.BUFFERING ||
        _castState == CastSessionState.PAUSED);

    if (isGoogleCastConnected) {
      await _castManager.stop();
    } else {
      await widget.manager.stopCasting();
    }

    if (mounted) {
      setState(() {
        _isCasting = false;
        _activeCastName = null;
      });
    }
    _showToast('Casting session stopped', backgroundColor: AppTheme.info);
  }

  void _startCastDiscovery() async {
    if (_isScanningCast) return;
    setState(() {
      _isScanningCast = true;
    });
    _showToast('Scanning for Google Cast devices...', backgroundColor: AppTheme.info);
    await _castManager.startDiscovery();

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _castManager.stopDiscovery();
      setState(() {
        _isScanningCast = false;
      });

      final devices = _castManager.discoveredDevices;
      if (devices.isEmpty) {
        _showToast('No Cast devices found.', backgroundColor: AppTheme.error);
      } else {
        _showCastDevicePicker(devices);
      }
    });
  }

  void _showCastDevicePicker(List<CastDevice> devices) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Cast Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final dev = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.cast, color: Color(0xFF794DEB)),
                      title: Text(
                        dev.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        dev.modelName,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('Connecting to ${dev.name}...', backgroundColor: AppTheme.info);
                        _castManager.connect(dev.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick and cast local file from mobile
  Future<void> _pickAndCastFile(String type) async {
    try {
      if (Platform.isAndroid) {
        bool permissionGranted = false;
        if (type == 'p') {
          if (await Permission.photos.request().isGranted) {
            permissionGranted = true;
          }
        } else if (type == 'v') {
          if (await Permission.videos.request().isGranted) {
            permissionGranted = true;
          }
        }

        if (!mounted) return;
        if (!permissionGranted) {
          if (await Permission.storage.request().isGranted) {
            permissionGranted = true;
          }
        }

        if (!mounted) return;
        if (!permissionGranted) {
          _showToast(
            'Storage permissions are required to access local media files.',
            backgroundColor: AppTheme.error,
          );
          return;
        }
      }

      String? filePath;
      String? fileName;
      String typeLabel = '';

      if (type == 'p') {
        typeLabel = 'Image';
        widget.manager.addLocalLog(
          'INFO',
          'UI',
          'Opening ImagePicker for image...',
        );
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          filePath = image.path;
          fileName = image.name;
        }
      } else if (type == 'v') {
        typeLabel = 'Video';
        widget.manager.addLocalLog(
          'INFO',
          'UI',
          'Opening ImagePicker for video...',
        );
        final XFile? video = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
        );
        if (!mounted) return;
        if (video != null) {
          filePath = video.path;
          fileName = video.name;
        }
      } else {
        typeLabel = 'Audio';
        widget.manager.addLocalLog(
          'INFO',
          'UI',
          'Opening FilePicker for audio...',
        );
        final result = await FilePicker.pickFiles(type: FileType.audio);
        if (!mounted) return;
        if (result != null && result.files.single.path != null) {
          filePath = result.files.single.path;
          fileName = result.files.single.name;
        }
      }

      if (filePath != null && fileName != null) {
        _showToast(
          'Starting local server & casting $typeLabel: $fileName...',
          backgroundColor: AppTheme.info,
        );

        await _startCast(filePath, type, name: fileName);
      } else {
        widget.manager.addLocalLog(
          'INFO',
          'UI',
          'File picking cancelled by user.',
        );
      }
    } catch (e) {
      widget.manager.addLocalLog(
        'ERROR',
        'UI',
        'Failed to pick or cast local file: $e',
      );
      _showToast('Casting failed: $e', backgroundColor: AppTheme.error);
    }
  }

  // Keyboard Submission
  Future<void> _onKeyboardSubmit(String text) async {
    if (text.isEmpty) return;

    if (widget.manager.connectionState != TvConnectionState.connected) {
      _showToast("Connection to the TV has been lost.", backgroundColor: AppTheme.error);
      return;
    }

    final state = await widget.manager.activeAdapter?.getKeyboardState() ?? 'UNKNOWN';
    if (state == 'NO_TEXT_FIELD') {
      _showToast("Open a search box or text field on your TV first.", backgroundColor: AppTheme.warning);
    } else if (state == 'CONNECTION_LOST') {
      _showToast("Connection to the TV has been lost.", backgroundColor: AppTheme.error);
      return;
    } else if (state == 'NOT_SUPPORTED') {
      _showToast("Keyboard input is not supported on this device.", backgroundColor: AppTheme.error);
      return;
    }

    if (_sendCharByChar) {
      // Sent already, just clear
      _keyboardController.clear();
    } else {
      widget.manager.sendText(text);
      _keyboardController.clear();
    }
  }

  Future<void> _checkKeyboardAndShowModal() async {
    if (widget.manager.connectionState != TvConnectionState.connected) {
      _showToast("Connection to the TV has been lost.", backgroundColor: AppTheme.error);
      return;
    }

    // Query state from adapter
    final state = await widget.manager.activeAdapter?.getKeyboardState() ?? 'UNKNOWN';

    switch (state) {
      case 'CONNECTION_LOST':
        _showToast("Connection to the TV has been lost.", backgroundColor: AppTheme.error);
        break;
      case 'NOT_SUPPORTED':
        _showToast("Keyboard input is not supported on this device.", backgroundColor: AppTheme.error);
        break;
      case 'NO_TEXT_FIELD':
        _showToast("Open a search box or text field on your TV first.", backgroundColor: AppTheme.warning);
        _showKeyboardModal();
        break;
      case 'READY':
        _showKeyboardModal();
        break;
      default:
        // Default fallback if we cannot determine, try showing anyway
        _showKeyboardModal();
        break;
    }
  }

  bool get _isRoku => widget.manager.currentDevice?.brand == 'Roku';

  bool get _isSamsung => widget.manager.currentDevice?.brand == 'Samsung Tizen';

  bool get _isAndroidTv =>
      !_isRoku && !_isSamsung && !_isLg && !_isAppleTv && !_isAmazonFireTv;

  bool get _isLg => widget.manager.currentDevice?.brand == 'LG webOS';

  bool get _isAppleTv => widget.manager.currentDevice?.brand == 'Apple TV';

  bool get _isAmazonFireTv =>
      widget.manager.currentDevice?.brand == 'Amazon Fire TV';

  bool get _supportsAppLauncher =>
      _isRoku || _isSamsung || _isAndroidTv || _isAmazonFireTv;

  bool get _supportsCasting => true;

  bool get _supportsKeyboard => _isRoku || _isSamsung || _isAndroidTv || _isLg;

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final deviceName = manager.currentDevice?.name ?? 'Universal TV';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/home/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top App Bar/Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _showConsole = !_showConsole;
                          });
                        },
                        child: Text(
                          manager.connectionState == TvConnectionState.connected
                              ? deviceName
                              : 'TV is not connected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SF Pro Display',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    (_isScanningCast || _castState == CastSessionState.CONNECTING)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF794DEB)),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              _castState == CastSessionState.CONNECTED ||
                                      _castState == CastSessionState.CASTING ||
                                      _castState == CastSessionState.BUFFERING ||
                                      _castState == CastSessionState.PAUSED
                                  ? Icons.cast_connected
                                  : Icons.cast,
                              color: _castState == CastSessionState.CONNECTED ||
                                      _castState == CastSessionState.CASTING ||
                                      _castState == CastSessionState.BUFFERING ||
                                      _castState == CastSessionState.PAUSED
                                  ? const Color(0xFF794DEB)
                                  : Colors.white,
                            ),
                            onPressed: () {
                              if (_castState == CastSessionState.CONNECTED ||
                                  _castState == CastSessionState.CASTING ||
                                  _castState == CastSessionState.BUFFERING ||
                                  _castState == CastSessionState.PAUSED) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E22),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: AppTheme.border),
                                    ),
                                    title: const Text(
                                      'Disconnect Google Cast?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to stop casting to this device?',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          _castManager.disconnect();
                                        },
                                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                                        child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                _startCastDiscovery();
                              }
                            },
                          ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        if (manager.connectionState == TvConnectionState.connected) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E22),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: AppTheme.border),
                              ),
                              title: const Text(
                                'Disconnect TV?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SF Pro Display',
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to disconnect from "${manager.currentDevice?.name ?? 'this TV'}"?',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'SF Pro Display',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontFamily: 'SF Pro Display',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF794DEB),
                                  ),
                                  child: const Text(
                                    'Disconnect',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'SF Pro Display',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            manager.disconnect();
                            Get.offAll(
                              () => DiscoveryScreen(manager: manager, selectedBrand: 'All'),
                            );
                          }
                        } else {
                          Get.offAll(
                            () => DiscoveryScreen(manager: manager, selectedBrand: 'All'),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/home/connect.png',
                              width: 18,
                              height: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              manager.connectionState ==
                                      TvConnectionState.connected
                                  ? 'Connected'
                                  : 'Connect',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      // tab changes controlled by nav bar
                      children: _activeTabs.map((tab) {
                        if (tab == 'control') {
                          return _buildRemotePanel();
                        } else if (tab == 'apps') {
                          return _buildAppLauncher();
                        } else if (tab == 'cast') {
                          return _buildCastingHub();
                        } else {
                          return _buildSettingsPanel();
                        }
                      }).toList(),
                    ),
                    if (_showConsole)
                      Positioned.fill(
                        child: LogConsoleDrawer(
                          manager: manager,
                          onClose: () {
                            setState(() {
                              _showConsole = false;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
          child: Container(
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(color: Colors.transparent, width: 0),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1B1F23).withOpacity(0.8),
                  const Color(0xFF11151A).withOpacity(0.8),
                ],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (index) {
                AdsVariable.onShowAds(
                  context,
                  onComplete: () {
                    _tabController.animateTo(index);
                  },
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white30,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: _activeTabs.map((tab) {
                final isSelected = _activeTabs[_currentTabIndex] == tab;
                if (tab == 'control') {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected
                          ? 'assets/tab/remoite s.png'
                          : 'assets/tab/Remote.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Remote',
                  );
                } else if (tab == 'apps') {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected
                          ? 'assets/tab/Apps s.png'
                          : 'assets/tab/apps.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Apps',
                  );
                } else if (tab == 'cast') {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected
                          ? 'assets/tab/Cast s.png'
                          : 'assets/tab/Cast.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Cast',
                  );
                } else {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected
                          ? 'assets/tab/Settings s.png'
                          : 'assets/tab/Settings.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Settings',
                  );
                }
              }).toList(),
            ),
          ),
        ),
      ),
    ));
  }

  // --- TAB PANELS ---

  // Tab 1: Remote Control Panel
  Widget _buildRemotePanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // D-Pad or Trackpad Area
          Expanded(
            child: Center(
              child: _useTrackpad ? _buildSwipeTrackpad() : _buildTactileDpad(),
            ),
          ),
          const SizedBox(height: 16),

          // Circular Buttons Row (Mode Toggles, Power)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // MicroPhone Button
              GestureDetector(
                onTapDown: (_) => _startVoiceSession(),
                onTapUp: (_) => _stopVoiceSession(),
                onTapCancel: () => _stopVoiceSession(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _isVoiceRecording
                        ? AppTheme.glowShadow(AppTheme.success)
                        : null,
                  ),
                  child: Image.asset(
                    'assets/home/microhphone.png',
                    width: 56,
                    height: 56,
                    color: _isVoiceRecording ? AppTheme.success : null,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // D-pad & Trackpad toggle pill
              Container(
                width: 145.w,
                height: 65.h,
                padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 5.h),  // ← More padding
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),  // ← ADD THIS

                  //color: const Color(0xFF1E1E22),
                  //borderRadius: BorderRadius.circular(28),
                  //border: Border.all(color: AppTheme.border),
                  image: DecorationImage(image: AssetImage('assets/bgswitch.png'),fit: BoxFit.cover, ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,  // ← Changed from .min to .max
                  mainAxisAlignment: MainAxisAlignment.center,  // ← Add spacing
                  children: [
                    // Move Button (Classic D-Pad)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _useTrackpad = false;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        width: 56,
                        height: 52,
                        decoration: BoxDecoration(
                          color: !_useTrackpad
                              ? const Color(0xFF2D2D33)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/home/move.png',
                            width: 24,
                            height: 24,
                            color: !_useTrackpad
                                ? Colors.white
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    // Touch Pad Button (Trackpad)
                    // Touch Pad Button (Trackpad) - with premium gating
                    GestureDetector(
                      onTap: () {
                        if (AdsVariable.isPurchase) {
                          setState(() {
                            _useTrackpad = true;
                          });
                          HapticFeedback.lightImpact();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PremiumCreditView(
                                onboarding: false,
                                onDone: () {
                                  setState(() {
                                    _useTrackpad = true;
                                  });
                                  HapticFeedback.lightImpact();
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _useTrackpad
                              ? const Color(0xFF2D2D33)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/home/touch pad.png',
                            width: 24,
                            height: 24,
                            color: _useTrackpad ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Power Button
              GestureDetector(
                onTap: () => _sendAction(TvKey.power),
                child: Image.asset(
                  'assets/home/power button.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Grid Buttons
          Column(
            children: [
              // Row 1: Back, Home (spans 2), Keyboard
              Row(
                children: [
                  _buildGridButton(
                    assetPath: 'assets/home/arrow.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.back);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.back);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButtonExpanded(
                    assetPath: 'assets/home/home.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.home);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.home);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (_supportsKeyboard) ...[
                    const SizedBox(width: 12),
                    _buildGridButton(
                      assetPath: 'assets/home/keyboard.png',
                      onPressed: () {
                        if (AdsVariable.isPurchase) {
                          _checkKeyboardAndShowModal();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PremiumCreditView(
                                onboarding: false,
                                onDone: () {
                                  _checkKeyboardAndShowModal();
                                },  
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Reverse, Play/Pause, Fast Forward, Options/Star
              // Row 2: Reverse, Play/Pause, Fast Forward, Options/Star
              Row(
                children: [
                  _buildGridButton(
                    assetPath: 'assets/home/reverse.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.rewind);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.rewind);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/play.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.playPause);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.playPause);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/fast.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.fastForward);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.fastForward);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/Media_next.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.options);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.options);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Mute, Volume Down, Volume Up, Reload
              // Row 3: Mute, Volume Down, Volume Up, Reload
              Row(
                children: [
                  _buildGridButton(
                    assetPath: 'assets/home/no sound.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.mute);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.mute);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/sound.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.volumeDown);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.volumeDown);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/volume up.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.volumeUp);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.volumeUp);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/media_previous.png',
                    onPressed: () {
                      if (AdsVariable.isPurchase) {
                        _sendAction(TvKey.info);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PremiumCreditView(
                              onboarding: false,
                              onDone: () {
                                _sendAction(TvKey.info);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGridButton({
    required String assetPath,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      flex: 1,
      child: GestureDetector(
        onTap: onPressed,
        child: Image.asset(assetPath, height: 60, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildGridButtonExpanded({
    required String assetPath,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: onPressed,
        child: Image.asset(assetPath, height: 60, fit: BoxFit.contain),
      ),
    );
  }

  Map<String, dynamic> _getAppTheme(Map<String, String> app) {
    final name = app['name']?.toLowerCase() ?? '';
    final iconUrl = app['iconUrl'] ?? app['icon'] ?? '';

    Color cardColor = const Color(0xFF1E1E22);

    if (name.contains('youtube music')) {
      cardColor = const Color(0xFF0F0F0F);
    } else if (name.contains('youtube')) {
      cardColor = Colors.white;
    } else if (name.contains('netflix')) {
      cardColor = const Color(0xFF0F0F0F);
    } else if (name.contains('prime video') || name.contains('amazon video')) {
      cardColor = const Color(0xFF0F172A);
    } else if (name.contains('disney')) {
      cardColor = const Color(0xFF0A192F);
    } else if (name.contains('spotify')) {
      cardColor = const Color(0xFF0C0C0D);
    } else if (name.contains('plex')) {
      cardColor = const Color(0xFF1F1F23);
    } else if (name.contains('kodi')) {
      cardColor = const Color(0xFF111E2E);
    } else if (name.contains('hulu')) {
      cardColor = const Color(0xFF0B1A1E);
    } else if (name.contains('max')) {
      cardColor = const Color(0xFF0A0E29);
    } else if (name.contains('apple')) {
      cardColor = Colors.black;
    } else if (name.contains('twitch')) {
      cardColor = const Color(0xFF6441A5);
    } else if (name.contains('tubi')) {
      cardColor = const Color(0xFF330066);
    } else if (name.contains('sony')) {
      cardColor = const Color(0xFF00113A);
    } else if (name.contains('hotstar') || name.contains('jiohotstar')) {
      cardColor = const Color(0xFF0A1128);
    }

    return {'cardColor': cardColor, 'iconUrl': iconUrl};
  }

  // Tab 2: App Launcher Grid
// Tab 2: App Launcher Grid
  Widget _buildAppLauncher() {
    if (!_isRoku && !_isSamsung && !_isAndroidTv && !_isAmazonFireTv) {
      return _buildBrandNotSupportedOverlay('Application Launcher');
    }

    if (_isLoadingApps) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      );
    }

    if (_installedApps.isEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.apps_outage_rounded,
                    size: 40,
                    color: Colors.white30,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Apps Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please connect to a supported Smart TV to retrieve and launch installed apps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadApps,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reload Apps', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF794DEB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApps,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceElevated,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _installedApps.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
        ),
        itemBuilder: (context, index) {
          final app = _installedApps[index];
          final appTheme = _getAppTheme(app);
          final String resolvedIcon = appTheme['iconUrl'];

          return GestureDetector(
            onTap: () {
              if(AdsVariable.isPurchase){
                _launchApp(app['id']!, app['name']!);
              }
              else{
                Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                  _launchApp(app['id']!, app['name']!);
                })));
              }
            },
            child: Card(
              color: appTheme['cardColor'],
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: resolvedIcon.isNotEmpty
                    ? SizedBox.expand(
                        child: Image.asset(
                          resolvedIcon,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.tv, color: Colors.white30, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                app['name'] ?? '',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.tv, color: Colors.white30, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            app['name'] ?? '',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
  // Tab 3: Casting Hub
// Tab 3: Casting Hub
  Widget _buildCastingHub() {
    if (!_isRoku && !_isSamsung && !_isAndroidTv && !_isLg && !_isAppleTv) {
      return _buildBrandNotSupportedOverlay('Screen & Media Casting');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Apps',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'SF Pro Display',
                ),
              ),
              if (_isCasting)
                GestureDetector(
                  onTap: _stopCast,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.stop_circle_rounded, color: AppTheme.error, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'STOP CAST',
                          style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Grid view of casting items
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildCastGridItem(
                iconPath: 'assets/casting/photos.png',
                label: 'Photo',
                onTap: () {
                  if(AdsVariable.isPurchase){
                    _pickAndCastFile('p');
                  }
                  else{
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                      _pickAndCastFile('p');
                    })));
                  }
                },
              ),
              _buildCastGridItem(
                iconPath: 'assets/casting/video.png',
                label: 'Video',
                onTap: () {
                  if(AdsVariable.isPurchase){
                    _pickAndCastFile('v');
                  }
                  else{
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                      _pickAndCastFile('v');
                    })));
                  }
                },
              ),
              _buildCastGridItem(
                iconPath: 'assets/casting/iptv.png',
                label: 'IPTV',
                onTap: () {
                  if(AdsVariable.isPurchase){
                    _showIptvModal();
                  }
                  else{
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                      _showIptvModal();
                    })));
                  }
                },
              ),
              if (_isSamsung || _isLg)
                _buildCastGridItem(
                  iconPath: 'assets/casting/web browser.png',
                  label: 'Web Browser',
                  onTap: () {
                    if(AdsVariable.isPurchase){
                      _showWebBrowserModal();
                    }
                    else{
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                        _showWebBrowserModal();
                      })));
                    }
                  },
                ),
              if (!_isAppleTv)
                _buildCastGridItem(
                  iconPath: 'assets/casting/screen mirroring.png',
                  label: 'Screen Mirroring',
                  onTap: () {
                    if(AdsVariable.isPurchase){
                      _showMirroringModal();
                    }
                    else{
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PremiumCreditView(onboarding: false, onDone: (){
                        _showMirroringModal();
                      })));
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildCastGridItem({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, width: 48, height: 48),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<Map<String, String>> _defaultIptvChannels = [
    {
      'name': 'Al Jazeera News',
      'logo':
          'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Al_Jazeera_English_logo.svg/320px-Al_Jazeera_English_logo.svg.png',
      'url': 'https://live-amg-el.akamaized.net/playlist.m3u8',
      'category': 'News',
    },
    {
      'name': 'NASA Public TV',
      'logo':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/NASA_logo.svg/200px-NASA_logo.svg.png',
      'url':
          'https://ntv1.akamaized.net/hls/live/2014027/NASA-NTV1-HLS/master.m3u8',
      'category': 'Science',
    },
    {
      'name': 'DW English News',
      'logo':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Deutsche_Welle_logo.svg/200px-Deutsche_Welle_logo.svg.png',
      'url':
          'https://dwamdstream102.akamaized.net/hls/live/2014162/dwamdstream102/master.m3u8',
      'category': 'News',
    },
    {
      'name': 'Red Bull Live TV',
      'logo':
          'https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/Red_Bull_TV_logo.svg/320px-Red_Bull_TV_logo.svg.png',
      'url':
          'https://rbmn-live.akamaized.net/hls/live/2002830/sports/master.m3u8',
      'category': 'Sports',
    },
  ];

  Future<void> _loadIptvSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _iptvPlaylistUrl = prefs.getString('iptv_playlist_url');
    });
    if (_iptvPlaylistUrl != null && _iptvPlaylistUrl!.isNotEmpty) {
      _fetchAndParseIptv(_iptvPlaylistUrl!);
    }
  }

  Future<void> _saveIptvUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iptv_playlist_url', url);
    if (!mounted) return;
    setState(() {
      _iptvPlaylistUrl = url;
    });
    _fetchAndParseIptv(url);
  }

  Future<void> _fetchAndParseIptv(String url) async {
    if (!mounted) return;
    setState(() {
      _isLoadingIptv = true;
    });
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final parsed = _parseM3u(res.body);
        setState(() {
          _parsedIptvChannels = parsed;
        });
      } else {
        Get.snackbar(
          'IPTV Error',
          'Failed to load playlist. Status code: ${res.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('IPTV Error', 'Could not parse playlist: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingIptv = false;
      });
    }
  }

  List<Map<String, String>> _parseM3u(String content) {
    final List<Map<String, String>> channels = [];
    final lines = content.split('\n');
    String? currentLogo;
    String? currentGroup;
    String? currentName;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);

        final groupMatch = RegExp(r'group-title="([^"]+)"').firstMatch(line);
        currentGroup = groupMatch?.group(1);

        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1) {
          currentName = line.substring(commaIndex + 1).trim();
        }
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (currentName != null) {
          channels.add({
            'name': currentName,
            'url': line,
            'logo': currentLogo ?? '',
            'category': currentGroup ?? 'General',
          });
        }
        currentLogo = null;
        currentGroup = null;
        currentName = null;
      }
    }
    return channels;
  }

  void _showIptvModal() {
    final iptvUrlController = TextEditingController(text: _iptvPlaylistUrl);
    bool showUrlInput = _iptvPlaylistUrl == null || _iptvPlaylistUrl!.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<Map<String, String>> channels =
              _parsedIptvChannels.isNotEmpty
              ? _parsedIptvChannels
              : _defaultIptvChannels;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF17171A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.border),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/casting/iptv.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'IPTV Player',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            showUrlInput
                                ? Icons.playlist_play_rounded
                                : Icons.settings_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setModalState(() {
                              showUrlInput = !showUrlInput;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                if (showUrlInput) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: iptvUrlController,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter M3U playlist URL...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: const Color(0xFF222226),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final url = iptvUrlController.text.trim();
                          if (url.isNotEmpty) {
                            await _saveIptvUrl(url);
                            setModalState(() {
                              showUrlInput = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF794DEB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('LOAD'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isLoadingIptv)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF794DEB),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  (channel['logo'] != null &&
                                      channel['logo']!.isNotEmpty &&
                                      (channel['logo']!.startsWith('http://') ||
                                          channel['logo']!.startsWith(
                                            'https://',
                                          )))
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        channel['logo']!,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.tv_rounded,
                                                  color: Colors.white30,
                                                ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.tv_rounded,
                                      color: Colors.white30,
                                    ),
                            ),
                            title: Text(
                              channel['name'] ?? 'Unknown Channel',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                channel['category'] ?? 'General',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.cast_connected_rounded,
                              color: Color(0xFF794DEB),
                              size: 20,
                            ),
                            onTap: () {
                              final streamUrl = channel['url'];
                              if (streamUrl != null && streamUrl.isNotEmpty) {
                                _startCast(
                                  streamUrl,
                                  'v',
                                  name: channel['name'],
                                );
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWebBrowserModal() {
    final bool supportsBrowserLaunch = _isSamsung || _isLg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF17171A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/casting/web browser.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Web Browser Cast',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _castUrlController,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g. http://example.com)...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF222226),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (supportsBrowserLaunch) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final url = _castUrlController.text.trim();
                        if (url.isNotEmpty) {
                          _startCast(url, 'w', name: 'Web Page');
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF794DEB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'OPEN ON TV',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final url = _castUrlController.text.trim();
                        if (url.isNotEmpty) {
                          _startCast(url, 'v', name: url.split('/').last);
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF794DEB),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'CAST VIDEO',
                        style: TextStyle(
                          color: Color(0xFF794DEB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  final url = _castUrlController.text.trim();
                  if (url.isNotEmpty) {
                    _startCast(url, 'v', name: url.split('/').last);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF794DEB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'CAST VIDEO STREAM',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '* TV browser page redirection is only supported on Samsung and LG TVs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMirroringModal() {
    final bool isAndroid = Platform.isAndroid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF17171A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/casting/screen mirroring.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Screen Mirroring',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'How to mirror your device screen to the TV:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isAndroid
                  ? '1. Ensure both your phone and TV are connected to the same Wi-Fi network.\n'
                        '2. Tap "START MIRRORING" below to open the Android Cast panel.\n'
                        '3. Select your Smart TV from the discovered device list to begin cloning your screen.'
                  : '1. Ensure both your phone and TV are connected to the same Wi-Fi network.\n'
                        '2. Swipe down from the top-right corner of your screen to open the iOS Control Center.\n'
                        '3. Tap "Screen Mirroring" (dual overlapping rectangles) and select your TV.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (isAndroid) {
                  try {
                    await _nativeChannel.invokeMethod('launchCastSettings');
                  } catch (e) {
                    _showToast(
                      'Could not open Cast settings: $e',
                      backgroundColor: AppTheme.error,
                    );
                  }
                } else {
                  _showToast(
                    'Swipe down top-right to open Control Center & choose Screen Mirroring.',
                    backgroundColor: AppTheme.info,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF794DEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                isAndroid ? 'START MIRRORING' : 'GOT IT',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 4: Keyboard Input
  Widget _buildKeyboardInput() {
    if (!_isRoku && !_isSamsung && !_isAndroidTv && !_isLg) {
      return _buildBrandNotSupportedOverlay('Keyboard Input');
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'REMOTE KEYBOARD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type text here to stream it directly to input fields and search screens on your TV.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _keyboardController,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            onChanged: (text) {
              if (_sendCharByChar && text.isNotEmpty) {
                widget.manager.sendText(text.substring(text.length - 1));
              }
            },
            onSubmitted: _onKeyboardSubmit,
            decoration: InputDecoration(
              hintText: 'Tap here to begin typing...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white30),
                onPressed: () => _keyboardController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Modes switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Send character-by-character',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              Switch(
                value: _sendCharByChar,
                onChanged: (val) {
                  setState(() {
                    _sendCharByChar = val;
                  });
                },
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Action Keys Panel
          const Text(
            'KEYBOARD ACTIONS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.white30,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeyboardActionBtn(
                label: 'BACKSPACE',
                icon: Icons.backspace,
                onPressed: () => _sendAction(
                  TvKey.back,
                ), // using back or we can expose backspace key press
              ),
              _buildKeyboardActionBtn(
                label: 'ENTER',
                icon: Icons.subdirectory_arrow_left,
                onPressed: () {
                  if (!_sendCharByChar) {
                    _onKeyboardSubmit(_keyboardController.text);
                  } else {
                    _sendAction(TvKey.select);
                  }
                },
              ),
              _buildKeyboardActionBtn(
                label: 'SPACEBAR',
                icon: Icons.space_bar,
                onPressed: () {
                  if (_sendCharByChar) {
                    widget.manager.sendText(' ');
                  } else {
                    _keyboardController.text += ' ';
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Card(
        color: AppTheme.surfaceElevated,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tab 4: Settings Panel
  Widget _buildSettingsPanel() {
    return Container(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Settings',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: 20),

            // Banner: Unlock the Full Experience
            GestureDetector(
              onTap: () {
                Get.to(() => PremiumCreditView(onboarding: false, onDone: () {}));
              },
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: const DecorationImage(
                    image: AssetImage('assets/settting/bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Image.asset('assets/settting/ic.png', width: 32, height: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Unlock the Full Experience',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Access all remote features with faster, smoother & unlimited connectivity.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontFamily: 'SF Pro Display',
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // General Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1116),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'General',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNewSettingsItem(
                    iconPath: 'assets/settting/Contact us.png',
                    title: 'Contact Us',
                    onTap: () {
                      Get.to(() => const ContactSupportScreen());
                    },
                  ),
                  _buildNewSettingsItem(
                    iconPath: 'assets/settting/privacy policy.png',
                    title: 'Privacy Policy',
                    onTap: () {
                      // Action for Privacy Policy
                    },
                  ),
                  _buildNewSettingsItem(
                    iconPath: 'assets/settting/share app.png',
                    title: 'Share App',
                    onTap: () {
                      shareApp(context);
                    },
                  ),
                  _buildNewSettingsItem(
                    iconPath: 'assets/settting/Rate Us.png',
                    title: 'Rate Us',
                    onTap: () {
                      rateUs(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewSettingsItem({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 14.0),
        child: Row(
          children: [
            Image.asset(iconPath, width: 24, height: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showKeyboardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF17171A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'TV Keyboard',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Stream typing directly to your TV',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _keyboardController,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'SF Pro Display',
                        ),
                        onChanged: (text) {
                          if (_sendCharByChar) {
                            widget.manager.sendText(text);
                          }
                        },
                        onSubmitted: (text) {
                          _onKeyboardSubmit(text);
                          Navigator.pop(context);
                        },
                        decoration: InputDecoration(
                          hintText: 'Type here to begin...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white30,
                            ),
                            onPressed: () {
                              _keyboardController.clear();
                              if (_sendCharByChar) {
                                widget.manager.sendText('');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Send character-by-character',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                        Switch(
                          value: _sendCharByChar,
                          onChanged: (val) {
                            setModalState(() {
                              _sendCharByChar = val;
                            });
                            setState(() {
                              _sendCharByChar = val;
                            });
                          },
                          activeColor: const Color(0xFF794DEB),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModalKeyboardActionBtn(
                          label: 'BACKSPACE',
                          icon: Icons.backspace_rounded,
                          onPressed: () => _sendAction(TvKey.back),
                        ),
                        const SizedBox(width: 8),
                        _buildModalKeyboardActionBtn(
                          label: 'ENTER',
                          icon: Icons.keyboard_return_rounded,
                          onPressed: () {
                            if (!_sendCharByChar) {
                              _onKeyboardSubmit(_keyboardController.text);
                            } else {
                              _sendAction(TvKey.select);
                            }
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildModalKeyboardActionBtn(
                          label: 'SPACE',
                          icon: Icons.space_bar_rounded,
                          onPressed: () {
                            if (_sendCharByChar) {
                              widget.manager.sendText(' ');
                            } else {
                              _keyboardController.text += ' ';
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalKeyboardActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF794DEB), size: 20),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- BRAND NOT SUPPORTED OVERLAY ---
  Widget _buildBrandNotSupportedOverlay(String featureName) {
    final brand = widget.manager.currentDevice?.brand ?? 'This device';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: AppTheme.warning, size: 48),
            const SizedBox(height: 16),
            Text(
              '$featureName Limited',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'The $featureName feature is currently optimized and supported on Roku TV devices. $brand does not support this control mechanism natively over ECP.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER COMPONENT BUILDERS ---

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildTactileDpad() {
    return Container(
      width: 240,
      height: 240,
      decoration: inset.BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
        ),
        boxShadow: [
          // Top semicircle white inner highlight
          inset.BoxShadow(
            inset: true,
            color: Colors.white.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
          // Bottom semicircle black inner shadow
          inset.BoxShadow(
            inset: true,
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // Faint overall softening
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.5),
                      radius: 1.0,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                ),
              ),
            ),

            // Tight dark crescent at bottom edge
            // Positioned.fill(
            //   child: IgnorePointer(
            //     child: DecoratedBox(
            //       decoration: BoxDecoration(
            //         gradient: LinearGradient(
            //           begin: Alignment.bottomCenter,
            //           end: Alignment.topCenter,
            //           colors: [
            //             Colors.black.withOpacity(0.44),
            //             Colors.black.withOpacity(0.0),
            //           ],
            //           stops: const [0.0, 0.07],
            //         ),
            //       ),
            //     ),
            //   ),
            // ),

            // Center Select Button (OK) — SIZE REDUCED
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  _sendAction(TvKey.select);
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  width: 110, // was 150
                  height: 110, // was 150
                  decoration: inset.BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                    ),
                    border: Border.all(color: Colors.black, width: 3.5),
                    boxShadow: [
                      // Top semicircle white inner highlight
                      inset.BoxShadow(
                        inset: true,
                        color: Colors.white.withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 8),
                      ),
                      // Bottom semicircle black inner shadow
                      inset.BoxShadow(
                        inset: true,
                        color: Colors.black.withOpacity(0.50),
                        blurRadius: 12,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        // slightly smaller to match smaller button
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // D-Pad Up
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0), // was 28.0
                child: _buildDpadDirection(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onPressed: () => _sendAction(TvKey.up),
                ),
              ),
            ),

            // D-Pad Down
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0), // was 28.0
                child: _buildDpadDirection(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: () => _sendAction(TvKey.down),
                ),
              ),
            ),

            // D-Pad Left
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0), // was 28.0
                child: _buildDpadDirection(
                  icon: Icons.keyboard_arrow_left_rounded,
                  onPressed: () => _sendAction(TvKey.left),
                ),
              ),
            ),

            // D-Pad Right
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20.0), // was 28.0
                child: _buildDpadDirection(
                  icon: Icons.keyboard_arrow_right_rounded,
                  onPressed: () => _sendAction(TvKey.right),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDpadDirection({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        // was 54
        height: 40,
        // was 54
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 32, // was 40
        ),
      ),
    );
  }

  void _showDisconnectConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Disconnect Device?'),
        content: const Text(
          'Would you like to search for other devices of the same brand or switch TV brands entirely?',
        ),
        actions: [
          TextButton(
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
            child: const Text('SWITCH BRAND'),
            onPressed: () {
              Navigator.pop(context);
              AdsVariable.onShowAds(
                context,
                onComplete: () {
                  widget.manager.disconnect();
                  Get.offAll(() => DiscoveryScreen(manager: widget.manager, selectedBrand: 'All'));
                },
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('DISCONNECT'),
            onPressed: () {
              Navigator.pop(context);
              AdsVariable.onShowAds(
                context,
                onComplete: () {
                  widget.manager.disconnect();
                  Get.offAll(() => DiscoveryScreen(manager: widget.manager, selectedBrand: 'All'));
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocalCastOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeTrackpad() {
    return GestureDetector(
      onPanStart: (details) {
        _dragAccumulatorX = 0.0;
        _dragAccumulatorY = 0.0;
      },
      onPanUpdate: (details) {
        _dragAccumulatorX += details.delta.dx;
        _dragAccumulatorY += details.delta.dy;

        if (_dragAccumulatorX.abs() > _swipeThreshold) {
          if (_dragAccumulatorX > 0) {
            _sendAction(TvKey.right);
          } else {
            _sendAction(TvKey.left);
          }
          _dragAccumulatorX = 0.0;
          _dragAccumulatorY = 0.0;
          HapticFeedback.lightImpact();
        } else if (_dragAccumulatorY.abs() > _swipeThreshold) {
          if (_dragAccumulatorY > 0) {
            _sendAction(TvKey.down);
          } else {
            _sendAction(TvKey.up);
          }
          _dragAccumulatorX = 0.0;
          _dragAccumulatorY = 0.0;
          HapticFeedback.lightImpact();
        }
      },
      onPanEnd: (details) {
        _dragAccumulatorX = 0.0;
        _dragAccumulatorY = 0.0;
      },
      onTap: () {
        _sendAction(TvKey.select);
        HapticFeedback.mediumImpact();
      },
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: CustomPaint(
                size: const Size(200, 200),
                painter: CrosshairPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;

    // Draw horizontal dotted line
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Draw vertical dotted line
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
