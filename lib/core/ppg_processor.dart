import 'package:camera/camera.dart';
import 'filters.dart';
import 'peak_detector.dart';

/// PPG measurement state
enum PPGState {
  idle,
  calibrating,
  measuring,
  completed,
  error,
}

/// PPG signal quality indicator
enum SignalQuality {
  poor,
  fair,
  good,
  excellent,
}

/// Result of PPG analysis
class PPGResult {
  final double heartRate;
  final double confidence;
  final SignalQuality signalQuality;
  final HRVMetrics? hrvMetrics;
  final List<double> ppgWaveform;
  final DateTime timestamp;
  final int measurementDurationSeconds;

  PPGResult({
    required this.heartRate,
    required this.confidence,
    required this.signalQuality,
    this.hrvMetrics,
    required this.ppgWaveform,
    required this.timestamp,
    required this.measurementDurationSeconds,
  });

  bool get isValid => confidence > 0.6 && heartRate >= 40 && heartRate <= 200;

  @override
  String toString() {
    return 'PPGResult(HR: ${heartRate.toStringAsFixed(0)} BPM, '
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
        'quality: $signalQuality)';
  }
}

/// Main PPG signal processor
class PPGProcessor {
  // Configuration
  final double sampleRate;
  final int measurementDuration; // seconds
  final int calibrationDuration; // seconds

  // Signal buffers
  final List<double> _redChannel = [];
  final List<double> _greenChannel = [];
  final List<double> _rawSignal = [];
  final List<double> _filteredSignal = [];
  final List<DateTime> _timestamps = [];

  // Processing components
  late final BandpassFilter _bandpassFilter;
  late final MovingAverageFilter _smoothingFilter;
  late final DetrendingFilter _detrendingFilter;
  late final RealTimePeakDetector _peakDetector;
  late final ExponentialMovingAverage _bpmSmoother;

  // State
  PPGState _state = PPGState.idle;
  DateTime? _startTime;
  double _currentBPM = 0;
  double _currentConfidence = 0;
  SignalQuality _signalQuality = SignalQuality.poor;

  // Calibration
  double _baselineRed = 0;
  double _baselineGreen = 0;
  int _calibrationSamples = 0;

  PPGProcessor({
    this.sampleRate = 30.0,
    this.measurementDuration = 30,
    this.calibrationDuration = 3,
  }) {
    _bandpassFilter = BandpassFilter(
      lowCutoff: 0.5, // 30 BPM
      highCutoff: 4.0, // 240 BPM
      sampleRate: sampleRate,
    );
    _smoothingFilter = MovingAverageFilter(windowSize: 3);
    _detrendingFilter = DetrendingFilter(windowSize: 30);
    _peakDetector = RealTimePeakDetector(
      windowSize: (sampleRate * 5).toInt(), // 5 second window
      sampleRate: sampleRate,
    );
    _bpmSmoother = ExponentialMovingAverage(alpha: 0.2);
  }

  // Getters
  PPGState get state => _state;
  double get currentBPM => _currentBPM;
  double get confidence => _currentConfidence;
  SignalQuality get signalQuality => _signalQuality;
  List<double> get waveform => List.unmodifiable(_filteredSignal);
  List<double> get rawWaveform => List.unmodifiable(_rawSignal);

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  int get remainingSeconds {
    final elapsed = elapsedSeconds;
    if (_state == PPGState.calibrating) {
      return (calibrationDuration - elapsed).clamp(0, calibrationDuration);
    }
    return (measurementDuration - elapsed + calibrationDuration)
        .clamp(0, measurementDuration);
  }

  double get progress {
    if (_state == PPGState.idle) return 0;
    if (_state == PPGState.completed) return 1;
    return elapsedSeconds / (calibrationDuration + measurementDuration);
  }

  /// Start the measurement process
  void start() {
    reset();
    _state = PPGState.calibrating;
    _startTime = DateTime.now();
  }

  /// Stop measurement
  void stop() {
    _state = PPGState.idle;
  }

  /// Reset processor state
  void reset() {
    _redChannel.clear();
    _greenChannel.clear();
    _rawSignal.clear();
    _filteredSignal.clear();
    _timestamps.clear();
    _bandpassFilter.reset();
    _smoothingFilter.reset();
    _peakDetector.reset();
    _bpmSmoother.reset();
    _state = PPGState.idle;
    _startTime = null;
    _currentBPM = 0;
    _currentConfidence = 0;
    _signalQuality = SignalQuality.poor;
    _baselineRed = 0;
    _baselineGreen = 0;
    _calibrationSamples = 0;
  }

  /// Process a camera frame and extract PPG signal
  void processFrame(CameraImage image) {
    if (_state == PPGState.idle || _state == PPGState.completed) return;

    try {
      // Extract color channels from frame
      final (red, green) = _extractChannels(image);

      if (_state == PPGState.calibrating) {
        _handleCalibration(red, green);
      } else if (_state == PPGState.measuring) {
        _handleMeasurement(red, green);
      }
    } catch (e) {
      _state = PPGState.error;
    }
  }

