import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/ppg_processor.dart';

/// Camera preview widget with finger placement guide
class CameraView extends StatelessWidget {
  final CameraController controller;
  final bool isMeasuring;
  final SignalQuality signalQuality;

  const CameraView({
    super.key,
    required this.controller,
    required this.isMeasuring,
    required this.signalQuality,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),

        // Overlay with finger placement guide
        _buildOverlay(),

        // Pulse animation when measuring
        if (isMeasuring && signalQuality != SignalQuality.poor)
          _buildPulseAnimation(),
      ],
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 4,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Finger placement circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getBorderColor().withOpacity(0.8),
                  width: 3,
                ),
                color: Colors.black.withOpacity(0.3),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 60,
                color: _getBorderColor().withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getInstructionText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseAnimation() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.2),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
          );
        },
        onEnd: () {
          // Animation will repeat
        },
      ),
    );
  }

  Color _getBorderColor() {
    if (!isMeasuring) {
      return Colors.white54;
    }

    switch (signalQuality) {
      case SignalQuality.excellent:
        return Colors.green;
      case SignalQuality.good:
        return Colors.lightGreen;
      case SignalQuality.fair:
        return Colors.amber;
      case SignalQuality.poor:
        return Colors.red;
    }
  }

  String _getInstructionText() {
    if (!isMeasuring) {
      return 'Place finger here';
    }

    switch (signalQuality) {
      case SignalQuality.excellent:
        return 'Perfect! Keep still';
      case SignalQuality.good:
        return 'Good signal';
      case SignalQuality.fair:
        return 'Hold steady';
      case SignalQuality.poor:
        return 'Cover camera completely';
    }
  }
}

/// Pulsing heart icon animation
class PulsingHeart extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingHeart({
    super.key,
    this.size = 40,
    this.color = Colors.redAccent,
  });

  @override
  State<PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<PulsingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            Icons.favorite,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Countdown timer widget
class CountdownTimer extends StatelessWidget {
  final int seconds;
  final double progress;

  const CountdownTimer({
    super.key,
    required this.seconds,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
        Text(
          '$seconds',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
