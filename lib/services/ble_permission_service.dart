import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class BlePermissionSnapshot {
  const BlePermissionSnapshot({
    required this.bluetoothScanGranted,
    required this.bluetoothConnectGranted,
    required this.locationGranted,
    required this.notificationGranted,
  });

  const BlePermissionSnapshot.unknown()
    : bluetoothScanGranted = false,
      bluetoothConnectGranted = false,
      locationGranted = false,
      notificationGranted = false;

  final bool bluetoothScanGranted;
  final bool bluetoothConnectGranted;
  final bool locationGranted;
  final bool notificationGranted;

  bool get canDiscoverDevices {
    return bluetoothScanGranted && bluetoothConnectGranted && locationGranted;
  }
}

abstract class BlePermissionService {
  Future<BlePermissionSnapshot> getSnapshot();

  Future<BlePermissionSnapshot> requestRequiredPermissions();
}

class AndroidBlePermissionService implements BlePermissionService {
  AndroidBlePermissionService({int? androidSdkInt})
    : _androidSdkInt = androidSdkInt;

  final int? _androidSdkInt;

  @override
  Future<BlePermissionSnapshot> getSnapshot() async {
    if (!Platform.isAndroid) {
      return const BlePermissionSnapshot(
        bluetoothScanGranted: true,
        bluetoothConnectGranted: true,
        locationGranted: true,
        notificationGranted: true,
      );
    }

    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    final notificationStatus = await Permission.notification.status;
    final requiresLocation = _requiresLocationForBleScan;

    var locationGranted = true;
    if (requiresLocation) {
      final locationWhenInUseStatus = await Permission.locationWhenInUse.status;
      final locationStatus = await Permission.location.status;
      locationGranted =
          locationWhenInUseStatus.isGranted || locationStatus.isGranted;
    }

    return BlePermissionSnapshot(
      bluetoothScanGranted: scanStatus.isGranted,
      bluetoothConnectGranted: connectStatus.isGranted,
      locationGranted: locationGranted,
      notificationGranted:
          notificationStatus.isGranted || notificationStatus.isProvisional,
    );
  }

  @override
  Future<BlePermissionSnapshot> requestRequiredPermissions() async {
    if (!Platform.isAndroid) {
      return getSnapshot();
    }

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ];
    if (_requiresLocationForBleScan) {
      permissions.add(Permission.locationWhenInUse);
    }

    await permissions.request();

    return getSnapshot();
  }

  bool get _requiresLocationForBleScan => _resolvedAndroidSdkInt <= 30;

  int get _resolvedAndroidSdkInt =>
      _androidSdkInt ??
      _parseAndroidSdkInt(Platform.operatingSystemVersion) ??
      30;

  static int? _parseAndroidSdkInt(String rawVersion) {
    final match = RegExp(
      r'SDK\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(rawVersion);
    return int.tryParse(match?.group(1) ?? '');
  }
}
