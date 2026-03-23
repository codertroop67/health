import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../core/ppg_processor.dart';

/// Service for integrating with HealthKit (iOS) and Google Fit (Android)
class HealthDataService {
  final Health _health = Health();
  bool _isAuthorized = false;

  bool get isAuthorized => _isAuthorized;

  /// Data types we want to read/write
  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
  ];

  /// Request authorization to access health data
  Future<bool> requestAuthorization() async {
    try {
      // Configure health plugin
      await _health.configure();

      // Request permissions for reading and writing
      final permissions = _types.map((type) => HealthDataAccess.READ_WRITE).toList();

      _isAuthorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );

      return _isAuthorized;
    } catch (e) {
      debugPrint('Health authorization error: $e');
      return false;
    }
  }

  /// Check if we have health data permissions
  Future<bool> hasPermissions() async {
    try {
      final result = await _health.hasPermissions(_types);
      _isAuthorized = result ?? false;
      return _isAuthorized;
    } catch (e) {
      debugPrint('Health permission check error: $e');
      return false;
    }
  }

  /// Save heart rate measurement to health platform
  Future<bool> saveHeartRate(PPGResult result) async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return false;
    }

    try {
      final now = DateTime.now();
      final startTime = now.subtract(Duration(seconds: result.measurementDurationSeconds));

      // Save heart rate
      final success = await _health.writeHealthData(
        value: result.heartRate,
        type: HealthDataType.HEART_RATE,
        startTime: startTime,
        endTime: now,
        unit: HealthDataUnit.BEATS_PER_MINUTE,
      );

      // Save HRV if available
      if (result.hrvMetrics != null && success) {
        await _health.writeHealthData(
          value: result.hrvMetrics!.sdnn,
          type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          startTime: startTime,
          endTime: now,
          unit: HealthDataUnit.MILLISECOND,
        );
      }

      return success;
    } catch (e) {
      debugPrint('Health write error: $e');
      return false;
    }
  }

  /// Get recent heart rate readings
  Future<List<HealthDataPoint>> getRecentHeartRates({
    int days = 7,
  }) async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return [];
    }

    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startDate,
        endTime: now,
      );

      // Remove duplicates
      return _health.removeDuplicates(data);
    } catch (e) {
      debugPrint('Health read error: $e');
      return [];
    }
  }

  /// Get average heart rate for a time period
  Future<double?> getAverageHeartRate({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return null;
    }

    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );

      if (data.isEmpty) return null;

      final values = data
          .where((d) => d.value is NumericHealthValue)
          .map((d) => (d.value as NumericHealthValue).numericValue.toDouble())
          .toList();

      if (values.isEmpty) return null;

      return values.reduce((a, b) => a + b) / values.length;
    } catch (e) {
      debugPrint('Health average error: $e');
      return null;
    }
  }

  /// Get resting heart rate
  Future<double?> getRestingHeartRate() async {
    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) return null;
    }

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: startDate,
        endTime: now,
      );

      if (data.isEmpty) return null;

      // Get most recent resting heart rate
      data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final latest = data.first;

      if (latest.value is NumericHealthValue) {
        return (latest.value as NumericHealthValue).numericValue.toDouble();
      }

      return null;
    } catch (e) {
      debugPrint('Health resting HR error: $e');
      return null;
    }
  }

  /// Get heart rate statistics
  Future<HeartRateStats?> getHeartRateStats({int days = 7}) async {
    final data = await getRecentHeartRates(days: days);
    if (data.isEmpty) return null;

    final values = data
        .where((d) => d.value is NumericHealthValue)
        .map((d) => (d.value as NumericHealthValue).numericValue.toDouble())
        .toList();

    if (values.isEmpty) return null;

    values.sort();
    final min = values.first;
    final max = values.last;
    final avg = values.reduce((a, b) => a + b) / values.length;

    return HeartRateStats(
      minimum: min,
      maximum: max,
      average: avg,
      count: values.length,
      periodDays: days,
    );
  }
}

/// Heart rate statistics
class HeartRateStats {
  final double minimum;
  final double maximum;
  final double average;
  final int count;
  final int periodDays;

  HeartRateStats({
    required this.minimum,
    required this.maximum,
    required this.average,
    required this.count,
    required this.periodDays,
  });

  @override
  String toString() {
    return 'HeartRateStats(min: ${minimum.toStringAsFixed(0)}, '
        'max: ${maximum.toStringAsFixed(0)}, '
        'avg: ${average.toStringAsFixed(0)}, '
        'count: $count, '
        'days: $periodDays)';
  }
}
