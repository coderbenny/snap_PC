// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

/// Maintains a long-lived Server-Sent Events connection to GET /events.
///
/// On `plan_changed` events the [onPlanChanged] callback fires with the new
/// plan string so callers can react immediately (no polling lag).
/// Reconnects automatically with back-off on any disconnect or error.
class EventStreamService {
  final SecureStorageService _storage;

  void Function(String newPlan)? onPlanChanged;
  void Function(Map<String, dynamic> payload)? onTransferIncoming;
  void Function(String sessionId)? onTransferCancelled;

  EventStreamService({required SecureStorageService storage}) : _storage = storage;

  StreamSubscription<String>? _lineSub;
  Timer? _reconnectTimer;
  bool _stopped = false;
  String? _myDeviceId;

  // SSE parser state
  String? _currentEvent;
  String? _currentData;

  Future<void> start() async {
    _stopped = false;
    _myDeviceId = await _storage.getOrCreateDeviceId();
    await _connect();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _lineSub?.cancel();
    _lineSub = null;
  }

  Future<void> _connect() async {
    if (_stopped) return;

    final token = await _storage.getAccessToken();
    if (token == null) return;

    final baseUrl =
        kDebugMode ? AppConstants.apiBaseUrlDev : AppConstants.apiBaseUrlProd;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: Duration.zero, // stream stays open indefinitely
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ));

      final response = await dio.get<ResponseBody>('/events');
      final body = response.data;
      if (body == null) {
        _scheduleReconnect(5);
        return;
      }

      _currentEvent = null;
      _currentData = null;

      _lineSub = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onDone: () => _scheduleReconnect(3),
            onError: (dynamic e) {
              debugPrint('[SSE] Stream error: $e');
              _scheduleReconnect(5);
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('[SSE] Connection failed: $e');
      _scheduleReconnect(10);
    }
  }

  void _handleLine(String line) {
    if (line.startsWith('event:')) {
      _currentEvent = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _currentData = line.substring(5).trim();
    } else if (line.isEmpty && _currentEvent != null) {
      _dispatchEvent(_currentEvent!, _currentData ?? '');
      _currentEvent = null;
      _currentData = null;
    }
    // Lines starting with ':' are comments / keepalives — ignore
  }

  void _dispatchEvent(String event, String data) {
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      switch (event) {
        case 'plan_changed':
          final plan = map['plan'] as String?;
          if (plan != null) onPlanChanged?.call(plan);
        case 'transfer_incoming':
          // Ignore events not targeted at this device — the server broadcasts
          // to all SSE connections for the user, including the sender's own.
          final targetId = map['target_device_id'] as String?;
          if (targetId != null && _myDeviceId != null && targetId != _myDeviceId) {
            break;
          }
          onTransferIncoming?.call(map);
        case 'transfer_cancelled':
          final sessionId = map['session_id'] as String?;
          if (sessionId != null) onTransferCancelled?.call(sessionId);
      }
    } catch (e) {
      debugPrint('[SSE] Failed to parse $event payload: $e');
    }
  }

  void _scheduleReconnect(int seconds) {
    if (_stopped) return;
    _lineSub?.cancel();
    _lineSub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(Duration(seconds: seconds), _connect);
  }
}
