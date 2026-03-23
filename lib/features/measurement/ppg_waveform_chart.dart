import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Real-time PPG waveform visualization
class PPGWaveformChart extends StatelessWidget {
  final List<double> waveform;
  final int displayPoints;
  final Color lineColor;
  final double strokeWidth;

  const PPGWaveformChart({
    super.key,
    required this.waveform,
    this.displayPoints = 150,
    this.lineColor = Colors.redAccent,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    if (waveform.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the most recent points
    final points = waveform.length > displayPoints
        ? waveform.sublist(waveform.length - displayPoints)
        : waveform;

    // Normalize for display
    final normalized = _normalize(points);

    // Create chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < normalized.length; i++) {
      spots.add(FlSpot(i.toDouble(), normalized[i]));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: strokeWidth,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withOpacity(0.3),
                  lineColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: -1.2,
        maxY: 1.2,
        clipData: const FlClipData.all(),
      ),
      duration: const Duration(milliseconds: 0), // Disable animation for real-time
    );
  }

  /// Normalize signal to [-1, 1] range
  List<double> _normalize(List<double> signal) {
    if (signal.isEmpty) return [];

    final maxAbs = signal.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    if (maxAbs == 0) return signal.map((_) => 0.0).toList();

    return signal.map((s) => s / maxAbs).toList();
  }
}

/// Full-screen waveform viewer for results
class PPGWaveformViewer extends StatelessWidget {
  final List<double> waveform;
  final String title;

  const PPGWaveformViewer({
    super.key,
    required this.waveform,
    this.title = 'PPG Waveform',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: PPGWaveformChart(
              waveform: waveform,
              displayPoints: waveform.length,
              strokeWidth: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0s',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              Text(
                '${(waveform.length / 30).toStringAsFixed(1)}s',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini waveform indicator for compact display
class MiniWaveformIndicator extends StatelessWidget {
  final List<double> waveform;
  final double width;
  final double height;
  final Color color;

  const MiniWaveformIndicator({
    super.key,
    required this.waveform,
    this.width = 100,
    this.height = 30,
    this.color = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniWaveformPainter(
          waveform: waveform,
          color: color,
        ),
      ),
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  _MiniWaveformPainter({
    required this.waveform,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = waveform.length > 50 ? waveform.sublist(waveform.length - 50) : waveform;

    // Normalize
    final maxAbs = points.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    final normalized = maxAbs > 0 ? points.map((s) => s / maxAbs).toList() : points;

    final dx = size.width / (normalized.length - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < normalized.length; i++) {
      final x = i * dx;
      final y = centerY - (normalized[i] * centerY * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) {
    return waveform != oldDelegate.waveform;
  }
}
