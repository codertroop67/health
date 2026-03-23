import 'package:flutter/material.dart';
import '../../core/peak_detector.dart';

/// Widget displaying health assessment based on heart rate
class HealthMetricsCard extends StatelessWidget {
  final double heartRate;
  final HRVMetrics? hrvMetrics;

  const HealthMetricsCard({
    super.key,
    required this.heartRate,
    this.hrvMetrics,
  });

  @override
  Widget build(BuildContext context) {
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
                Icons.health_and_safety,
                color: Colors.green,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Health Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heart rate zone
          _buildMetricRow(
            'Heart Rate Zone',
            _getHeartRateZone(heartRate),
            _getZoneColor(heartRate),
          ),

          const Divider(color: Colors.white12, height: 24),

          // Cardiovascular fitness indicator
          _buildMetricRow(
            'Resting HR Assessment',
            _getCardioAssessment(heartRate),
            _getAssessmentColor(heartRate),
          ),

          if (hrvMetrics != null) ...[
            const Divider(color: Colors.white12, height: 24),

            // HRV-based stress indicator
            _buildMetricRow(
              'Stress Level',
              _getStressLevel(hrvMetrics!),
              _getStressColor(hrvMetrics!),
            ),

            const Divider(color: Colors.white12, height: 24),

            // Recovery status
            _buildMetricRow(
              'Recovery Status',
              _getRecoveryStatus(hrvMetrics!),
              _getRecoveryColor(hrvMetrics!),
            ),
          ],

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is for informational purposes only. Consult a healthcare professional for medical advice.',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHeartRateZone(double hr) {
    if (hr < 50) return 'Very Low';
    if (hr < 60) return 'Low';
    if (hr < 70) return 'Optimal';
    if (hr < 80) return 'Normal';
    if (hr < 100) return 'Moderate';
    if (hr < 120) return 'Elevated';
    return 'High';
  }

  Color _getZoneColor(double hr) {
    if (hr < 50) return Colors.blue;
    if (hr < 60) return Colors.lightBlue;
    if (hr < 80) return Colors.green;
    if (hr < 100) return Colors.lightGreen;
    if (hr < 120) return Colors.orange;
    return Colors.red;
  }

  String _getCardioAssessment(double hr) {
    // Based on typical resting heart rate ranges
    if (hr < 50) return 'Athletic';
    if (hr < 60) return 'Excellent';
    if (hr < 70) return 'Good';
    if (hr < 80) return 'Average';
    if (hr < 90) return 'Below Average';
    return 'Poor';
  }

  Color _getAssessmentColor(double hr) {
    if (hr < 60) return Colors.green;
    if (hr < 80) return Colors.lightGreen;
    if (hr < 90) return Colors.orange;
    return Colors.red;
  }

  String _getStressLevel(HRVMetrics hrv) {
    // Higher RMSSD generally indicates lower stress
    if (hrv.rmssd > 50) return 'Low';
    if (hrv.rmssd > 30) return 'Moderate';
    if (hrv.rmssd > 20) return 'Elevated';
    return 'High';
  }

  Color _getStressColor(HRVMetrics hrv) {
    if (hrv.rmssd > 50) return Colors.green;
    if (hrv.rmssd > 30) return Colors.lightGreen;
    if (hrv.rmssd > 20) return Colors.orange;
    return Colors.red;
  }

  String _getRecoveryStatus(HRVMetrics hrv) {
    // pNN50 is an indicator of parasympathetic activity (recovery)
    if (hrv.pnn50 > 0.25) return 'Well Recovered';
    if (hrv.pnn50 > 0.15) return 'Recovered';
    if (hrv.pnn50 > 0.05) return 'Recovering';
    return 'Needs Rest';
  }

  Color _getRecoveryColor(HRVMetrics hrv) {
    if (hrv.pnn50 > 0.25) return Colors.green;
    if (hrv.pnn50 > 0.15) return Colors.lightGreen;
    if (hrv.pnn50 > 0.05) return Colors.orange;
    return Colors.red;
  }
}

/// Heart rate history chart (placeholder for future implementation)
class HeartRateHistoryCard extends StatelessWidget {
  final List<HeartRateReading> readings;

  const HeartRateHistoryCard({
    super.key,
    required this.readings,
  });

  @override
  Widget build(BuildContext context) {
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
                Icons.show_chart,
                color: Colors.blue,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Recent Measurements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (readings.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No previous measurements',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: readings.length.clamp(0, 5),
              itemBuilder: (context, index) {
                final reading = readings[index];
                return _buildReadingRow(reading);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReadingRow(HeartRateReading reading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.favorite,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '${reading.bpm.toStringAsFixed(0)} BPM',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            _formatDateTime(reading.timestamp),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}';
  }
}

/// Simple data class for heart rate readings
class HeartRateReading {
  final double bpm;
  final DateTime timestamp;
  final double? confidence;

  HeartRateReading({
    required this.bpm,
    required this.timestamp,
    this.confidence,
  });
}
