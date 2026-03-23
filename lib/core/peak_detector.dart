import 'dart:math';

/// Peak detection result
class PeakResult {
  final List<int> peakIndices;
  final List<double> peakValues;
  final List<double> intervals; // Time between peaks in seconds
  final double? averageBPM;
  final double? confidence;

  PeakResult({
    required this.peakIndices,
    required this.peakValues,
    required this.intervals,
    this.averageBPM,
    this.confidence,
  });

  bool get isValid => peakIndices.length >= 3 && confidence != null && confidence! > 0.5;
}

/// Heart rate variability metrics
class HRVMetrics {
  final double sdnn; // Standard deviation of NN intervals
  final double rmssd; // Root mean square of successive differences
  final double pnn50; // Percentage of intervals differing by >50ms
  final double meanRR; // Mean RR interval in ms

  HRVMetrics({
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.meanRR,
  });

  @override
  String toString() {
    return 'HRV(SDNN: ${sdnn.toStringAsFixed(1)}ms, RMSSD: ${rmssd.toStringAsFixed(1)}ms, pNN50: ${(pnn50 * 100).toStringAsFixed(1)}%)';
  }
}

/// Peak detector for PPG signals using adaptive threshold
class PeakDetector {
  final double sampleRate;
  final double minBPM;
  final double maxBPM;
  final double adaptiveThresholdFactor;

  late final double _minPeakDistance; // Minimum samples between peaks
  // ignore: unused_field - reserved for future interval validation
  late final double _maxPeakDistance; // Maximum samples between peaks

  PeakDetector({
    this.sampleRate = 30.0,
    this.minBPM = 40.0,
    this.maxBPM = 200.0,
    this.adaptiveThresholdFactor = 0.6,
  }) {
    // Convert BPM to sample distance
    _minPeakDistance = sampleRate * 60.0 / maxBPM; // Max BPM = min distance
    _maxPeakDistance = sampleRate * 60.0 / minBPM; // Min BPM = max distance
  }

  /// Detect peaks in the PPG signal
  PeakResult detectPeaks(List<double> signal) {
    if (signal.length < 10) {
      return PeakResult(
        peakIndices: [],
        peakValues: [],
        intervals: [],
        averageBPM: null,
        confidence: 0.0,
      );
    }

    final peakIndices = <int>[];
    final peakValues = <double>[];

    // Calculate adaptive threshold
    final threshold = _calculateAdaptiveThreshold(signal);

    // Find local maxima above threshold
    for (int i = 2; i < signal.length - 2; i++) {
      if (_isLocalMaximum(signal, i) && signal[i] > threshold) {
        // Check minimum distance from last peak
        if (peakIndices.isEmpty ||
            (i - peakIndices.last) >= _minPeakDistance) {
          peakIndices.add(i);
          peakValues.add(signal[i]);
        } else if (signal[i] > peakValues.last) {
          // Replace last peak if this one is higher
          peakIndices[peakIndices.length - 1] = i;
          peakValues[peakValues.length - 1] = signal[i];
        }
      }
    }

    // Calculate intervals
    final intervals = _calculateIntervals(peakIndices);

    // Calculate BPM
    double? avgBPM;
    if (intervals.isNotEmpty) {
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      avgBPM = 60.0 / avgInterval;
    }

    // Calculate confidence
    final confidence = _calculateConfidence(intervals, signal);

    return PeakResult(
      peakIndices: peakIndices,
      peakValues: peakValues,
      intervals: intervals,
      averageBPM: avgBPM,
      confidence: confidence,
    );
  }

  /// Calculate adaptive threshold based on signal characteristics
  double _calculateAdaptiveThreshold(List<double> signal) {
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final maxVal = signal.reduce((a, b) => a > b ? a : b);
    final minVal = signal.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;

    // Threshold is mean + fraction of the range above mean
    return mean + (range * adaptiveThresholdFactor * 0.3);
  }

  /// Check if point is a local maximum
  bool _isLocalMaximum(List<double> signal, int index) {
    return signal[index] > signal[index - 1] &&
        signal[index] > signal[index - 2] &&
        signal[index] > signal[index + 1] &&
        signal[index] > signal[index + 2];
  }

  /// Calculate time intervals between peaks in seconds
  List<double> _calculateIntervals(List<int> peakIndices) {
    if (peakIndices.length < 2) return [];

    final intervals = <double>[];
    for (int i = 1; i < peakIndices.length; i++) {
      final intervalSamples = peakIndices[i] - peakIndices[i - 1];
      final intervalSeconds = intervalSamples / sampleRate;
      intervals.add(intervalSeconds);
    }
    return intervals;
  }

