import 'package:flutter/material.dart';
import '../../core/ppg_processor.dart';
import '../../core/peak_detector.dart';
import '../measurement/ppg_waveform_chart.dart';
import 'health_metrics.dart';

class ResultsScreen extends StatelessWidget {
  final PPGResult result;
  final VoidCallback onMeasureAgain;
  final VoidCallback onDone;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.onMeasureAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Success icon
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Measurement Complete',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // Heart rate card
          _buildHeartRateCard(),
          const SizedBox(height: 24),

          // HRV metrics (if available)
          if (result.hrvMetrics != null) ...[
            _buildHRVCard(result.hrvMetrics!),
            const SizedBox(height: 24),
          ],

          // Signal quality and confidence
          _buildQualityCard(),
          const SizedBox(height: 24),

          // Waveform
          PPGWaveformViewer(
            waveform: result.ppgWaveform,
            title: 'Your PPG Waveform',
          ),
          const SizedBox(height: 24),

          // Health assessment
          HealthMetricsCard(
            heartRate: result.heartRate,
            hrvMetrics: result.hrvMetrics,
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMeasureAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Measure Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.done),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1E1E), Color(0xFF1E1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.favorite,
                size: 50,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 12),
              Text(
                result.heartRate.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  ' BPM',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getHeartRateDescription(result.heartRate),
            style: TextStyle(
              fontSize: 16,
              color: _getHeartRateColor(result.heartRate),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRVCard(HRVMetrics hrv) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.timeline,
                color: Colors.blue,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Heart Rate Variability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHRVMetric(
                  'SDNN',
                  '${hrv.sdnn.toStringAsFixed(1)} ms',
                  'Standard deviation',
                ),
              ),
              Expanded(
                child: _buildHRVMetric(
                  'RMSSD',
                  '${hrv.rmssd.toStringAsFixed(1)} ms',
                  'Beat-to-beat variation',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHRVMetric(
                  'pNN50',
                  '${(hrv.pnn50 * 100).toStringAsFixed(1)}%',
                  'Recovery indicator',
                ),
              ),
              Expanded(
                child: _buildHRVMetric(
                  'Mean RR',
                  '${hrv.meanRR.toStringAsFixed(0)} ms',
                  'Average interval',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHRVMetric(String label, String value, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildQualityItem(
            'Signal Quality',
            _getSignalQualityText(result.signalQuality),
            _getSignalQualityColor(result.signalQuality),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          const SizedBox(width: 16),
          _buildQualityItem(
            'Confidence',
            '${(result.confidence * 100).toStringAsFixed(0)}%',
            _getConfidenceColor(result.confidence),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          const SizedBox(width: 16),
          _buildQualityItem(
            'Duration',
            '${result.measurementDurationSeconds}s',
            Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildQualityItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getHeartRateDescription(double hr) {
    if (hr < 60) return 'Below normal resting range';
    if (hr <= 100) return 'Normal resting heart rate';
    if (hr <= 120) return 'Slightly elevated';
    return 'Elevated heart rate';
  }

  Color _getHeartRateColor(double hr) {
    if (hr < 50) return Colors.blue;
    if (hr < 60) return Colors.lightBlue;
    if (hr <= 100) return Colors.green;
    if (hr <= 120) return Colors.orange;
    return Colors.red;
  }

  String _getSignalQualityText(SignalQuality quality) {
    switch (quality) {
      case SignalQuality.excellent:
        return 'Excellent';
      case SignalQuality.good:
        return 'Good';
      case SignalQuality.fair:
        return 'Fair';
      case SignalQuality.poor:
        return 'Poor';
    }
  }

  Color _getSignalQualityColor(SignalQuality quality) {
    switch (quality) {
      case SignalQuality.excellent:
        return Colors.green;
      case SignalQuality.good:
        return Colors.lightGreen;
      case SignalQuality.fair:
        return Colors.orange;
      case SignalQuality.poor:
        return Colors.red;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.lightGreen;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
