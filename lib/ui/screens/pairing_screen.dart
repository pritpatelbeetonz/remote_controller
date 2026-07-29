import 'package:flutter/material.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'remote_screen.dart';

class PairingScreen extends StatefulWidget {
  final TvRemoteManager manager;

  const PairingScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onStateChange);
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onStateChange() {
    if (widget.manager.connectionState == TvConnectionState.connected) {
      // Pairing successful! Route to remote screen.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RemoteScreen(manager: widget.manager),
        ),
        (route) => false, // Remove all previous routes
      );
    } else if (widget.manager.connectionState == TvConnectionState.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing failed. Please check the code and try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submitPin();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _submitPin() {
    final pin = _controllers.map((c) => c.text.trim()).join();
    if (pin.length == 6) {
      widget.manager.submitPin(pin);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 6 characters of the PIN code.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final deviceName = manager.currentDevice?.name ?? 'Android TV';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PAIRING CODE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            manager.disconnect();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // TV Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow(AppTheme.primary),
                        ),
                        child: const Icon(
                          Icons.vpn_key_outlined,
                          color: AppTheme.primary,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                     // Prompt text
                    Text(
                      manager.pairingPin == 'CONFIRM ON TV'
                          ? 'Allow Connection on TV'
                          : 'Enter the 6-character PIN shown on your TV screen ($deviceName)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dynamic Entry / Spinner Fields
                    if (manager.pairingPin == 'CONFIRM ON TV')
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Please press "Allow" on your TV screen using your physical TV Remote to complete pairing.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return Container(
                            width: 48,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border, width: 1.5),
                            ),
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              maxLength: 1,
                              onChanged: (val) => _onPinChanged(index, val),
                            ),
                          );
                        }),
                      ),
                    const SizedBox(height: 40),

                    // Pairing status feedback
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: manager.connectionState == TvConnectionState.pairing
                                    ? AppTheme.warning
                                    : AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              manager.pairingStatusMessage ?? 'Establishing SSL Handshake...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Connect button
                    ElevatedButton(
                      onPressed: _submitPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shadowColor: AppTheme.primary.withOpacity(0.5),
                        elevation: 5,
                      ),
                      child: const Text('VERIFY & LINK'),
                    ),
                  ],
                ),
              ),
            ),

            // Log Console Overlay
           // LogConsoleDrawer(manager: manager),
          ],
        ),
      ),
    );
  }
}
