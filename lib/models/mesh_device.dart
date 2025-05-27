import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MeshDevice extends Equatable {
  final String id;
  final String name;
  final String address;
  final int rssi;
  final BluetoothDevice device;
  final Map<String, dynamic> deviceInfo;
  final String? meshVersion;
  final bool isOn;
  final int brightness;
  final int meshLayer;
  final String? parentAddress;
  final List<String> childAddresses;

  const MeshDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
    required this.device,
    required this.deviceInfo,
    this.meshVersion,
    this.isOn = false,
    this.brightness = 0,
    this.meshLayer = 0,
    this.parentAddress,
    this.childAddresses = const [],
  });

  factory MeshDevice.fromScanResult(ScanResult result) {
    return MeshDevice(
      id: const Uuid().v4(),
      name:
          result.device.name.isNotEmpty ? result.device.name : 'Unknown Device',
      address: result.device.remoteId.str,
      rssi: result.rssi,
      device: result.device,
      deviceInfo: {
        'advertisementData': result.advertisementData.manufacturerData,
        'serviceData': result.advertisementData.serviceData,
      },
    );
  }

  MeshDevice copyWith({
    String? id,
    String? name,
    String? address,
    int? rssi,
    BluetoothDevice? device,
    Map<String, dynamic>? deviceInfo,
    String? meshVersion,
    bool? isOn,
    int? brightness,
    int? meshLayer,
    String? parentAddress,
    List<String>? childAddresses,
  }) {
    return MeshDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
      device: device ?? this.device,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      meshVersion: meshVersion ?? this.meshVersion,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      meshLayer: meshLayer ?? this.meshLayer,
      parentAddress: parentAddress ?? this.parentAddress,
      childAddresses: childAddresses ?? this.childAddresses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'rssi': rssi,
      'deviceInfo': deviceInfo,
      'meshVersion': meshVersion,
      'isOn': isOn,
      'brightness': brightness,
      'meshLayer': meshLayer,
      'parentAddress': parentAddress,
      'childAddresses': childAddresses,
    };
  }

  factory MeshDevice.fromJson(Map<String, dynamic> json) {
    return MeshDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      rssi: json['rssi'] as int,
      device: BluetoothDevice.fromId(json['address'] as String),
      deviceInfo: Map<String, dynamic>.from(json['deviceInfo'] as Map),
      meshVersion: json['meshVersion'] as String?,
      isOn: json['isOn'] as bool? ?? false,
      brightness: json['brightness'] as int? ?? 0,
      meshLayer: json['meshLayer'] as int? ?? 0,
      parentAddress: json['parentAddress'] as String?,
      childAddresses: List<String>.from(json['childAddresses'] as List? ?? []),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        rssi,
        device,
        deviceInfo,
        meshVersion,
        isOn,
        brightness,
        meshLayer,
        parentAddress,
        childAddresses,
      ];
}
