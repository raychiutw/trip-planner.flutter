/// 通知系統權限的 app-owned boundary。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 作業系統回報的通知權限狀態。
enum NotificationPermissionStatus { notDetermined, granted, denied }

/// 隔離 iOS／Android 通知權限 API，讓設定頁只處理產品流程。
abstract interface class NotificationPermissionService {
  /// 讀取目前通知權限，不顯示系統提示。
  Future<NotificationPermissionStatus> getStatus();

  /// 顯示作業系統通知權限提示。
  Future<NotificationPermissionStatus> request();

  /// 開啟目前 App 的系統通知設定。
  Future<void> openSettings();
}

/// 通知權限服務 provider；widget test 可覆寫為可控制的 fake。
final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>(
      (ref) => const MethodChannelNotificationPermissionService(),
    );

/// 透過原生 bridge 存取通知權限。
class MethodChannelNotificationPermissionService
    implements NotificationPermissionService {
  const MethodChannelNotificationPermissionService();

  static const _channel = MethodChannel('tripline/notification-permission');

  @override
  Future<NotificationPermissionStatus> getStatus() => _invokeStatus('status');

  @override
  Future<NotificationPermissionStatus> request() => _invokeStatus('request');

  @override
  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      // Desktop 不需要行動平台的 runtime notification permission。
    }
  }

  Future<NotificationPermissionStatus> _invokeStatus(String method) async {
    if (kIsWeb) return NotificationPermissionStatus.granted;
    try {
      final raw = await _channel.invokeMethod<String>(method);
      return switch (raw) {
        'notDetermined' => NotificationPermissionStatus.notDetermined,
        'granted' => NotificationPermissionStatus.granted,
        'denied' => NotificationPermissionStatus.denied,
        _ => NotificationPermissionStatus.denied,
      };
    } on MissingPluginException {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS => NotificationPermissionStatus.denied,
        _ => NotificationPermissionStatus.granted,
      };
    }
  }
}
