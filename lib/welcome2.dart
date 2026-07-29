
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../for_ads/utils/firebase_analysis.dart';

class Welcome2 extends StatefulWidget {
  final bool isActive;
  const Welcome2({super.key, required this.isActive});

  @override
  State<Welcome2> createState() => _Welcome2State();
}

class _Welcome2State extends State<Welcome2> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService.logEvent(eventName: 'INTRO_SCREEN_2');
    _controller = VideoPlayerController.asset(
      'assets/intro/intro_videos/intro_2.mp4',
    )..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          if (widget.isActive) {
            _controller.play();
          }
        }
      });
  }

  @override
  void didUpdateWidget(covariant Welcome2 oldWidget) {
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