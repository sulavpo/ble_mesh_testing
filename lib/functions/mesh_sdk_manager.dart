import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:hypnotik/src/features/devices_flow/data/models/light.dart';
// import 'package:hypnotik/src/features/settings_flow/data/models/gateway.dart';
// import 'package:hypnotik/src/utils/util.dart';
// import 'package:uuid/uuid.dart';

// import '../core/providers/home_provider.dart';
// import '../features/devices_flow/data/models/ble_state.dart';
// import '../features/devices_flow/data/models/dimmer.dart';
// import '../features/devices_flow/presentation/ble_gateway/ble_gateway_screen.dart';
// import '../routing/app_router.dart';

class CNMeshMethodChannel {
  static const channelName =
      'hypnotic.fantom.com/cnmesh_flutter'; // this channel name needs to match the one in Native method channel
  late MethodChannel methodChannel;
  late BuildContext context;
  bool isInitLight = false;
  int countDevice = 0;
  Timer? timer;
  String? dimmerName;

  static final CNMeshMethodChannel instance = CNMeshMethodChannel._init();
  CNMeshMethodChannel._init();

  void configureChannel(BuildContext context) {
    this.context = context;
    methodChannel = const MethodChannel(channelName);
    methodChannel.setMethodCallHandler(methodHandler);
  }

  void setIsInitLight(bool value) => isInitLight = value;

