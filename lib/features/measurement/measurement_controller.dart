import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../../core/ppg_processor.dart';
import '../../services/camera_service.dart';
import '../../services/health_data_service.dart';

/// Controller for the measurement screen
class MeasurementController extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final PPGProcessor _ppgProcessor = PPGProcessor();
  final HealthDataService _healthService = HealthDataService();

  // State
  bool _isInitialized = false;
  bool _isMeasuring = false;
  String? _errorMessage;
  PPGResult? _result;

  // Getters
  CameraService get cameraService => _cameraService;
  PPGProcessor get ppgProcessor => _ppgProcessor;
  HealthDataService get healthService => _healthService;

  bool get isInitialized => _isInitialized;
  bool get isMeasuring => _isMeasuring;
  String? get errorMessage => _errorMessage;
  PPGResult? get result => _result;

  CameraController? get cameraController => _cameraService.controller;
  PPGState get measurementState => _ppgProcessor.state;
  double get currentBPM => _ppgProcessor.currentBPM;
  double get confidence => _ppgProcessor.confidence;
  SignalQuality get signalQuality => _ppgProcessor.signalQuality;
  double get progress => _ppgProcessor.progress;
  int get remainingSeconds => _ppgProcessor.remainingSeconds;
  List<double> get waveform => _ppgProcessor.waveform;

  /// Initialize camera and prepare for measurement
  Future<bool> initialize() async {
    try {
      _errorMessage = null;
      notifyListeners();

      // Initialize camera
      final success = await _cameraService.initialize();
      if (!success) {
        _errorMessage = _cameraService.errorMessage;
        notifyListeners();
        return false;
      }

      // Start preview with flash
      await _cameraService.startPreview();
      await _cameraService.lockExposureAndFocus();

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Initialization failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start heart rate measurement
  Future<void> startMeasurement() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    _isMeasuring = true;
    _result = null;
    _errorMessage = null;
    notifyListeners();

    // Start PPG processor
    _ppgProcessor.start();

    // Start camera image stream
    await _cameraService.startImageStream(_onFrame);

    // Set up periodic UI updates
    _startUIUpdateTimer();
  }

  /// Handle each camera frame
  void _onFrame(CameraImage image) {
    if (!_isMeasuring) return;

    // Process frame for PPG
    _ppgProcessor.processFrame(image);

    // Check if measurement is complete
    if (_ppgProcessor.state == PPGState.completed) {
      _completeMeasurement();
    }
  }

  /// Timer for UI updates during measurement
  void _startUIUpdateTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_isMeasuring) return false;

      notifyListeners();

      // Check for errors
      if (_ppgProcessor.state == PPGState.error) {
        _errorMessage = 'Signal error - please try again';
        _isMeasuring = false;
        notifyListeners();
        return false;
      }

      return _isMeasuring;
    });
  }

  /// Complete the measurement and get results
  Future<void> _completeMeasurement() async {
    _isMeasuring = false;

    // Stop camera stream
    await _cameraService.stopImageStream();

    // Get results
    _result = _ppgProcessor.getResult();

    if (_result == null) {
      _errorMessage = 'Could not calculate heart rate. Please try again.';
    } else if (!_result!.isValid) {
      _errorMessage = 'Measurement quality too low. Please try again.';
    } else {
      // Try to save to health platform
      await _saveToHealth();
    }

    notifyListeners();
  }

  /// Save result to HealthKit/Google Fit
  Future<void> _saveToHealth() async {
    if (_result == null || !_result!.isValid) return;

    try {
      final saved = await _healthService.saveHeartRate(_result!);
      if (saved) {
        debugPrint('Heart rate saved to health platform');
      }
    } catch (e) {
      debugPrint('Could not save to health platform: $e');
    }
  }

  /// Stop measurement early
  Future<void> stopMeasurement() async {
    _isMeasuring = false;
    _ppgProcessor.stop();
    await _cameraService.stopImageStream();
    notifyListeners();
  }

  /// Reset for a new measurement
  Future<void> reset() async {
    await stopMeasurement();
    _ppgProcessor.reset();
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Get signal quality color
  int get signalQualityColor {
    switch (signalQuality) {
      case SignalQuality.excellent:
        return 0xFF4CAF50; // Green
      case SignalQuality.good:
        return 0xFF8BC34A; // Light green
      case SignalQuality.fair:
        return 0xFFFFC107; // Amber
      case SignalQuality.poor:
        return 0xFFF44336; // Red
    }
  }

  /// Get signal quality text
  String get signalQualityText {
    switch (signalQuality) {
      case SignalQuality.excellent:
        return 'Excellent signal';
      case SignalQuality.good:
        return 'Good signal';
      case SignalQuality.fair:
        return 'Fair signal - hold steady';
      case SignalQuality.poor:
        return 'Poor signal - cover camera with finger';
    }
  }

  /// Get state description
  String get stateDescription {
    switch (measurementState) {
      case PPGState.idle:
        return 'Ready to measure';
      case PPGState.calibrating:
        return 'Calibrating...';
      case PPGState.measuring:
        return 'Measuring heart rate...';
      case PPGState.completed:
        return 'Measurement complete';
      case PPGState.error:
        return 'Error - please try again';
    }
  }

  @override
  void dispose() {
    stopMeasurement();
    _cameraService.dispose();
    super.dispose();
  }
}
