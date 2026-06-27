// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class DeviceRegistrationService {
  final ApiClient _api;
  final SecureStorageService _storage;
  Timer? _heartbeatTimer;

  DeviceRegistrationService({
    required ApiClient api,
    required SecureStorageService storage,
  })  : _api = api,
        _storage = storage;

  Future<void> start() async {
    await _register();
    _heartbeatTimer ??= Timer.periodic(
      AppConstants.deviceHeartbeatInterval,
      (_) => _register(),
    );
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _register() async {
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      await _api.registerDevice(
        deviceId: deviceId,
        name: _deviceName(),
        platform: _platform(),
        appVersion: AppConstants.appVersion,
      );
    } catch (e) {
      debugPrint('[Device] Registration failed: $e');
    }
  }

  static String _platform() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  static String _deviceName() {
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'Windows PC';
    return Platform.operatingSystemVersion;
  }
}
