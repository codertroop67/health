import 'dart:math';

/// Bandpass filter for PPG signal processing.
/// Filters out frequencies outside the typical heart rate range (0.5-4 Hz = 30-240 BPM).
class BandpassFilter {
  final double lowCutoff;
  final double highCutoff;
  final double sampleRate;
  final int order;

  // Filter coefficients
  late final List<double> _aCoeffs;
  late final List<double> _bCoeffs;

  // Filter state
  late List<double> _xHistory;
  late List<double> _yHistory;

  BandpassFilter({
    this.lowCutoff = 0.5, // 30 BPM minimum
    this.highCutoff = 4.0, // 240 BPM maximum
    this.sampleRate = 30.0, // Typical camera frame rate
    this.order = 2,
  }) {
    _initializeFilter();
  }

  void _initializeFilter() {
    // Simple 2nd order Butterworth bandpass filter coefficients
    // Using bilinear transform approximation
    final nyquist = sampleRate / 2;
    final lowNorm = lowCutoff / nyquist;
    final highNorm = highCutoff / nyquist;

    // Pre-warping
    final wLow = tan(pi * lowNorm);
    final wHigh = tan(pi * highNorm);
    final bw = wHigh - wLow;
    final w0 = sqrt(wLow * wHigh);

    // Butterworth coefficients
    final q = w0 / bw;
    final alpha = sin(w0) / (2 * q);

    final b0 = alpha;
    final b1 = 0.0;
    final b2 = -alpha;
    final a0 = 1 + alpha;
    final a1 = -2 * cos(w0);
    final a2 = 1 - alpha;

    // Normalize
    _bCoeffs = [b0 / a0, b1 / a0, b2 / a0];
    _aCoeffs = [1.0, a1 / a0, a2 / a0];

    // Initialize history
    _xHistory = List.filled(3, 0.0);
    _yHistory = List.filled(3, 0.0);
  }

  /// Filter a single sample
  double filter(double sample) {
    // Shift history
    _xHistory[2] = _xHistory[1];
    _xHistory[1] = _xHistory[0];
    _xHistory[0] = sample;

    _yHistory[2] = _yHistory[1];
    _yHistory[1] = _yHistory[0];

    // Apply filter
    _yHistory[0] = _bCoeffs[0] * _xHistory[0] +
        _bCoeffs[1] * _xHistory[1] +
        _bCoeffs[2] * _xHistory[2] -
        _aCoeffs[1] * _yHistory[1] -
        _aCoeffs[2] * _yHistory[2];

    return _yHistory[0];
  }

  /// Reset filter state
  void reset() {
    _xHistory = List.filled(3, 0.0);
    _yHistory = List.filled(3, 0.0);
  }

  /// Filter an entire signal
  List<double> filterSignal(List<double> signal) {
    reset();
    return signal.map((s) => filter(s)).toList();
  }
}

/// Moving average filter for smoothing
class MovingAverageFilter {
  final int windowSize;
  final List<double> _buffer = [];

  MovingAverageFilter({this.windowSize = 5});

  double filter(double sample) {
    _buffer.add(sample);
    if (_buffer.length > windowSize) {
      _buffer.removeAt(0);
    }
    return _buffer.reduce((a, b) => a + b) / _buffer.length;
  }

  void reset() {
    _buffer.clear();
  }

  List<double> filterSignal(List<double> signal) {
    reset();
    return signal.map((s) => filter(s)).toList();
  }
}

/// Exponential moving average for real-time smoothing
class ExponentialMovingAverage {
  final double alpha;
  double? _previousValue;

  ExponentialMovingAverage({this.alpha = 0.3});

  double filter(double sample) {
    if (_previousValue == null) {
      _previousValue = sample;
      return sample;
    }
    _previousValue = alpha * sample + (1 - alpha) * _previousValue!;
    return _previousValue!;
  }

  void reset() {
    _previousValue = null;
  }
}

/// Removes DC offset and normalizes signal
class SignalNormalizer {
  /// Remove DC offset by subtracting mean
  static List<double> removeDCOffset(List<double> signal) {
    if (signal.isEmpty) return signal;
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    return signal.map((s) => s - mean).toList();
  }

  /// Normalize signal to range [-1, 1]
  static List<double> normalize(List<double> signal) {
    if (signal.isEmpty) return signal;
    final maxAbs = signal.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    if (maxAbs == 0) return signal;
    return signal.map((s) => s / maxAbs).toList();
  }

  /// Apply z-score normalization
  static List<double> zScoreNormalize(List<double> signal) {
    if (signal.length < 2) return signal;
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final variance =
        signal.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) /
            signal.length;
    final std = sqrt(variance);
    if (std == 0) return signal.map((_) => 0.0).toList();
    return signal.map((s) => (s - mean) / std).toList();
  }
}

/// Detrending filter to remove slow baseline wander
class DetrendingFilter {
  final int windowSize;

  DetrendingFilter({this.windowSize = 30});

  List<double> detrend(List<double> signal) {
    if (signal.length < windowSize) return signal;

    final detrended = <double>[];
    for (int i = 0; i < signal.length; i++) {
      // Calculate local baseline using moving window
      final start = (i - windowSize ~/ 2).clamp(0, signal.length - 1);
      final end = (i + windowSize ~/ 2).clamp(0, signal.length);
      final window = signal.sublist(start, end);
      final baseline = window.reduce((a, b) => a + b) / window.length;
      detrended.add(signal[i] - baseline);
    }
    return detrended;
  }
}
