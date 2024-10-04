import 'package:flutter/services.dart';

class MeshSdkManager {
  static const MethodChannel _channel = MethodChannel('com.example.ble_scanner/ble');

  static Future<void> updateMeshUserNameAndPassword(String username, String password) async {
    try {
      await _channel.invokeMethod('updateMeshUserNameAndPassword', {
        'username': username,
        'password': password,
      });
    } catch (e) {
      _handleError(e);
    }
  }

  static Future<void> registerConnectionEvent() async {
    try {
      await _channel.invokeMethod('registerConnectionEvent');
    } catch (e) {
      _handleError(e);
    }
  }

  static Future<void> startProvisionMode() async {
    try {
      await _channel.invokeMethod('startProvisionMode');
    } catch (e) {
      _handleError(e);
    }
  }

  static Future<void> stopProvisionMode() async {
    try {
      await _channel.invokeMethod('stopProvisionMode');
    } catch (e) {
      _handleError(e);
    }
  }

static Future<List<Map<String, dynamic>>> getFactoryMeshDevices() async {
  try {
    final List<dynamic> result = await _channel.invokeMethod('getFactoryMeshDevices');
    return result.cast<Map<String, dynamic>>();
  } catch (e) {
    print('Error getting factory mesh devices: $e');
    return [];
  }
}

  static Future<List<Map<String, dynamic>>> getProvisionedMeshDevices() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getProvisionedMeshDevices');
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMeshDevices() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getMeshDevices');
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFactoryMeshDevicesWithFilter({
    String? productId,
    String? macAddress,
    int? rssi,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getFactoryMeshDevicesWithFilter', {
        'filter': {
          'productId': productId,
          'macAddress': macAddress,
          'rssi': rssi,
        },
      });
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  static Future<bool> provisionDevice(String macAddress, int meshAddress, int groupAddress) async {
    try {
      return await _channel.invokeMethod('provisionDevice', {
        'macAddress': macAddress,
        'meshAddress': meshAddress,
        'groupAddress': groupAddress,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<bool> unProvisionDevice(int meshAddress) async {
    try {
      return await _channel.invokeMethod('unProvisionDevice', {
        'meshAddress': meshAddress,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<bool> sendCommand(int meshAddress, String commandType, Map<String, dynamic> commandParams) async {
    try {
      return await _channel.invokeMethod('sendCommand', {
        'meshAddress': meshAddress,
        'commandType': commandType,
        'commandParams': commandParams,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<bool> connectAndSendCommand(String macAddress, List<Map<String, dynamic>> commands) async {
    try {
      return await _channel.invokeMethod('connectAndSendCommand', {
        'macAddress': macAddress,
        'commands': commands,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getGateways() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getGateways');
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getGatewaysWithFilter({
    String? productId,
    String? macAddress,
    int? rssi,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getGatewaysWithFilter', {
        'filter': {
          'productId': productId,
          'macAddress': macAddress,
          'rssi': rssi,
        },
      });
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  static Future<bool> provisionGateway(String macAddress) async {
    try {
      return await _channel.invokeMethod('provisionGateway', {
        'macAddress': macAddress,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<bool> unProvisionGateway(String macAddress) async {
    try {
      return await _channel.invokeMethod('unProvisionGateway', {
        'macAddress': macAddress,
      });
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Helper function to handle errors
  static void _handleError(dynamic error) {
    if (error is PlatformException) {
      print('PlatformException: ${error.message}');
    } else {
      print('Unexpected error: $error');
    }
  }
}

// Helper classes for type safety
class MeshDevice {
  final String macAddress;
  // Add other properties as needed

  MeshDevice({required this.macAddress});

  factory MeshDevice.fromMap(Map<String, dynamic> map) {
    return MeshDevice(
      macAddress: map['macAddress'] as String,
      // Initialize other properties
    );
  }
}

class MeshCommand {
  final String type;
  final Map<String, dynamic> params;

  MeshCommand({required this.type, required this.params});

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'params': params,
    };
  }
}

// Example command classes
class BlinkCommand extends MeshCommand {
  BlinkCommand({int delay = 0}) : super(type: 'Blink', params: {'delay': delay});
}

class OnCommand extends MeshCommand {
  OnCommand({int delay = 0}) : super(type: 'On', params: {'delay': delay});
}

class OffCommand extends MeshCommand {
  OffCommand({int delay = 0}) : super(type: 'Off', params: {'delay': delay});
}

class BrightnessCommand extends MeshCommand {
  BrightnessCommand({required int brightness, int delay = 0})
      : super(type: 'Brightness', params: {'brightness': brightness, 'delay': delay});
}
