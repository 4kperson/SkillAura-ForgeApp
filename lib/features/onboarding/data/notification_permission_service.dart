import 'package:permission_handler/permission_handler.dart';

abstract interface class NotificationPermissionService {
  Future<bool> request();
}

class DeviceNotificationPermissionService
    implements NotificationPermissionService {
  const DeviceNotificationPermissionService();

  @override
  Future<bool> request() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
