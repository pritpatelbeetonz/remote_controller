import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../for_ads/utils/firebase_analysis.dart';

class Welcome1 extends StatefulWidget {
  final bool isActive;
  const Welcome1({super.key, required this.isActive});

  @override
  State<Welcome1> createState() => _Welcome1State();
}

class _Welcome1State extends State<Welcome1> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService.logEvent(eventName: 'INROSCREEN_1');
    _controller = VideoPlayerController.asset(
      'assets/intro/intro_videos/intro_1.mp4',
    )..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.setVolume(0.0);
          if (widget.isActive) {
            _controller.play();
          }
        }
      });
  }

  @override
  void didUpdateWidget(covariant Welcome1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
        _controller.seekTo(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : Container(color: Colors.black),
    );
  }
}
