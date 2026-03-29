import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/companion_models.dart';

abstract class BleCompanionService {
  Future<List<ScannedBand>> scanForBands({
    Duration timeout = const Duration(seconds: 6),
  });
}

class ReactiveBleCompanionService implements BleCompanionService {
  ReactiveBleCompanionService({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;

  static const _relevantNameMarkers = [
    'band',
    'xiaomi',
    'huami',
    'amazfit',
    'miband',
  ];

  @override
  Future<List<ScannedBand>> scanForBands({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final results = <String, ScannedBand>{};
    Object? scanError;
    StackTrace? scanStackTrace;

    final subscription = _ble
        .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
        .listen(
          (device) {
            if (!_looksRelevant(device)) {
              return;
            }

            results[device.id] = ScannedBand(
              name: device.name,
              id: device.id,
              rssi: device.rssi,
              connectable: device.connectable == Connectable.available,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            scanError = error;
            scanStackTrace = stackTrace;
          },
        );

    try {
      await Future<void>.delayed(timeout);
    } finally {
      await subscription.cancel();
    }

    if (scanError != null) {
      Error.throwWithStackTrace(scanError!, scanStackTrace!);
    }

    final bands = results.values.toList(growable: false);
    bands.sort((left, right) => right.rssi.compareTo(left.rssi));
    return bands;
  }

  bool _looksRelevant(DiscoveredDevice device) {
    final normalizedName = device.name.toLowerCase();
    if (normalizedName.isEmpty) {
      return false;
    }

    return _relevantNameMarkers.any(normalizedName.contains);
  }
}
