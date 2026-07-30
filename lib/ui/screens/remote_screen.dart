import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'discovery_screen.dart';
import 'brand_selection_screen.dart';
import '../../RatingScreen.dart';
import '../../PremiumCreditView.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;

class RemoteScreen extends StatefulWidget {
  final TvRemoteManager manager;

  const RemoteScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTabIndex = 0;

  final TextEditingController _castUrlController = TextEditingController(
    text: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );
  String _selectedCastType = 'v'; // 'v' = Video, 'p' = Photo, 'm' = Music
  bool _isCasting = false;
  String? _activeCastName;

  final TextEditingController _keyboardController = TextEditingController();
  bool _sendCharByChar = true;

  bool _useTrackpad = true; // Default to swipe trackpad
  double _dragAccumulatorX = 0.0;
  double _dragAccumulatorY = 0.0;
  static const double _swipeThreshold = 40.0;

  bool _showConsole = false;
  bool _isLoadingApps = false;
  List<Map<String, String>> _installedApps = [];
  bool _isNavigating = false;

  late final List<String> _activeTabs;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _castUrlController.dispose();
    _keyboardController.dispose();
    super.dispose();
  }

  void _sendAction(TvKey key) {
    if (widget.manager.connectionState != TvConnectionState.connected) {
      _showNotConnectedSnackBar();
      return;
    }
    widget.manager.sendPress(key);
  }

  void _showNotConnectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to TV. Redirecting to brand selection...'),
        backgroundColor: AppTheme.error,
        duration: Duration(seconds: 2),
      ),
    );
    Get.offAll(() => BrandSelectionScreen(manager: widget.manager));
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
    final success = await widget.manager.launchApp(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully launched $name'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch $name'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // Cast URL
  Future<void> _startCast(String url, String type, {String? name}) async {
    setState(() {
      _isCasting = true;
      _activeCastName = name ?? 'Web Stream';
    });
    
    final success = await widget.manager.castMedia(
      url: url,
      type: type,
      name: _activeCastName,
    );

    if (!success) {
      setState(() {
        _isCasting = false;
        _activeCastName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start casting session'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // Stop Cast
  Future<void> _stopCast() async {
    await widget.manager.stopCasting();
    setState(() {
      _isCasting = false;
      _activeCastName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Casting session stopped'),
        backgroundColor: AppTheme.info,
      ),
    );
  }

  // Pick and cast local file from mobile
  Future<void> _pickAndCastFile(String type) async {
    try {
      FileType fileType;
      String typeLabel;
      if (type == 'p') {
        fileType = FileType.image;
        typeLabel = 'Image';
      } else if (type == 'v') {
        fileType = FileType.video;
        typeLabel = 'Video';
      } else {
        fileType = FileType.audio;
        typeLabel = 'Audio';
      }

      widget.manager.addLocalLog('INFO', 'UI', 'Opening file picker for local $typeLabel...');
      final result = await FilePicker.pickFiles(type: fileType);

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting local server & casting $typeLabel: $fileName...'),
            backgroundColor: AppTheme.info,
          ),
        );

        await _startCast(filePath, type, name: fileName);
      } else {
        widget.manager.addLocalLog('INFO', 'UI', 'File picking cancelled by user.');
      }
    } catch (e) {
      widget.manager.addLocalLog('ERROR', 'UI', 'Failed to pick or cast local file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Casting failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // Keyboard Submission
  void _onKeyboardSubmit(String text) {
    if (text.isEmpty) return;
    if (_sendCharByChar) {
      // Sent already, just clear
      _keyboardController.clear();
    } else {
      widget.manager.sendText(text);
      _keyboardController.clear();
    }
  }

  bool get _isRoku => widget.manager.currentDevice?.brand == 'Roku';
  bool get _isSamsung => widget.manager.currentDevice?.brand == 'Samsung Tizen';
  bool get _isAndroidTv => !_isRoku && !_isSamsung && !_isLg && !_isAppleTv && !_isAmazonFireTv;
  bool get _isLg => widget.manager.currentDevice?.brand == 'LG webOS';
  bool get _isAppleTv => widget.manager.currentDevice?.brand == 'Apple TV';
  bool get _isAmazonFireTv => widget.manager.currentDevice?.brand == 'Amazon Fire TV';

  bool get _supportsAppLauncher => _isRoku || _isSamsung || _isAndroidTv || _isAmazonFireTv;
  bool get _supportsCasting => _isRoku || _isSamsung || _isAndroidTv || _isLg || _isAppleTv;
  bool get _supportsKeyboard => _isRoku || _isSamsung || _isAndroidTv || _isLg;

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final deviceName = manager.currentDevice?.name ?? 'Universal TV';

    return Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    GestureDetector(
                      onTap: () {
                        Get.offAll(() => BrandSelectionScreen(manager: manager));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              manager.connectionState == TvConnectionState.connected
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
                      physics: const NeverScrollableScrollPhysics(), // tab changes controlled by nav bar
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
              border: const Border(top: BorderSide(color: Colors.transparent, width: 0)),
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
                _tabController.animateTo(index);
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
                      isSelected ? 'assets/tab/remoite s.png' : 'assets/tab/Remote.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Remote',
                  );
                } else if (tab == 'apps') {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected ? 'assets/tab/Apps s.png' : 'assets/tab/apps.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Apps',
                  );
                } else if (tab == 'cast') {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected ? 'assets/tab/Cast s.png' : 'assets/tab/Cast.png',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Cast',
                  );
                } else {
                  return BottomNavigationBarItem(
                    icon: Image.asset(
                      isSelected ? 'assets/tab/Settings s.png' : 'assets/tab/Settings.png',
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
    );
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

          // Circular Buttons Row (Microphone, Mode Toggles, Power)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Microphone
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                },
                child: Image.asset(
                  'assets/home/microhphone.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              // D-pad & Trackpad toggle pill
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                          color: !_useTrackpad ? const Color(0xFF2D2D33) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/home/move.png',
                            width: 24,
                            height: 24,
                            color: !_useTrackpad ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    // Touch Pad Button (Trackpad)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _useTrackpad = true;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        width: 56,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _useTrackpad ? const Color(0xFF2D2D33) : Colors.transparent,
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
                    onPressed: () => _sendAction(TvKey.back),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButtonExpanded(
                    assetPath: 'assets/home/home.png',
                    onPressed: () => _sendAction(TvKey.home),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/keyboard.png',
                    onPressed: _showKeyboardModal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Reverse, Play/Pause, Fast Forward, Options/Star
              Row(
                children: [
                  _buildGridButton(
                    assetPath: 'assets/home/reverse.png',
                    onPressed: () => _sendAction(TvKey.left),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/play.png',
                    onPressed: () => _sendAction(TvKey.playPause),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/fast.png',
                    onPressed: () => _sendAction(TvKey.right),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/star.png',
                    onPressed: () => _sendAction(TvKey.select),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Mute, Volume Down, Volume Up, Reload
              Row(
                children: [
                  _buildGridButton(
                    assetPath: 'assets/home/no sound.png',
                    onPressed: () => _sendAction(TvKey.mute),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/sound.png',
                    onPressed: () => _sendAction(TvKey.volumeDown),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/volume up.png',
                    onPressed: () => _sendAction(TvKey.volumeUp),
                  ),
                  const SizedBox(width: 12),
                  _buildGridButton(
                    assetPath: 'assets/home/restart.png',
                    onPressed: () => _sendAction(TvKey.home),
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
        child: Image.asset(
          assetPath,
          height: 60,
          fit: BoxFit.contain,
        ),
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
        child: Image.asset(
          assetPath,
          height: 60,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apps_outage, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No Apps Found',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadApps,
              icon: const Icon(Icons.refresh, color: AppTheme.primary),
              label: const Text('Reload Apps', style: TextStyle(color: AppTheme.primary)),
            )
          ],
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
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final app = _installedApps[index];
          return GestureDetector(
            onTap: () => _launchApp(app['id']!, app['name']!),
            child: Card(
              color: AppTheme.surfaceElevated,
              margin: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          app['iconUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.white12,
                            child: const Icon(Icons.tv, color: Colors.white30, size: 32),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.white12,
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      app['name']!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
          // Active session card
          if (_isCasting) ...[
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1A382A).withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.success.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_filled_rounded, color: AppTheme.success, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENTLY CASTING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.success,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeCastName ?? 'Web Media Stream',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _stopCast,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('STOP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Casting URL input card
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/tab/Cast.png',
                      width: 20,
                      height: 20,
                      color: const Color(0xFF794DEB),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'CAST WEB LINK',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _castUrlController,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter media URL here...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF16161A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF794DEB), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cast Type selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCastType,
                      dropdownColor: const Color(0xFF1B1B1F),
                      style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'SF Pro Display'),
                      decoration: const InputDecoration(
                        labelText: 'Select Media Type',
                        labelStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'v', child: Text('🎬  Video (MP4, MOV)')),
                        DropdownMenuItem(value: 'p', child: Text('🖼️  Photo (JPG, PNG)')),
                        DropdownMenuItem(value: 'm', child: Text('🎵  Music (MP3, WAV)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCastType = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    final url = _castUrlController.text.trim();
                    if (url.isEmpty) return;
                    _startCast(url, _selectedCastType, name: url.split('/').last);
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF794DEB),
                          Color(0xFF512CB8),
                        ],
                      ),
                    ),
                    child: const Text(
                      'Cast Media Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Casting Local files card
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_shared_rounded, color: Color(0xFF794DEB), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'LOCAL FILE STREAMING',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Stream local media files directly from your mobile device to the TV screen.',
                  style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildLocalCastOption(
                        icon: Icons.image_rounded,
                        label: 'Image',
                        color: const Color(0xFF794DEB),
                        onPressed: () => _pickAndCastFile('p'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLocalCastOption(
                        icon: Icons.movie_creation_rounded,
                        label: 'Video',
                        color: const Color(0xFF794DEB),
                        onPressed: () => _pickAndCastFile('v'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLocalCastOption(
                        icon: Icons.audiotrack_rounded,
                        label: 'Audio',
                        color: const Color(0xFF794DEB),
                        onPressed: () => _pickAndCastFile('m'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick samples section
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'QUICK WEB SAMPLE STREAMS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white30, letterSpacing: 1.0),
            ),
          ),
          const SizedBox(height: 10),
          _buildSampleMediaTile(
            title: 'Sintel Open Movie Video',
            subtitle: 'MP4 Video Stream (1080p)',
            url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
            type: 'v',
          ),
          _buildSampleMediaTile(
            title: 'Beautiful Abstract Wallpaper',
            subtitle: 'Unsplash JPEG Image',
            url: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=800',
            type: 'p',
          ),
          _buildSampleMediaTile(
            title: 'Ambient Music Track',
            subtitle: 'SoundHelix Audio Stream',
            url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            type: 'm',
          ),
        ],
      ),
    );
  }

  Widget _buildSampleMediaTile({
    required String title,
    required String subtitle,
    required String url,
    required String type,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF794DEB).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            type == 'v'
                ? Icons.movie_creation_rounded
                : type == 'p'
                    ? Icons.image_rounded
                    : Icons.audiotrack_rounded,
            color: const Color(0xFF794DEB),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
        trailing: const Icon(Icons.cast_connected_rounded, color: Color(0xFF794DEB), size: 20),
        onTap: () {
          _castUrlController.text = url;
          setState(() {
            _selectedCastType = type;
          });
          _startCast(url, type, name: title);
        },
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
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 14),
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
              const Text('Send character-by-character', style: TextStyle(fontSize: 12, color: Colors.white54)),
              Switch(
                value: _sendCharByChar,
                onChanged: (val) {
                  setState(() {
                    _sendCharByChar = val;
                  });
                },
                activeColor: AppTheme.primary,
              )
            ],
          ),
          const SizedBox(height: 20),

          // Custom Action Keys Panel
          const Text(
            'KEYBOARD ACTIONS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white30, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeyboardActionBtn(
                label: 'BACKSPACE',
                icon: Icons.backspace,
                onPressed: () => _sendAction(TvKey.back), // using back or we can expose backspace key press
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
          )
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
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tab 4: Settings Panel
  Widget _buildSettingsPanel() {
    return SingleChildScrollView(
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
              Get.to(() => PremiumCreditView(onboarding: false, onDone: (){},));
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
                  Image.asset(
                    'assets/settting/ic.png',
                    width: 32,
                    height: 32,
                  ),
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
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
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
                    // Action for Contact Us
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
                    // Action for Share App
                  },
                ),
                _buildNewSettingsItem(
                  iconPath: 'assets/settting/Rate Us.png',
                  title: 'Rate Us',
                  onTap: () {
                    Get.to(() => const Ratingscreen());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Advance Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
                const SizedBox(height: 12),
                _buildNewSettingsItem(
                  iconPath: 'assets/settting/Feedback.png',
                  title: 'Feedback',
                  onTap: () {
                    // Action for Feedback
                  },
                ),
                _buildNewSettingsItem(
                  iconPath: 'assets/settting/Request a Feature.png',
                  title: 'Request A Feature',
                  onTap: () {
                    // Action for Request A Feature
                  },
                ),
              ],
            ),
          ),
        ],
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
            Image.asset(
              iconPath,
              width: 24,
              height: 24,
            ),
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
            return Container(
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
                      const Text(
                        'TV KEYBOARD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyboardController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                    onChanged: (text) {
                      if (_sendCharByChar && text.isNotEmpty) {
                        widget.manager.sendText(text.substring(text.length - 1));
                      }
                    },
                    onSubmitted: (text) {
                      _onKeyboardSubmit(text);
                      Navigator.pop(context);
                    },
                    decoration: InputDecoration(
                      hintText: 'Type here...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF222226),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white30),
                        onPressed: () => _keyboardController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          setModalState(() {
                            _sendCharByChar = val;
                          });
                          setState(() {
                            _sendCharByChar = val;
                          });
                        },
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModalKeyboardActionBtn(
                        label: 'BACKSPACE',
                        icon: Icons.backspace,
                        onPressed: () => _sendAction(TvKey.back),
                      ),
                      _buildModalKeyboardActionBtn(
                        label: 'ENTER',
                        icon: Icons.subdirectory_arrow_left,
                        onPressed: () {
                          if (!_sendCharByChar) {
                            _onKeyboardSubmit(_keyboardController.text);
                          } else {
                            _sendAction(TvKey.select);
                          }
                          Navigator.pop(context);
                        },
                      ),
                      _buildModalKeyboardActionBtn(
                        label: 'SPACE',
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
      child: Card(
        color: const Color(0xFF222226),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
        )
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
            colors: [
              Color(0xFF794DEB),
              Color(0xFF512CB8),
            ],
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
                  width: 110,  // was 150
                  height: 110, // was 150
                  decoration: inset.BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF794DEB),
                        Color(0xFF512CB8),
                      ],
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
                        fontSize: 16, // slightly smaller to match smaller button
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
        width: 40,  // was 54
        height: 40, // was 54
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
        content: const Text('Would you like to search for other devices of the same brand or switch TV brands entirely?'),
        actions: [
          TextButton(
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
            child: const Text('SWITCH BRAND'),
            onPressed: () {
              Navigator.pop(context);
              widget.manager.disconnect();
              Get.offAll(() => BrandSelectionScreen(manager: widget.manager));
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('DISCONNECT'),
            onPressed: () {
              Navigator.pop(context);
              widget.manager.disconnect();
              Get.offAll(() => BrandSelectionScreen(manager: widget.manager));
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
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }

    // Draw vertical dotted line
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(size.width / 2, startY), Offset(size.width / 2, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
