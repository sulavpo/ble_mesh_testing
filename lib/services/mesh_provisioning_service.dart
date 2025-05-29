import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class MeshProvisioningService {
  static final MeshProvisioningService _instance =
      MeshProvisioningService._internal();
  factory MeshProvisioningService() => _instance;
  MeshProvisioningService._internal() {
    _setupMethodCallHandler();
  }

  static const platform =
      MethodChannel('com.example.ble_testing/ble_advertiser');
  final RxBool isAdvertising = false.obs;

  // Example/stub data for mesh node
  final String deviceUuid = '00001827-0000-1000-8000-00805f9b34fb';
  final String deviceName = 'BLE Mesh Node';
  final List<String> appKeys = [
    '1234567890abcdef1234567890abcdef',
    'abcdef1234567890abcdef1234567890',
  ];
  final Map<String, dynamic> capabilities = {
    'numElements': 1,
    'algorithms': ['FIPS P-256 Elliptic Curve'],
    'publicKeyType': 'No OOB',
    'staticOobType': 'Not supported',
    'outputOobSize': 0,
    'inputOobSize': 0,
  };
  final List<Map<String, dynamic>> elements = [
    {
      'location': '0x0000',
      'models': ['Generic OnOff Server', 'Generic Level Server'],
    },
  ];

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdvertisingStarted':
          print('[NODE] Advertising started successfully');
          isAdvertising.value = true;
          break;
        case 'onAdvertisingError':
          print('[NODE] Advertising error: ${call.arguments}');
          isAdvertising.value = false;
          break;
      }
    });
  }

  Future<void> startAdvertising() async {
    try {
      // Request necessary permissions
      await Permission.bluetooth.request();
      await Permission.bluetoothAdvertise.request();
      await Permission.location.request();

      if (!isAdvertising.value) {
        // Start advertising through platform channel
        await platform.invokeMethod('startAdvertising');
        isAdvertising.value = true;
        print('[NODE] Started advertising with Mesh provisioning service');
      }
    } catch (e) {
      print('[NODE] Error starting advertising: $e');
      isAdvertising.value = false;
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      if (isAdvertising.value) {
        await platform.invokeMethod('stopAdvertising');
        isAdvertising.value = false;
        print('[NODE] Stopped advertising');
      }
    } catch (e) {
      print('[NODE] Error stopping advertising: $e');
      rethrow;
    }
  }

  // Stub for sending a "Turn On" command
  Future<void> turnOn() async {
    print('[NODE] Turn On command sent (stub)');
    // TODO: Implement BLE characteristic write or other communication
  }

  // Stub for sending a "Turn Off" command
  Future<void> turnOff() async {
    print('[NODE] Turn Off command sent (stub)');
    // TODO: Implement BLE characteristic write or other communication
  }
}
