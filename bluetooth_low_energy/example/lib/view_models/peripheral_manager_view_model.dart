import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_low_energy_example/models.dart';
import 'package:clover/clover.dart';

class PeripheralManagerViewModel extends ViewModel {
  final PeripheralManager _manager;
  final List<Log> _logs;
  bool _advertising;

  late final StreamSubscription _stateChangedSubscription;
  late final StreamSubscription _characteristicReadRequestedSubscription;
  late final StreamSubscription _characteristicWriteRequestedSubscription;
  late final StreamSubscription _characteristicNotifyStateChangedSubscription;

  PeripheralManagerViewModel()
    : _manager = PeripheralManager(),
      _logs = [],
      _advertising = false {
    _stateChangedSubscription = _manager.stateChanged.listen((eventArgs) async {
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        await _manager.authorize();
      }
      notifyListeners();
    });
    _characteristicReadRequestedSubscription = _manager
        .characteristicReadRequested
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
          final log = Log(
            type: 'Characteristic read requested',
            message: '${central.uuid}, ${characteristic.uuid}, $offset',
          );
          _logs.add(log);
          notifyListeners();
          final elements = List.generate(100, (i) => i % 256);
          final value = Uint8List.fromList(elements);
          final trimmedValue = value.sublist(offset);
          await _manager.respondReadRequestWithValue(
            request,
            value: trimmedValue,
          );
        });
    _characteristicWriteRequestedSubscription = _manager
        .characteristicWriteRequested
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
          final value = request.value;
          final log = Log(
            type: 'Characteristic write requested',
            message:
                '[${value.length}] ${central.uuid}, ${characteristic.uuid}, $offset, $value',
          );
          _logs.add(log);
          notifyListeners();
          await _manager.respondWriteRequest(request);
        });
    _characteristicNotifyStateChangedSubscription = _manager
        .characteristicNotifyStateChanged
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final state = eventArgs.state;
          final log = Log(
            type: 'Characteristic notify state changed',
            message: '${central.uuid}, ${characteristic.uuid}, $state',
          );
          _logs.add(log);
          notifyListeners();
          // Write someting to the central when notify started.
          if (state) {
            final maximumNotifyLength = await _manager.getMaximumNotifyLength(
              central,
            );
            final elements = List.generate(maximumNotifyLength, (i) => i % 256);
            final value = Uint8List.fromList(elements);
            await _manager.notifyCharacteristic(
              central,
              characteristic,
              value: value,
            );
          }
        });
  }

  BluetoothLowEnergyState get state => _manager.state;
  bool get advertising => _advertising;
  List<Log> get logs => _logs;

  Future<void> showAppSettings() async {
    await _manager.showAppSettings();
  }

  Future<void> startAdvertising() async {
    if (_advertising) {
      return;
    }
    await _manager.removeAllServices();
    final elements = List.generate(100, (i) => i % 256);
    final value = Uint8List.fromList(elements);
    final service = GATTService(
      uuid: UUID.short(100),
      isPrimary: true,
      includedServices: [],
      characteristics: [
        GATTCharacteristic.immutable(
          uuid: UUID.short(200),
          value: value,
          descriptors: [],
        ),
        GATTCharacteristic.mutable(
          uuid: UUID.short(201),
          properties: [
            GATTCharacteristicProperty.read,
            GATTCharacteristicProperty.write,
            GATTCharacteristicProperty.writeWithoutResponse,
            GATTCharacteristicProperty.notify,
            GATTCharacteristicProperty.indicate,
          ],
          permissions: [
            GATTCharacteristicPermission.read,
            GATTCharacteristicPermission.write,
          ],
          descriptors: [],
        ),
      ],
    );
    await _manager.addService(service);
    final advertisement = Advertisement(
      name: Platform.isWindows ? null : 'BLE-12138',
      manufacturerSpecificData:
          Platform.isIOS || Platform.isMacOS
              ? []
              : [
                ManufacturerSpecificData(
                  id: 0x2e19,
                  data: Uint8List.fromList([0x01, 0x02, 0x03]),
                ),
              ],
    );
    await _manager.startAdvertising(advertisement);
    _advertising = true;
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) {
      return;
    }
    await _manager.stopAdvertising();
    _advertising = false;
    notifyListeners();
  }

  /// Example: Start advertising with advanced Android-specific settings.
  /// 
  /// This demonstrates all available Android BLE advertising controls:
  /// - Advertising mode (affects interval/frequency)
  /// - TX power level
  /// - Timeout duration
  /// - Extended advertising features (API 26+)
  /// - Custom advertise/scan response payloads
  Future<void> startAdvertisingWithAdvancedAndroidSettings() async {
    if (_advertising) {
      return;
    }
    await _manager.removeAllServices();
    final elements = List.generate(100, (i) => i % 256);
    final value = Uint8List.fromList(elements);
    final service = GATTService(
      uuid: UUID.short(100),
      isPrimary: true,
      includedServices: [],
      characteristics: [
        GATTCharacteristic.immutable(
          uuid: UUID.short(200),
          value: value,
          descriptors: [],
        ),
      ],
    );
    await _manager.addService(service);

    // Low-power advertising: interval ~1000ms, low power consumption
    // final lowPowerAdv = Advertisement(
    //   name: 'BLE-LowPower',
    //   serviceUUIDs: [UUID.short(100)],
    //   androidOptions: AndroidAdvertisingOptions(
    //     settings: AndroidAdvertiseSettings(
    //       mode: AndroidAdvertiseMode.lowPower,
    //       connectable: true,
    //       timeout: 30000, // 30 seconds
    //       txPowerLevel: AndroidTXPowerLevel.low,
    //     ),
    //   ),
    // );

    // Balanced mode: interval ~250ms, moderate power (good for general use)
    final balancedAdv = Advertisement(
      name: 'BLE-Balanced',
      serviceUUIDs: [UUID.short(100)],
      androidOptions: AndroidAdvertisingOptions(
        settings: AndroidAdvertiseSettings(
          mode: AndroidAdvertiseMode.balanced,
          connectable: true,
          timeout: 60000, // 60 seconds
          txPowerLevel: AndroidTXPowerLevel.medium,
        ),
      ),
    );

    // Low-latency advertising: interval ~100ms, high power (for proximity)
    // final lowLatencyAdv = Advertisement(
    //   name: 'BLE-HighPerf',
    //   serviceUUIDs: [UUID.short(100)],
    //   androidOptions: AndroidAdvertisingOptions(
    //     settings: AndroidAdvertiseSettings(
    //       mode: AndroidAdvertiseMode.lowLatency,
    //       connectable: true,
    //       timeout: 10000, // 10 seconds
    //       txPowerLevel: AndroidTXPowerLevel.high,
    //     ),
    //   ),
    // );

    // Extended advertising with PHY settings (Android 8.0+ / API 26+)
    // final extendedAdv = Advertisement(
    //   name: 'BLE-Extended',
    //   serviceUUIDs: [UUID.short(100)],
    //   manufacturerSpecificData: [
    //     ManufacturerSpecificData(
    //       id: 0x2e19,
    //       data: Uint8List.fromList([0x01, 0x02, 0x03]),
    //     ),
    //   ],
    //   androidOptions: AndroidAdvertisingOptions(
    //     settings: AndroidAdvertiseSettings(
    //       mode: AndroidAdvertiseMode.balanced,
    //       connectable: true,
    //       timeout: 45000, // 45 seconds
    //       txPowerLevel: AndroidTXPowerLevel.medium,
    //       // Extended advertising settings (API 26+)
    //       legacy: false, // Use extended advertising PDU
    //       anonymous: false,
    //       includeTxPower: true,
    //       primaryPhy: AndroidPhy.le1m,
    //       secondaryPhy: AndroidPhy.le2m,
    //     ),
    //     // Customize advertise payload separately from scan response
    //     advertiseData: AndroidAdvertiseData(
    //       includeDeviceName: true,
    //       includeTxPowerLevel: true,
    //       serviceUUIDs: [UUID.short(100)],
    //     ),
    //     // Separate scan response payload
    //     scanResponseData: AndroidAdvertiseData(
    //       includeDeviceName: false,
    //       manufacturerSpecificData: [
    //         ManufacturerSpecificData(
    //           id: 0x2e19,
    //           data: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
    //         ),
    //       ],
    //     ),
    //   ),
    // );

    await _manager.startAdvertising(balancedAdv);
    _advertising = true;
    notifyListeners();

    // Log the started configuration
    final log = Log(
      type: 'Advanced Android Advertising',
      message: 'Mode: Balanced (250ms interval), TX: Medium, Timeout: 60s',
    );
    _logs.add(log);
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateChangedSubscription.cancel();
    _characteristicReadRequestedSubscription.cancel();
    _characteristicWriteRequestedSubscription.cancel();
    _characteristicNotifyStateChangedSubscription.cancel();
    super.dispose();
  }
}
