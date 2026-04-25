import 'dart:typed_data';

import 'manufacturer_specific_data.dart';
import 'uuid.dart';

/// Android BLE advertising mode.
enum AndroidAdvertiseMode { lowPower, balanced, lowLatency }

/// Android BLE TX power level.
enum AndroidTXPowerLevel { ultraLow, low, medium, high }

/// Android BLE PHY used by extended advertising.
enum AndroidPhy { le1m, le2m, leCoded }

/// Android-specific advertising settings mapped to AdvertiseSettings.Builder.
final class AndroidAdvertiseSettings {
  final AndroidAdvertiseMode? mode;
  final bool? connectable;
  final int? timeout;
  final AndroidTXPowerLevel? txPowerLevel;
  final bool? legacy;
  final bool? anonymous;
  final bool? includeTxPower;
  final AndroidPhy? primaryPhy;
  final AndroidPhy? secondaryPhy;

  const AndroidAdvertiseSettings({
    this.mode,
    this.connectable,
    this.timeout,
    this.txPowerLevel,
    this.legacy,
    this.anonymous,
    this.includeTxPower,
    this.primaryPhy,
    this.secondaryPhy,
  });
}

/// Android-specific advertise/scan-response payload controls.
final class AndroidAdvertiseData {
  final bool? includeDeviceName;
  final bool? includeTxPowerLevel;
  final List<UUID> serviceUUIDs;
  final Map<UUID, Uint8List> serviceData;
  final List<ManufacturerSpecificData> manufacturerSpecificData;

  const AndroidAdvertiseData({
    this.includeDeviceName,
    this.includeTxPowerLevel,
    this.serviceUUIDs = const [],
    this.serviceData = const {},
    this.manufacturerSpecificData = const [],
  });
}

/// Android-specific options for [Advertisement].
///
/// These options are only used on Android and ignored on other platforms.
final class AndroidAdvertisingOptions {
  final AndroidAdvertiseSettings? settings;
  final AndroidAdvertiseData? advertiseData;
  final AndroidAdvertiseData? scanResponseData;

  const AndroidAdvertisingOptions({
    this.settings,
    this.advertiseData,
    this.scanResponseData,
  });
}

/// The advertisement of the peripheral.
abstract interface class Advertisement {
  /// The name of the peripheral.
  ///
  /// This field is available on Android, iOS and macOS, throws [UnsupportedError]
  /// on other platforms.
  String? get name;

  /// The GATT service uuids of the peripheral.
  List<UUID> get serviceUUIDs;

  /// The GATT service data of the peripheral.
  ///
  /// This field is available on Android and Windows, throws [UnsupportedError]
  /// on other platforms.
  Map<UUID, Uint8List> get serviceData;

  /// The manufacturer specific data of the peripheral.
  ///
  /// This field is available on Android and Windows, throws [UnsupportedError]
  /// on other platforms.
  List<ManufacturerSpecificData> get manufacturerSpecificData;

  /// Android-specific advertising controls.
  ///
  /// This field is available on Android and ignored on other platforms.
  AndroidAdvertisingOptions? get androidOptions;

  /// Constructs an [Advertisement].
  factory Advertisement({
    String? name,
    List<UUID> serviceUUIDs = const [],
    Map<UUID, Uint8List> serviceData = const {},
    List<ManufacturerSpecificData> manufacturerSpecificData = const [],
    AndroidAdvertisingOptions? androidOptions,
  }) => AdvertisementImpl(
    name: name,
    serviceUUIDs: serviceUUIDs,
    serviceData: serviceData,
    manufacturerSpecificData: manufacturerSpecificData,
    androidOptions: androidOptions,
  );
}

final class AdvertisementImpl implements Advertisement {
  @override
  final String? name;
  @override
  final List<UUID> serviceUUIDs;
  @override
  final Map<UUID, Uint8List> serviceData;
  @override
  final List<ManufacturerSpecificData> manufacturerSpecificData;
  @override
  final AndroidAdvertisingOptions? androidOptions;

  AdvertisementImpl({
    required this.name,
    required this.serviceUUIDs,
    required this.serviceData,
    required this.manufacturerSpecificData,
    required this.androidOptions,
  });
}
