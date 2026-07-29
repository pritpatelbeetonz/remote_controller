import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
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

  bool _isNavigating = false;

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
    if (_isNavigating) return;

    if (widget.manager.connectionState == TvConnectionState.connected) {
      _isNavigating = true;
      // Pairing successful! Route to remote screen.
      Get.offAll(() => RemoteScreen(manager: widget.manager));
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
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          'Pairing Code',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20.sp,
            fontFamily: 'SF Pro Display',
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            manager.disconnect();
            Get.back();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              const Spacer(),
              // Title
              Text(
                '6-Digit Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro Display',
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10.h),
              // Subtitle
              Text(
                'Enter the 6-digit PIN displayed on your TV',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: 'SF Pro Display',
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 40.h),

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
                      width: 46.w,
                      height: 58.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: TextField(
                        autofocus: index == 0,
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              const Spacer(),

              // Pairing status feedback (optional, but keep it clean if present)
              if (manager.pairingStatusMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: Center(
                    child: Text(
                      manager.pairingStatusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                ),

              // Connect button
              GestureDetector(
                onTap: _submitPin,
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(33.33.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }
}
