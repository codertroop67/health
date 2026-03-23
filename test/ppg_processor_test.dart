import 'package:flutter_test/flutter_test.dart';
import 'package:ppg_health_app/core/filters.dart';
import 'package:ppg_health_app/core/peak_detector.dart';
import 'dart:math';

void main() {
  group('BandpassFilter', () {
    test('should filter DC component', () {
      final filter = BandpassFilter(
        lowCutoff: 0.5,
        highCutoff: 4.0,
        sampleRate: 30.0,
      );

      // DC signal (constant value)
      final dcSignal = List.filled(100, 100.0);
      final filtered = filter.filterSignal(dcSignal);

      // After initial transient, output should be near zero
      final steadyState = filtered.sublist(50);
      final avgAbs = steadyState.map((v) => v.abs()).reduce((a, b) => a + b) /
          steadyState.length;

      expect(avgAbs, lessThan(1.0));
    });

    test('should pass signal within passband', () {
      final filter = BandpassFilter(
        lowCutoff: 0.5,
        highCutoff: 4.0,
        sampleRate: 30.0,
      );

      // Generate 1 Hz sine wave (within passband, ~60 BPM)
      final sampleRate = 30.0;
      final frequency = 1.0;
      final signal = List.generate(
        150,
        (i) => sin(2 * pi * frequency * i / sampleRate),
      );

      final filtered = filter.filterSignal(signal);

      // After initial transient, signal should still be present
      final steadyState = filtered.sublist(60);
      final maxAmp = steadyState.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);

      expect(maxAmp, greaterThan(0.3)); // Signal should pass through
    });
  });

  group('MovingAverageFilter', () {
    test('should smooth signal', () {
      final filter = MovingAverageFilter(windowSize: 5);

      final signal = [1.0, 10.0, 1.0, 10.0, 1.0, 10.0, 1.0, 10.0, 1.0, 10.0];
      final filtered = filter.filterSignal(signal);

      // Variance should be reduced
      final originalVariance = _variance(signal);
      final filteredVariance = _variance(filtered);

      expect(filteredVariance, lessThan(originalVariance));
    });
  });

  group('SignalNormalizer', () {
    test('should remove DC offset', () {
      final signal = [10.0, 12.0, 8.0, 11.0, 9.0];
      final normalized = SignalNormalizer.removeDCOffset(signal);

      final mean = normalized.reduce((a, b) => a + b) / normalized.length;
      expect(mean.abs(), lessThan(0.001));
    });

    test('should normalize to [-1, 1]', () {
      final signal = [-5.0, 0.0, 5.0, 10.0, -10.0];
      final normalized = SignalNormalizer.normalize(signal);

      expect(normalized.every((v) => v >= -1 && v <= 1), isTrue);
      expect(normalized.map((v) => v.abs()).reduce((a, b) => a > b ? a : b), equals(1.0));
    });
  });

  group('PeakDetector', () {
    test('should detect peaks in synthetic PPG signal', () {
      final detector = PeakDetector(sampleRate: 30.0);

      // Generate synthetic PPG signal at 60 BPM (1 Hz)
      final sampleRate = 30.0;
      final heartRate = 60.0; // BPM
      final frequency = heartRate / 60.0; // Hz

      // 5 seconds of data
      final signal = List.generate(
        150,
        (i) {
          final t = i / sampleRate;
          // Simulated PPG waveform with sharp systolic peak
          final phase = (t * frequency) % 1.0;
          if (phase < 0.2) {
            return sin(phase * pi / 0.2);
          } else {
            return 0.0;
          }
        },
      );

      final result = detector.detectPeaks(signal);

      expect(result.peakIndices.length, greaterThan(3));
      expect(result.averageBPM, isNotNull);
      expect(result.averageBPM!, closeTo(60.0, 10.0)); // Within 10 BPM
    });

    test('should return valid intervals between peaks', () {
      final detector = PeakDetector(sampleRate: 30.0);

      // Generate clean peaks at exactly 1 Hz
      final signal = List.generate(
        150,
        (i) => (i % 30 < 3) ? 1.0 : 0.0, // Peak every 30 samples (1 second at 30fps)
      );

      final result = detector.detectPeaks(signal);

      if (result.intervals.isNotEmpty) {
        // Each interval should be approximately 1 second
        for (final interval in result.intervals) {
          expect(interval, closeTo(1.0, 0.2));
        }
      }
    });
  });

  group('RealTimePeakDetector', () {
    test('should return BPM after sufficient samples', () {
      final detector = RealTimePeakDetector(
        windowSize: 90, // 3 seconds
        sampleRate: 30.0,
      );

      // Feed samples
      double? lastBpm;
      for (int i = 0; i < 150; i++) {
        final t = i / 30.0;
        // Simulate 72 BPM heart rate
        final value = sin(2 * pi * 1.2 * t);
        lastBpm = detector.addSample(value);
      }

      expect(lastBpm, isNotNull);
      expect(lastBpm!, greaterThan(50));
      expect(lastBpm!, lessThan(100));
    });

    test('should reset properly', () {
      final detector = RealTimePeakDetector(
        windowSize: 60,
        sampleRate: 30.0,
      );

      // Add some samples
      for (int i = 0; i < 100; i++) {
        detector.addSample(sin(i * 0.1));
      }

      detector.reset();

      expect(detector.currentBuffer, isEmpty);
    });
  });

  group('HRVMetrics', () {
    test('should calculate SDNN correctly', () {
      final detector = PeakDetector();

      // RR intervals in seconds (simulating ~60 BPM with some variation)
      final rrIntervals = [0.95, 1.05, 0.98, 1.02, 1.00, 0.97, 1.03, 0.99, 1.01, 0.96];

      final hrv = detector.calculateHRV(rrIntervals);

      expect(hrv, isNotNull);
      expect(hrv!.sdnn, greaterThan(0));
      expect(hrv.rmssd, greaterThan(0));
      expect(hrv.pnn50, greaterThanOrEqualTo(0));
      expect(hrv.pnn50, lessThanOrEqualTo(1));
      expect(hrv.meanRR, closeTo(1000, 100)); // ~1000ms mean
    });

    test('should return null for insufficient intervals', () {
      final detector = PeakDetector();

      final hrv = detector.calculateHRV([1.0, 1.0, 1.0]); // Only 3 intervals

      expect(hrv, isNull);
    });
  });
}

double _variance(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
}
