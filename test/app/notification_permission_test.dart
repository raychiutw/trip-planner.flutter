import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/notification_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tripline/notification-permission');
  const service = MethodChannelNotificationPermissionService();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('bridge 回傳未知或 null 狀態時採 fail-closed denied', () async {
    for (final response in <String?>['unexpected', null]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => response);

      expect(await service.getStatus(), NotificationPermissionStatus.denied);
    }
  });
}
