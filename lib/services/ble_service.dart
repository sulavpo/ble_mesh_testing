// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../models/mesh_device.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // BLE service state
  final RxList<MeshDevice> discoveredDevices = <MeshDevice>[].obs;
  final Rx<ScanState> scanState = ScanState.idle.obs;
  final RxBool isScanning = false.obs;
  final Rx<MeshDevice?> connectedDevice = Rx<MeshDevice?>(null);
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  // Initialize the service
  Future<BLEService> init() async {
    // Check if Bluetooth is available
    if (await FlutterBluePlus.isAvailable == false) {
      throw Exception('Bluetooth is not available on this device');
    }

    // Check if Bluetooth is on
    if (await FlutterBluePlus.isOn == false) {
      throw Exception('Bluetooth is not turned on');
    }

    return this;
  }

  // Start scanning for devices
  Future<void> startScan() async {
    if (isScanning.value) return;

    try {
      isScanning.value = true;
      discoveredDevices.clear();

      // Start scanning
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final device = MeshDevice.fromScanResult(result);
          if (!discoveredDevices.any((d) => d.id == device.id)) {
            discoveredDevices.add(device);
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      scanState.value = ScanState.error;
      rethrow;
    } finally {
      isScanning.value = false;
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      scanState.value = ScanState.idle;
    } catch (e) {
      scanState.value = ScanState.error;
      rethrow;
    }
  }

  // Connect to device
  Future<bool> connectToDevice(MeshDevice device) async {
    try {
      final bluetoothDevice = BluetoothDevice.fromId(device.address);

      _connectionSubscription = bluetoothDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          connectedDevice.value = device;
        } else if (state == BluetoothConnectionState.disconnected) {
          connectedDevice.value = null;
        }
      });

      await bluetoothDevice.connect();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Disconnect from device
  Future<void> disconnectFromDevice(MeshDevice device) async {
    try {
      if (connectedDevice.value != null) {
        final bluetoothDevice =
            BluetoothDevice.fromId(connectedDevice.value!.address);
        await bluetoothDevice.disconnect();
        connectedDevice.value = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting device: $e');
      }
      rethrow;
    }
  }

  // Cleanup
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    discoveredDevices.clear();
    isScanning.value = false;
    scanState.value = ScanState.idle;
  }
}

enum ScanState {
  idle,
  scanning,
  error,
}
