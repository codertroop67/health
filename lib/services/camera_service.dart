import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera service state
enum CameraState {
  uninitialized,
  initializing,
  ready,
  streaming,
  error,
  permissionDenied,
}

/// Manages camera lifecycle and image streaming for PPG capture
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraState _state = CameraState.uninitialized;
  String? _errorMessage;

  // Callbacks
  Function(CameraImage)? _onFrameCallback;
  Function(CameraState)? _onStateChange;

  // Getters
  CameraController? get controller => _controller;
  CameraState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _state == CameraState.streaming;

  /// Set callback for state changes
  void setStateCallback(Function(CameraState) callback) {
    _onStateChange = callback;
  }

  void _setState(CameraState newState) {
    _state = newState;
    _onStateChange?.call(newState);
  }

  /// Initialize the camera
  Future<bool> initialize() async {
    try {
      _setState(CameraState.initializing);

      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _errorMessage = 'Camera permission denied';
        _setState(CameraState.permissionDenied);
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _errorMessage = 'No cameras available';
        _setState(CameraState.error);
        return false;
      }

      // Use back camera for PPG (has flash)
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Initialize controller with low resolution for faster processing
      _controller = CameraController(
        backCamera,
        ResolutionPreset.low, // Low resolution for PPG - we only need color data
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // YUV for Android
      );

      await _controller!.initialize();
      _setState(CameraState.ready);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      _setState(CameraState.error);
      return false;
    }
  }

  /// Start camera preview with flash on
  Future<bool> startPreview() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return false;
    }

    try {
      // Turn on flash (torch mode) for consistent illumination
      await _controller!.setFlashMode(FlashMode.torch);
      _setState(CameraState.ready);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start preview: $e';
      return false;
    }
  }

  /// Start image stream for PPG processing
  Future<bool> startImageStream(Function(CameraImage) onFrame) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return false;
    }

    if (_state == CameraState.streaming) {
      return true; // Already streaming
    }

    try {
      _onFrameCallback = onFrame;
      await _controller!.startImageStream(_handleFrame);
      _setState(CameraState.streaming);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start image stream: $e';
      _setState(CameraState.error);
      return false;
    }
  }

  void _handleFrame(CameraImage image) {
    _onFrameCallback?.call(image);
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    if (_controller == null || _state != CameraState.streaming) {
      return;
    }

    try {
      await _controller!.stopImageStream();
      _setState(CameraState.ready);
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
  }

  /// Turn flash on
  Future<void> enableFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      await _controller!.setFlashMode(FlashMode.torch);
    } catch (e) {
      debugPrint('Error enabling flash: $e');
    }
  }

  /// Turn flash off
  Future<void> disableFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      await _controller!.setFlashMode(FlashMode.off);
    } catch (e) {
      debugPrint('Error disabling flash: $e');
    }
  }

  /// Set exposure offset for better PPG capture
  Future<void> setExposure(double offset) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final minOffset = await _controller!.getMinExposureOffset();
      final maxOffset = await _controller!.getMaxExposureOffset();
      final clampedOffset = offset.clamp(minOffset, maxOffset);
      await _controller!.setExposureOffset(clampedOffset);
    } catch (e) {
      debugPrint('Error setting exposure: $e');
    }
  }

  /// Lock exposure and focus for consistent readings
  Future<void> lockExposureAndFocus() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      await _controller!.setExposureMode(ExposureMode.locked);
      await _controller!.setFocusMode(FocusMode.locked);
    } catch (e) {
      debugPrint('Error locking exposure/focus: $e');
    }
  }

  /// Unlock exposure and focus
  Future<void> unlockExposureAndFocus() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('Error unlocking exposure/focus: $e');
    }
  }

  /// Get current frame rate
  double get frameRate {
    // Estimated based on resolution preset
    // Low resolution typically runs at 30fps
    return 30.0;
  }

  /// Dispose camera resources
  Future<void> dispose() async {
    try {
      if (_state == CameraState.streaming) {
        await stopImageStream();
      }
      await disableFlash();
      await _controller?.dispose();
      _controller = null;
      _setState(CameraState.uninitialized);
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }

  /// Check if flash is available
  Future<bool> isFlashAvailable() async {
    if (_cameras == null || _cameras!.isEmpty) {
      return false;
    }

    final backCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    // Back camera typically has flash
    return backCamera.lensDirection == CameraLensDirection.back;
  }
}
