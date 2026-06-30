class AppConstants {
  AppConstants._();

  static const String appName = 'Snapit';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrlDev = 'http://localhost:5559/snap';
  static const String apiBaseUrlProd = 'https://api.snapit.ink/snap';

  // Website
  static const String webBaseUrlDev = 'http://localhost:3000';
  static const String webBaseUrlProd = 'https://snapit.ink';

  // Encryption — must match the web client derivation
  static const int pbkdf2Iterations = 600000;
  static const String keySaltSuffix = ':snap-key-v1';

  // Sync
  static const Duration syncInterval = Duration(seconds: 30);
  static const Duration planPollInterval = Duration(minutes: 5);
  static const int syncBatchSize = 100;
  static const int syncMaxItems = 500;

  // Clipboard polling
  static const Duration clipboardPollInterval = Duration(milliseconds: 500);

  // Device heartbeat — re-registers this device to update last_seen_at
  static const Duration deviceHeartbeatInterval = Duration(minutes: 30);

  // Secure storage keys
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserId = 'user_id';
  static const String kUserEmail = 'user_email';
  static const String kEncryptionKey = 'enc_key';

  // Shared prefs keys
  static const String kLastSyncCursor = 'last_sync_cursor';
  static const String kSyncEnabled = 'sync_enabled';
  static const String kLaunchAtLogin = 'launch_at_login';
}
