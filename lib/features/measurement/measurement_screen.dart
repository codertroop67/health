import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ppg_processor.dart';
import '../results/results_screen.dart';
import 'measurement_controller.dart';
import 'camera_view.dart';
import 'ppg_waveform_chart.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  late MeasurementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<MeasurementController>();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _controller.initialize();
  }

  @override
  void dispose() {
    _controller.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Measurement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _controller.stopMeasurement();
            Navigator.pop(context);
          },
        ),
      ),
      body: Consumer<MeasurementController>(
        builder: (context, controller, child) {
          return _buildBody(controller);
        },
      ),
    );
  }

  Widget _buildBody(MeasurementController controller) {
    // Show results if measurement is complete
    if (controller.result != null && controller.result!.isValid) {
      return _buildResultsView(controller);
    }

    // Show error if any
    if (controller.errorMessage != null && !controller.isMeasuring) {
      return _buildErrorView(controller);
    }

    // Show measurement interface
    return Column(
      children: [
        // Camera preview
        Expanded(
          flex: 3,
          child: _buildCameraPreview(controller),
        ),

        // Signal quality and status
        Expanded(
          flex: 2,
          child: _buildMeasurementInfo(controller),
        ),

        // Control buttons
        Padding(
          padding: const EdgeInsets.all(24),
          child: _buildControls(controller),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(MeasurementController controller) {
    if (!controller.isInitialized || controller.cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return CameraView(
      controller: controller.cameraController!,
      isMeasuring: controller.isMeasuring,
      signalQuality: controller.signalQuality,
    );
  }

  Widget _buildMeasurementInfo(MeasurementController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Signal quality indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Color(controller.signalQualityColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(controller.signalQualityColor),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  controller.signalQuality == SignalQuality.poor
                      ? Icons.warning
                      : Icons.check_circle,
                  color: Color(controller.signalQualityColor),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  controller.signalQualityText,
                  style: TextStyle(
                    color: Color(controller.signalQualityColor),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Heart rate display
          if (controller.isMeasuring && controller.currentBPM > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.favorite,
                  color: Colors.redAccent,
                  size: 40,
                ),
                const SizedBox(width: 8),
                Text(
                  controller.currentBPM.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'BPM',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Confidence indicator
            Text(
              'Confidence: ${(controller.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ] else if (!controller.isMeasuring) ...[
            const Text(
              'Place your finger on the camera',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep your finger still during measurement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ] else ...[
            const Text(
              'Detecting signal...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // PPG waveform
          if (controller.isMeasuring && controller.waveform.length > 10)
            SizedBox(
              height: 60,
              child: PPGWaveformChart(waveform: controller.waveform),
            ),

          // Progress and timer
          if (controller.isMeasuring) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: controller.progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.remainingSeconds} seconds remaining',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(MeasurementController controller) {
    if (controller.isMeasuring) {
      return ElevatedButton.icon(
        onPressed: () => controller.stopMeasurement(),
        icon: const Icon(Icons.stop),
        label: const Text('Stop'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: controller.isInitialized ? () => controller.startMeasurement() : null,
      icon: const Icon(Icons.favorite, size: 28),
      label: const Text(
        'Start Measurement',
        style: TextStyle(fontSize: 18),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildResultsView(MeasurementController controller) {
    return ResultsScreen(
      result: controller.result!,
      onMeasureAgain: () => controller.reset(),
      onDone: () => Navigator.pop(context),
    );
  }

  Widget _buildErrorView(MeasurementController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            Text(
              controller.errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => controller.reset(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
