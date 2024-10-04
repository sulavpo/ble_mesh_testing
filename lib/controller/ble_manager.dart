import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class BleManager {
  static const MethodChannel _channel =
      MethodChannel('com.example.ble_testing/ble'); // Updated package name

  Function(Map<String, dynamic>)? onDeviceFound;
  Function(String)? onConnectionStateChange;
  Function(List<Map<String, dynamic>>)? onServicesDiscovered;
  Function(Map<String, dynamic>)? onCharacteristicRead;
  Function(Map<String, dynamic>)? onCharacteristicWrite;
  Function(String)? onError;

  BleManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        final Map<String, dynamic> deviceInfo = call.arguments;
        log('Device found: ${deviceInfo['name']} (${deviceInfo['address']})');
        log('Is Mesh: ${deviceInfo['isMesh']}');
        log('Provisioning Service UUID: ${deviceInfo['provisioningServiceUuid']}');
        log('Primary PHY: ${deviceInfo['primaryPhy']}');
        log('Secondary PHY: ${deviceInfo['secondaryPhy']}');
        log('Advertising SID: ${deviceInfo['advertisingSid']}');
        log('TX Power: ${deviceInfo['txPower']}');
        log('Periodic Advertising Interval: ${deviceInfo['periodicAdvertisingInterval']}');

        // Log Service Data and Manufacturer Data
        _logServiceAndManufacturerData(deviceInfo);

        break;
      case 'onConnectionStateChange':
        onConnectionStateChange?.call(call.arguments as String);
        break;
      case 'onServicesDiscovered':
        onServicesDiscovered
            ?.call(List<Map<String, dynamic>>.from(call.arguments));
        break;
      case 'onCharacteristicRead':
        onCharacteristicRead?.call(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onCharacteristicWrite':
        onCharacteristicWrite?.call(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onError':
        onError?.call(call.arguments as String);
        break;
    }
  }

  void _logServiceAndManufacturerData(Map<String, dynamic> deviceInfo) {
    if (deviceInfo['serviceData'] != null) {
      for (var serviceData in deviceInfo['serviceData']) {
        log('Service Data - UUID: ${serviceData['uuid']}, Data: ${serviceData['data']}');
      }
    }

    if (deviceInfo['manufacturerData'] != null) {
      for (var manufacturerData in deviceInfo['manufacturerData']) {
        log('Manufacturer Data - ID: ${manufacturerData['manufacturerId']}, Data: ${manufacturerData['data']}');
      }
    }
  }

  Future<void> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      log('Failed to start scan: ${e.message}');
      onError?.call('Failed to start scan: ${e.message}');
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      log('Failed to stop scan: ${e.message}');
      onError?.call('Failed to stop scan: ${e.message}');
    }
  }

  Future<void> connect(String address) async {
    try {
      await _channel.invokeMethod('connect', {'address': address});
    } on PlatformException catch (e) {
      log('Failed to connect: ${e.message}');
      onError?.call('Failed to connect: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      log('Failed to disconnect: ${e.message}');
      onError?.call('Failed to disconnect: ${e.message}');
    }
  }

  Future<void> readCharacteristic(String serviceUuid, String characteristicUuid) async {
    try {
      await _channel.invokeMethod('readCharacteristic', {
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
      });
    } on PlatformException catch (e) {
      log('Failed to read characteristic: ${e.message}');
      onError?.call('Failed to read characteristic: ${e.message}');
    }
  }

  Future<void> writeCharacteristic(String serviceUuid, String characteristicUuid, Uint8List value) async {
    try {
      await _channel.invokeMethod('writeCharacteristic', {
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
        'value': value,
      });
    } on PlatformException catch (e) {
      log('Failed to write characteristic: ${e.message}');
      onError?.call('Failed to write characteristic: ${e.message}');
    }
  }

  // New methods for provisioning
  Future<Map<String, dynamic>?> startProvisioning(String address) async {
    try {
      final capabilities = await _channel.invokeMethod<Map<String, dynamic>>(
          'startProvisioning', {'address': address});
      return capabilities; // Return the device capabilities
    } on PlatformException catch (e) {
      log('Failed to start provisioning: ${e.message}');
      onError?.call('Failed to start provisioning: ${e.message}');
      return null; // Return null in case of error
    }
  }

  Future<void> sendProvisioningInvite(int attentionDuration) async {
    try {
      await _channel.invokeMethod('sendProvisioningInvite', {'attentionDuration': attentionDuration});
    } on PlatformException catch (e) {
      log('Failed to send provisioning invite: ${e.message}');
      onError?.call('Failed to send provisioning invite: ${e.message}');
    }
  }

  Future<void> sendProvisioningConfirmation(Uint8List confirmation) async {
    try {
      await _channel.invokeMethod('sendProvisioningConfirmation', {'confirmation': confirmation});
    } on PlatformException catch (e) {
      log('Failed to send provisioning confirmation: ${e.message}');
      onError?.call('Failed to send provisioning confirmation: ${e.message}');
    }
  }

  Future<void> sendProvisioningRandom(Uint8List random) async {
    try {
      await _channel.invokeMethod('sendProvisioningRandom', {'random': random});
    } on PlatformException catch (e) {
      log('Failed to send provisioning random: ${e.message}');
      onError?.call('Failed to send provisioning random: ${e.message}');
    }
  }

  Future<void> sendProvisioningData(Uint8List provisioningData) async {
    try {
      await _channel.invokeMethod('sendProvisioningData', {'provisioningData': provisioningData});
    } on PlatformException catch (e) {
      log('Failed to send provisioning data: ${e.message}');
      onError?.call('Failed to send provisioning data: ${e.message}');
    }
  }
}
