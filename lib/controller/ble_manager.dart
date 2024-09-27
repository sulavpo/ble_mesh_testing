import 'dart:typed_data';
import 'package:flutter/services.dart';

class BleManager {
  static const MethodChannel _channel = MethodChannel('com.example.ble_scanner/ble');

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
      case 'onError':
        onError?.call(call.arguments as String);
        break;
    }
  }

  Future<void> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      print('Failed to start scan: ${e.message}');
      onError?.call('Failed to start scan: ${e.message}');
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      print('Failed to stop scan: ${e.message}');
      onError?.call('Failed to stop scan: ${e.message}');
    }
  }

  Future<void> connect(String address) async {
    try {
      await _channel.invokeMethod('connect', {'address': address});
    } on PlatformException catch (e) {
      print('Failed to connect: ${e.message}');
      onError?.call('Failed to connect: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      print('Failed to disconnect: ${e.message}');
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
      print('Failed to read characteristic: ${e.message}');
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
      print('Failed to write characteristic: ${e.message}');
      onError?.call('Failed to write characteristic: ${e.message}');
    }
  }
}