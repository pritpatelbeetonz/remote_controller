import 'package:flutter/material.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'discovery_screen.dart';
import 'brand_selection_screen.dart';

class RemoteScreen extends StatefulWidget {
  final TvRemoteManager manager;

  const RemoteScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  bool _showConsole = false;

  void _sendAction(TvKey key) {
    if (widget.manager.connectionState != TvConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to TV. Redirecting to brand selection...'),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BrandSelectionScreen(manager: widget.manager)),
        (route) => false,
      );
      return;
    }
    widget.manager.sendPress(key);
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final deviceName = manager.currentDevice?.name ?? 'Android TV';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar/Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.power_settings_new, color: AppTheme.error),
                    onPressed: () {
                      _showDisconnectConfirmation();
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          deviceName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: manager.connectionState == TvConnectionState.connected
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              manager.connectionState == TvConnectionState.connected
                                  ? 'CONNECTED'
                                  : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: manager.connectionState == TvConnectionState.connected
                                    ? AppTheme.success
                                    : AppTheme.error,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Terminal Console Toggle
                  IconButton(
                    icon: Icon(
                      Icons.terminal,
                      color: _showConsole ? AppTheme.primary : Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _showConsole = !_showConsole;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Remote Control Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Power & Mute Top Panel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRoundButton(
                          icon: Icons.power_settings_new,
                          color: AppTheme.error,
                          onPressed: () => _sendAction(TvKey.power),
                        ),
                        _buildRoundButton(
                          icon: Icons.volume_mute,
                          color: Colors.white60,
                          onPressed: () => _sendAction(TvKey.mute),
                        ),
                      ],
                    ),

                    // Tactile D-Pad Component
                    _buildTactileDpad(),

                    // Action buttons (Back, Home, Play/Pause)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.arrow_back,
                          label: 'BACK',
                          onPressed: () => _sendAction(TvKey.back),
                        ),
                        _buildActionButton(
                          icon: Icons.play_arrow,
                          label: 'PLAY/PAUSE',
                          onPressed: () => _sendAction(TvKey.playPause),
                        ),
                        _buildActionButton(
                          icon: Icons.home_outlined,
                          label: 'HOME',
                          onPressed: () => _sendAction(TvKey.home),
                        ),
                      ],
                    ),

                    // Volume Controls
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_down, color: Colors.white70),
                            onPressed: () => _sendAction(TvKey.volumeDown),
                          ),
                          const Text(
                            'VOLUME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.white38,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Colors.white70),
                            onPressed: () => _sendAction(TvKey.volumeUp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Live debug log console drawer
            if (_showConsole)
              LogConsoleDrawer(
                manager: manager,
                onClose: () {
                  setState(() {
                    _showConsole = false;
                  });
                },
              ),
          ],
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => BrandSelectionScreen(manager: widget.manager)),
                (route) => false,
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('DISCONNECT'),
            onPressed: () {
              final brand = widget.manager.currentDevice?.brand ?? 'Android TV';
              Navigator.pop(context);
              widget.manager.disconnect();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => DiscoveryScreen(manager: widget.manager, selectedBrand: brand)),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

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
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Stack(
        children: [
          // Center Select Button
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _sendAction(TvKey.select),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border, width: 2),
                  boxShadow: AppTheme.glowShadow(AppTheme.primary),
                ),
                child: const Center(
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.primary,
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
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildDpadDirection(
                icon: Icons.keyboard_arrow_up,
                onPressed: () => _sendAction(TvKey.up),
              ),
            ),
          ),

          // D-Pad Down
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildDpadDirection(
                icon: Icons.keyboard_arrow_down,
                onPressed: () => _sendAction(TvKey.down),
              ),
            ),
          ),

          // D-Pad Left
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: _buildDpadDirection(
                icon: Icons.keyboard_arrow_left,
                onPressed: () => _sendAction(TvKey.left),
              ),
            ),
          ),

          // D-Pad Right
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildDpadDirection(
                icon: Icons.keyboard_arrow_right,
                onPressed: () => _sendAction(TvKey.right),
              ),
            ),
          ),
        ],
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
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }
}