  /// Calculate confidence score (0-1) based on signal quality
  double _calculateConfidence(List<double> intervals, List<double> signal) {
    if (intervals.length < 2) return 0.0;

    // Factor 1: Interval consistency (lower variance = higher confidence)
    final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
            .map((i) => pow(i - meanInterval, 2))
            .reduce((a, b) => a + b) /
        intervals.length;
    final cv = sqrt(variance) / meanInterval; // Coefficient of variation
    final intervalConfidence = (1 - cv.clamp(0.0, 1.0));

    // Factor 2: Signal quality (SNR estimation)
    final signalQuality = _estimateSignalQuality(signal);

    // Factor 3: Reasonable BPM range
    final bpm = 60.0 / meanInterval;
    final bpmConfidence = (bpm >= minBPM && bpm <= maxBPM) ? 1.0 : 0.5;

    // Factor 4: Sufficient peaks detected
    final peakCountConfidence = (intervals.length / 10).clamp(0.0, 1.0);

    // Weighted average of factors
    return (intervalConfidence * 0.4 +
            signalQuality * 0.3 +
            bpmConfidence * 0.2 +
            peakCountConfidence * 0.1)
        .clamp(0.0, 1.0);
  }

  /// Estimate signal quality (0-1)
  double _estimateSignalQuality(List<double> signal) {
    if (signal.length < 10) return 0.0;

    // Calculate signal energy
    final energy = signal.map((s) => s * s).reduce((a, b) => a + b);
    if (energy == 0) return 0.0;

    // Calculate derivative energy (noise indicator)
    double noiseEnergy = 0;
    for (int i = 1; i < signal.length; i++) {
      final diff = signal[i] - signal[i - 1];
      noiseEnergy += diff * diff;
    }

    // Higher ratio of signal to noise energy = better quality
    final snr = energy / (noiseEnergy + 1e-10);
    return (snr / (snr + 10)).clamp(0.0, 1.0); // Normalize to 0-1
  }

  /// Calculate heart rate variability metrics
  HRVMetrics? calculateHRV(List<double> rrIntervals) {
    if (rrIntervals.length < 5) return null;

    // Convert to milliseconds
    final rrMs = rrIntervals.map((r) => r * 1000).toList();

    // Mean RR
    final meanRR = rrMs.reduce((a, b) => a + b) / rrMs.length;

    // SDNN - Standard deviation of NN intervals
    final sdnn = sqrt(
        rrMs.map((r) => pow(r - meanRR, 2)).reduce((a, b) => a + b) /
            rrMs.length);

    // RMSSD - Root mean square of successive differences
    double sumSquaredDiff = 0;
    for (int i = 1; i < rrMs.length; i++) {
      sumSquaredDiff += pow(rrMs[i] - rrMs[i - 1], 2);
    }
    final rmssd = sqrt(sumSquaredDiff / (rrMs.length - 1));

    // pNN50 - Percentage of intervals differing by >50ms
    int nn50Count = 0;
    for (int i = 1; i < rrMs.length; i++) {
      if ((rrMs[i] - rrMs[i - 1]).abs() > 50) {
        nn50Count++;
      }
    }
    final pnn50 = nn50Count / (rrMs.length - 1);

    return HRVMetrics(
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
      meanRR: meanRR,
    );
  }
}

/// Real-time peak detector with sliding window
class RealTimePeakDetector {
  final int windowSize;
  final double sampleRate;
  final List<double> _buffer = [];
  final List<int> _recentPeaks = [];
  final PeakDetector _detector;

  double _lastBPM = 0;
  double _smoothedBPM = 0;
  final double _smoothingFactor = 0.3;

  RealTimePeakDetector({
    this.windowSize = 150, // ~5 seconds at 30fps
    this.sampleRate = 30.0,
  }) : _detector = PeakDetector(sampleRate: sampleRate);

  /// Add a new sample and get current BPM estimate
  double? addSample(double sample) {
    _buffer.add(sample);
    if (_buffer.length > windowSize) {
      _buffer.removeAt(0);
    }

    if (_buffer.length < windowSize ~/ 2) {
      return null; // Not enough data yet
    }

    // Detect peaks in buffer
    final result = _detector.detectPeaks(_buffer);

    if (result.averageBPM != null && result.confidence! > 0.4) {
      _lastBPM = result.averageBPM!;
      _smoothedBPM = _smoothingFactor * _lastBPM +
          (1 - _smoothingFactor) * _smoothedBPM;
      return _smoothedBPM;
    }

    return _smoothedBPM > 0 ? _smoothedBPM : null;
  }

  void reset() {
    _buffer.clear();
    _recentPeaks.clear();
    _lastBPM = 0;
    _smoothedBPM = 0;
  }

  double get confidence {
    if (_buffer.length < windowSize ~/ 2) return 0.0;
    final result = _detector.detectPeaks(_buffer);
    return result.confidence ?? 0.0;
  }

  List<double> get currentBuffer => List.unmodifiable(_buffer);
}
