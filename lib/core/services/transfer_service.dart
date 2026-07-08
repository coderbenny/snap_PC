import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Handles the WebSocket-based file relay on the client side.
///
/// Flow (sender):
///   startSend(file, targetDeviceId) → opens WS, streams 64 KB chunks, closes.
///
/// Flow (receiver):
///   startReceive(sessionId, fileName, fileSize) → opens WS, writes chunks
///   to the Downloads directory, returns the saved [File].
class TransferService {
  final ApiClient _api;
  final SecureStorageService _storage;

  TransferService({required this._api, required this._storage});

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Starts a transfer to [targetDeviceId] and streams [file] to the server.
  ///
  /// Returns the session ID that was created.
  /// [onProgress] receives values from 0.0 to 1.0.
  Future<String> startSend(
    XFile file,
    String targetDeviceId, {
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    final fileSize = await file.length();
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';

    final sessionId = await _api.startTransfer(
      fileName: file.name,
      fileSize: fileSize,
      mimeType: mimeType,
      targetDeviceId: targetDeviceId,
    );

    _sendChunks(
      sessionId: sessionId,
      file: file,
      fileSize: fileSize,
      onProgress: onProgress,
      onError: onError,
    );

    return sessionId;
  }

  Future<void> _sendChunks({
    required String sessionId,
    required XFile file,
    required int fileSize,
    void Function(double)? onProgress,
    void Function(String)? onError,
  }) async {
    final token = await _storage.getAccessToken();
    final String deviceId = await _storage.getOrCreateDeviceId();
    if (token == null) {
      onError?.call('Not authenticated');
      return;
    }

    final wsBase = kDebugMode ? AppConstants.wsBaseUrlDev : AppConstants.wsBaseUrlProd;
    final uri = Uri.parse(
      '$wsBase/transfer/$sessionId/send?token=$token&device_id=$deviceId',
    );

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(uri);

      final raf = await File(file.path).open();
      int bytesSent = 0;

      try {
        while (bytesSent < fileSize) {
          final remaining = fileSize - bytesSent;
          final chunkSize = remaining < AppConstants.transferChunkSize
              ? remaining
              : AppConstants.transferChunkSize;
          final chunk = Uint8List(chunkSize);
          await raf.readInto(chunk);
          channel.sink.add(chunk);
          bytesSent += chunkSize;
          onProgress?.call(bytesSent / fileSize);
        }
      } finally {
        await raf.close();
      }

      await channel.sink.close();
    } catch (e) {
      onError?.call(e.toString());
      try {
        await _api.cancelTransfer(sessionId);
      } catch (_) {}
    } finally {
      await channel?.sink.close();
    }
  }

  // ── Receive ───────────────────────────────────────────────────────────────

  /// Connects to the server and saves incoming bytes to the Downloads folder.
  ///
  /// Returns the saved [File] on success, or null on error.
  /// [onProgress] receives values from 0.0 to 1.0.
  Future<File?> startReceive(
    String sessionId,
    String fileName,
    int fileSize, {
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    final token = await _storage.getAccessToken();
    final String deviceId = await _storage.getOrCreateDeviceId();
    if (token == null) {
      onError?.call('Not authenticated');
      return null;
    }

    final wsBase = kDebugMode ? AppConstants.wsBaseUrlDev : AppConstants.wsBaseUrlProd;
    final uri = Uri.parse(
      '$wsBase/transfer/$sessionId/recv?token=$token&device_id=$deviceId',
    );

    final downloadsDir = await _resolveDownloadsDir();
    final destFile = _uniqueFile(downloadsDir, fileName);

    WebSocketChannel? channel;
    IOSink? sink;
    String? serverError;
    try {
      channel = WebSocketChannel.connect(uri);
      sink = destFile.openWrite();

      int bytesReceived = 0;

      await for (final message in channel.stream) {
        if (message is String) {
          try {
            final frame = jsonDecode(message) as Map<String, dynamic>;
            serverError = frame['error'] as String? ?? 'Transfer error from server';
          } catch (_) {
            serverError = 'Transfer error from server';
          }
          break;
        }
        final bytes = message is Uint8List
            ? message
            : Uint8List.fromList(message as List<int>);
        sink.add(bytes);
        bytesReceived += bytes.length;
        if (fileSize > 0) {
          onProgress?.call((bytesReceived / fileSize).clamp(0.0, 1.0));
        }
      }

      if (serverError != null) {
        onError?.call(serverError!);
        return null;
      }

      await sink.flush();
      return destFile;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    } finally {
      await sink?.close();
      if (serverError != null) {
        try { await destFile.delete(); } catch (_) {}
      }
      await channel?.sink.close();
    }
  }

  File _uniqueFile(Directory dir, String fileName) {
    var file = File('${dir.path}/$fileName');
    if (!file.existsSync()) return file;
    final dot = fileName.lastIndexOf('.');
    final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot >= 0 ? fileName.substring(dot) : '';
    var i = 1;
    while (true) {
      file = File('${dir.path}/$base ($i)$ext');
      if (!file.existsSync()) return file;
      i++;
    }
  }

  Future<Directory> _resolveDownloadsDir() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$home/Downloads');
      if (await dir.exists()) return dir;
    }
    return getApplicationDocumentsDirectory();
  }
}