  Future<bool> startScanDevices(bool isLightsSearch) async {
    try {
      if (isLightsSearch) {
        timer = Timer(const Duration(seconds: 10), () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No lights found. Try again'),
          ));
        });
      }
      final bool result = await methodChannel.invokeMethod('startSearch');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> stopScanDevices() async {
    try {
      final bool result = await methodChannel.invokeMethod('stopSearch');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> getFactoryDevices() async {
    try {
      final bool result = await methodChannel.invokeMethod('getFactoryDevices');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> getProvisionedDevices() async {
    try {
      final bool result =
          await methodChannel.invokeMethod('getProvisionedDevices');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> getGateways() async {
    try {
      final bool result = await methodChannel.invokeMethod('getGateways');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> getDimmers(String setupName) async {
    try {
      dimmerName = setupName;
      final bool result = await methodChannel.invokeMethod('getDimmers');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<int> provisionRemote(String macAddress, int groupAddress) async {
    try {
      var mapValue = {'macAddress': macAddress, 'groupAddress': groupAddress};
      final int result = await methodChannel.invokeMethod('provisionRemote', mapValue);
      return result;
    } on PlatformException catch (e) {
      return 0;
    }
  }

  Future<int> provisionDevice(String macAddress, int groupAddress) async {
    try {
      countDevice++;
      var mapValue = {'macAddress': macAddress, 'groupAddress': groupAddress};
      final int result =
          await methodChannel.invokeMethod('provisionDevice', mapValue);
      return result;
    } on PlatformException catch (e) {
      return 0;
    }
  }

  Future<bool> unProvisionDevice(int meshAddress) async {
    try {
      final bool result =
          await methodChannel.invokeMethod('unProvisionDevice', meshAddress);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> unProvisionRemote(String macAddress) async {
    try {
      final bool result =
      await methodChannel.invokeMethod('unProvisionRemote', macAddress);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<int> provisionGateway(String idGateway) async {
    try {
      var mapValue = {'id': idGateway};
      final int result =
      await methodChannel.invokeMethod('provisionGateway', mapValue);
      return result;
    } on PlatformException catch (e) {
      return 0;
    }
  }

  Future<bool> addGroupDevice(int meshAddress, int groupAddress) async {
    try {
      var mapValue = {'meshAddress': meshAddress, 'groupAddress': groupAddress};
      final bool result =
          await methodChannel.invokeMethod('addToGroup', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> addSceneDevice(int meshAddress, int sceneAddress, int brightness,
      int red, int green, int blue, int cct) async {
    try {
      var mapValue = {
        'meshAddress': meshAddress,
        'sceneAddress': sceneAddress,
        'brightness': brightness,
        'red': red,
        'green': green,
        'blue': blue,
        'cct': cct
      };
      final bool result =
          await methodChannel.invokeMethod('addToScene', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> loadScene(int sceneAddress) async {
    try {
      var mapValue = {'meshAddress': 65535, 'sceneAddress': sceneAddress};
      final bool result =
          await methodChannel.invokeMethod('loadScene', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> lightOn(int meshAddress) async {
    try {
      final bool result =
          await methodChannel.invokeMethod('lightOn', meshAddress);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> lightOff(int meshAddress) async {
    try {
      final bool result =
          await methodChannel.invokeMethod('lightOff', meshAddress);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> brightness(int meshAddress, int value) async {
    try {
      var mapValue = {'meshAddress': meshAddress, 'value': value};
      final bool result =
          await methodChannel.invokeMethod('brightness', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> cct(int meshAddress, int value) async {
    try {
      var mapValue = {'meshAddress': meshAddress, 'value': value};
      final bool result = await methodChannel.invokeMethod('cct', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<bool> color(int meshAddress, int red, int green, int blue) async {
    try {
      var mapValue = {
        'meshAddress': meshAddress,
        'red': red,
        'green': green,
        'blue': blue
      };
      final bool result = await methodChannel.invokeMethod('color', mapValue);
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<void> methodHandler(MethodCall call) async {
    print('Method ${call.method}');
    print('Arguments ${call.arguments}');
    switch (call.method) {
      case 'isProvisioning':
        break;
      case 'isConnecting':
        String status = call.arguments;
        // ref.read(sdkReadyToWorkProvider.state).state = status;
        break;
      case 'isResetting':
        break;
      case 'isManualProvisioning':
        break;
      case 'isLoading':
        break;
      case 'meshManualProvisioningDevices':
        break;
      case 'provisionCount':
        break;
      case 'dimmers':
        List<dynamic> gatewaysDictionary = call.arguments;
        List<Dimmer> dimmers = gatewaysDictionary
            .map((e) => Dimmer(
            id: const Uuid().v4(),
            deviceId: e['id'],
            name: dimmerName ?? e['name'],
            macAddress: e['macAddress'],
            meshAddress: e['meshAddress'],
            productId: e['productId'],
            rssi: e['rssi']))
            .toList();
        break;
      case 'gateways':
        List<dynamic> gatewaysDictionary = call.arguments;
        List<Gateway> gateways = gatewaysDictionary
            .map((e) => Gateway(
            id: const Uuid().v4(),
            deviceId: e['id'],
            name: e['name'],
            macAddress: e['macAddress'],
            meshAddress: e['meshAddress'],
            productId: e['productId'],
            rssi: e['rssi']))
            .toList();
        break;
      case 'finishProvisionGateway':
        break;
      case 'meshDevices':
        List<dynamic> lightDictionary = call.arguments;
        List<Light> lights = lightDictionary
            .map((e) => Light(
                id: const Uuid().v4(),
                deviceId: e['id'],
                name: e['name'],
                macAddress: e['macAddress'],
                meshAddress: e['meshAddress'],
                productId: e['productId'],
                type: 'Downlight',
                cardColor: Colors.yellow,
                rssi: e['rssi']))
            .toList();
        if (lights.isNotEmpty && isInitLight) {
          if (timer != null) {
            timer!.cancel();
          }
          Navigator.of(context).pop();
        }
        break;
      case 'meshProvisionedDevices':
        List<dynamic> lightDictionary = call.arguments;
        List<Light> lights = lightDictionary
            .map((e) => Light(
                id: const Uuid().v4(),
                deviceId: e['id'],
                name: e['name'],
                macAddress: e['macAddress'],
                meshAddress: e['meshAddress'],
                productId: e['productId'],
                type: 'Downlight',
                cardColor: Colors.red,
                rssi: e['rssi']))
            .toList();
        break;
      case 'meshState':
        break;
      case 'meshConnectedDevice':
        break;
      case 'otaInProgress':
        break;
      case 'otaStatusString':
        break;
      case 'otaFileSentProgress':
        break;
      case 'otaMeshProgress':
        break;
      case 'finishProvision':
        countDevice--;
        if (countDevice == 0) {
          Navigator.of(context).pop();
        }
        break;
      case 'finishAddGroup':
        break;
      case 'finishAddScene':
        break;
      case 'finishUnprovision':
        break;
      case 'finishProvisionRemote':
        Navigator.of(context).pop();
        break;
      default:
        print('no method handler for method ${call.method}');
    }
  }
}







class Dimmer {
  final String id;
  final String deviceId;
  final String name;
  final String macAddress;
  final int meshAddress;
  final String productId;
  final int rssi;

  Dimmer({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.macAddress,
    required this.meshAddress,
    required this.productId,
    required this.rssi,
  });

  factory Dimmer.fromJson(Map<String, dynamic> json) {
    return Dimmer(
      id: json['id'],
      deviceId: json['deviceId'],
      name: json['name'],
      macAddress: json['macAddress'],
      meshAddress: json['meshAddress'],
      productId: json['productId'],
      rssi: json['rssi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'macAddress': macAddress,
      'meshAddress': meshAddress,
      'productId': productId,
      'rssi': rssi,
    };
  }
}



class Light {
  final String id;
  final String deviceId;
  final String name;
  final String macAddress;
  final int meshAddress;
  final String productId;
  final String type;
  final Color cardColor;
  final int rssi;

  Light({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.macAddress,
    required this.meshAddress,
    required this.productId,
    required this.type,
    required this.cardColor,
    required this.rssi,
  });

  factory Light.fromJson(Map<String, dynamic> json) {
    return Light(
      id: json['id'],
      deviceId: json['deviceId'],
      name: json['name'],
      macAddress: json['macAddress'],
      meshAddress: json['meshAddress'],
      productId: json['productId'],
      type: json['type'],
      cardColor: Color(json['cardColor']),
      rssi: json['rssi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'macAddress': macAddress,
      'meshAddress': meshAddress,
      'productId': productId,
      'type': type,
      'cardColor': cardColor.value,
      'rssi': rssi,
    };
  }
}


class Gateway {
  final String id;
  final String deviceId;
  final String name;
  final String macAddress;
  final int meshAddress;
  final String productId;
  final int rssi;

  Gateway({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.macAddress,
    required this.meshAddress,
    required this.productId,
    required this.rssi,
  });

  factory Gateway.fromJson(Map<String, dynamic> json) {
    return Gateway(
      id: json['id'],
      deviceId: json['deviceId'],
      name: json['name'],
      macAddress: json['macAddress'],
      meshAddress: json['meshAddress'],
      productId: json['productId'],
      rssi: json['rssi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'macAddress': macAddress,
      'meshAddress': meshAddress,
      'productId': productId,
      'rssi': rssi,
    };
  }
}
