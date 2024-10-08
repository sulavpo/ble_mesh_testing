import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class BleManager {
  static const MethodChannel _channel = MethodChannel('com.example.ble_scanner/ble');

  // Define callbacks
  void Function(Map<String, dynamic>)? onDeviceFound;
  void Function(String)? onConnectionStateChange;
  void Function(List<Map<String, dynamic>>)? onServicesDiscovered;
  void Function(Map<String, dynamic>)? onCharacteristicRead;
  void Function(Map<String, dynamic>)? onCharacteristicWrite;
  void Function()? onProvisioningServiceFound;
  void Function(Uint8List)? onProvisioningCapabilities;
  void Function(Uint8List)? onProvisioningPublicKey;
  void Function(Uint8List)? onProvisioningConfirmation;
  void Function(Uint8List)? onProvisioningRandom;
  void Function()? onProvisioningComplete;
  void Function(Uint8List)? onProvisioningFailed;
  void Function(String)? onError;

  BleManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        onDeviceFound?.call(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onConnectionStateChange':
        onConnectionStateChange?.call(call.arguments as String);
        break;
      case 'onServicesDiscovered':
        onServicesDiscovered?.call(List<Map<String, dynamic>>.from(call.arguments));
        break;
      case 'onCharacteristicRead':
        onCharacteristicRead?.call(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onCharacteristicWrite':
        onCharacteristicWrite?.call(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onProvisioningServiceFound':
        onProvisioningServiceFound?.call();
        break;
      case 'onProvisioningCapabilities':
        onProvisioningCapabilities?.call(Uint8List.fromList(call.arguments));
        break;
      case 'onProvisioningPublicKey':
        onProvisioningPublicKey?.call(Uint8List.fromList(call.arguments));
        break;
      case 'onProvisioningConfirmation':
        onProvisioningConfirmation?.call(Uint8List.fromList(call.arguments));
        break;
      case 'onProvisioningRandom':
        onProvisioningRandom?.call(Uint8List.fromList(call.arguments));
        break;
      case 'onProvisioningComplete':
        onProvisioningComplete?.call();
        break;
      case 'onProvisioningFailed':
        onProvisioningFailed?.call(Uint8List.fromList(call.arguments));
        break;
      case 'onError':
        onError?.call(call.arguments as String);
        break;
    }
  }

  Future<void> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      onError?.call('Failed to start scan: ${e.message}');
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      onError?.call('Failed to stop scan: ${e.message}');
    }
  }

  Future<void> connect(String address) async {
    try {
      await _channel.invokeMethod('connect', {'address': address});
    } on PlatformException catch (e) {
      onError?.call('Failed to connect: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      onError?.call('Failed to disconnect: ${e.message}');
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
      onError?.call('Failed to write characteristic: ${e.message}');
    }
  }

  Future<void> startProvisioning(String address) async {
    try {
      await _channel.invokeMethod('startProvisioning', {'address': address});
    } on PlatformException catch (e) {
      onError?.call('Failed to start provisioning: ${e.message}');
    }
  }

  Future<void> sendProvisioningInvite(int attentionDuration) async {
    try {
      await _channel.invokeMethod('sendProvisioningInvite', {'attentionDuration': attentionDuration});
    } on PlatformException catch (e) {
      onError?.call('Failed to send provisioning invite: ${e.message}');
    }
  }

  Future<void> sendProvisioningConfirmation(Uint8List confirmation) async {
    try {
      await _channel.invokeMethod('sendProvisioningConfirmation', {'confirmation': confirmation});
    } on PlatformException catch (e) {
      onError?.call('Failed to send provisioning confirmation: ${e.message}');
    }
  }

  Future<void> sendProvisioningRandom(Uint8List random) async {
    try {
      await _channel.invokeMethod('sendProvisioningRandom', {'random': random});
    } on PlatformException catch (e) {
      onError?.call('Failed to send provisioning random: ${e.message}');
    }
  }

  Future<void> sendProvisioningData(Uint8List provisioningData) async {
    try {
      await _channel.invokeMethod('sendProvisioningData', {'provisioningData': provisioningData});
    } on PlatformException catch (e) {
      onError?.call('Failed to send provisioning data: ${e.message}');
    }
  }
}