  /// Extract red and green channel averages from camera image
  (double, double) _extractChannels(CameraImage image) {
    double redSum = 0;
    double greenSum = 0;
    int pixelCount = 0;

    // Handle different image formats
    if (image.format.group == ImageFormatGroup.yuv420) {
      // YUV format - extract from Y plane (luminance) and UV for color
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      // Sample center region of image
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final sampleRadius = 50;

      for (int y = centerY - sampleRadius; y < centerY + sampleRadius; y++) {
        for (int x = centerX - sampleRadius; x < centerX + sampleRadius; x++) {
          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final yIndex = y * yRowStride + x;
            final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

            if (yIndex < yPlane.length && uvIndex < uPlane.length) {
              final yVal = yPlane[yIndex];
              final uVal = uPlane[uvIndex] - 128;
              final vVal = vPlane[uvIndex] - 128;

              // Convert YUV to RGB
              final r = (yVal + 1.402 * vVal).clamp(0, 255);
              final g = (yVal - 0.344 * uVal - 0.714 * vVal).clamp(0, 255);

              redSum += r;
              greenSum += g;
              pixelCount++;
            }
          }
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      // BGRA format (iOS)
      final bytes = image.planes[0].bytes;
      final bytesPerRow = image.planes[0].bytesPerRow;

      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final sampleRadius = 50;

      for (int y = centerY - sampleRadius; y < centerY + sampleRadius; y++) {
        for (int x = centerX - sampleRadius; x < centerX + sampleRadius; x++) {
          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final index = y * bytesPerRow + x * 4;
            if (index + 2 < bytes.length) {
              redSum += bytes[index + 2]; // R in BGRA
              greenSum += bytes[index + 1]; // G in BGRA
              pixelCount++;
            }
          }
        }
      }
    }

    if (pixelCount == 0) {
      return (0.0, 0.0);
    }

    return (redSum / pixelCount, greenSum / pixelCount);
  }

  void _handleCalibration(double red, double green) {
    _baselineRed += red;
    _baselineGreen += green;
    _calibrationSamples++;

    // Check if finger is covering the camera
    if (red < 100) {
      // Too dark - finger not on camera
      _signalQuality = SignalQuality.poor;
      return;
    }

    final elapsed = elapsedSeconds;
    if (elapsed >= calibrationDuration && _calibrationSamples > 0) {
      _baselineRed /= _calibrationSamples;
      _baselineGreen /= _calibrationSamples;
      _state = PPGState.measuring;
    }
  }

  void _handleMeasurement(double red, double green) {
    _timestamps.add(DateTime.now());

    // Normalize against baseline
    final normalizedRed = (red - _baselineRed) / _baselineRed;
    final normalizedGreen = (green - _baselineGreen) / _baselineGreen;

    // Store raw values
    _redChannel.add(normalizedRed);
    _greenChannel.add(normalizedGreen);

    // PPG signal is typically derived from red channel (for reflective mode)
    // or the ratio/difference for better noise rejection
    final ppgValue = -normalizedRed; // Inverted - blood absorption
    _rawSignal.add(ppgValue);

    // Apply filtering
    final smoothed = _smoothingFilter.filter(ppgValue);
    final filtered = _bandpassFilter.filter(smoothed);
    _filteredSignal.add(filtered);

    // Update signal quality based on red channel intensity
    _updateSignalQuality(red);

    // Detect peaks and calculate heart rate
    final bpm = _peakDetector.addSample(filtered);
    if (bpm != null) {
      _currentBPM = _bpmSmoother.filter(bpm);
      _currentConfidence = _peakDetector.confidence;
    }

    // Check if measurement is complete
    final totalDuration = calibrationDuration + measurementDuration;
    if (elapsedSeconds >= totalDuration) {
      _state = PPGState.completed;
    }
  }

  void _updateSignalQuality(double redIntensity) {
    // Quality based on red channel intensity
    // Good coverage = high red value with flash on
    if (redIntensity > 200) {
      _signalQuality = SignalQuality.excellent;
    } else if (redIntensity > 150) {
      _signalQuality = SignalQuality.good;
    } else if (redIntensity > 100) {
      _signalQuality = SignalQuality.fair;
    } else {
      _signalQuality = SignalQuality.poor;
    }
  }

  /// Get final measurement result
  PPGResult? getResult() {
    if (_state != PPGState.completed || _filteredSignal.isEmpty) {
      return null;
    }

    // Final peak detection on full signal
    final detector = PeakDetector(sampleRate: sampleRate);

    // Apply detrending for final analysis
    final detrended = _detrendingFilter.detrend(_filteredSignal);
    final normalized = SignalNormalizer.normalize(detrended);

    final peakResult = detector.detectPeaks(normalized);

    if (peakResult.averageBPM == null) {
      return null;
    }

    // Calculate HRV if enough peaks
    final hrv = peakResult.intervals.length >= 5
        ? detector.calculateHRV(peakResult.intervals)
        : null;

    return PPGResult(
      heartRate: peakResult.averageBPM!,
      confidence: peakResult.confidence ?? 0,
      signalQuality: _signalQuality,
      hrvMetrics: hrv,
      ppgWaveform: normalized,
      timestamp: DateTime.now(),
      measurementDurationSeconds: measurementDuration,
    );
  }

  /// Check if finger is properly placed on camera
  bool isFingerDetected(double redIntensity) {
    // With flash on and finger covering camera, red channel should be bright
    return redIntensity > 80;
  }
}
