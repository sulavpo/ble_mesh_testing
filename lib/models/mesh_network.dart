import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'mesh_device.dart';

class MeshNetwork extends Equatable {
  final String id;
  final String name;
  final List<MeshDevice> devices;
  final String networkKey;
  final String applicationKey;
  final int unicastAddress;
  final Map<String, dynamic>? configuration;

  const MeshNetwork._({
    required this.id,
    required this.name,
    required this.devices,
    required this.networkKey,
    required this.applicationKey,
    required this.unicastAddress,
    this.configuration,
  });

  factory MeshNetwork({
    String? id,
    required String name,
    List<MeshDevice>? devices,
    String? networkKey,
    String? applicationKey,
    int? unicastAddress,
    Map<String, dynamic>? configuration,
  }) {
    return MeshNetwork._(
      id: id ?? const Uuid().v4(),
      name: name,
      devices: devices ?? [],
      networkKey: networkKey ?? _generateNetworkKey(),
      applicationKey: applicationKey ?? _generateApplicationKey(),
      unicastAddress: unicastAddress ?? 0x0001,
      configuration: configuration,
    );
  }

  static String _generateNetworkKey() {
    // Generate a random 16-byte network key
    return const Uuid().v4().replaceAll('-', '').substring(0, 32);
  }

  static String _generateApplicationKey() {
    // Generate a random 16-byte application key
    return const Uuid().v4().replaceAll('-', '').substring(0, 32);
  }

  MeshNetwork copyWith({
    String? name,
    List<MeshDevice>? devices,
    String? networkKey,
    String? applicationKey,
    int? unicastAddress,
    Map<String, dynamic>? configuration,
  }) {
    return MeshNetwork(
      id: id,
      name: name ?? this.name,
      devices: devices ?? this.devices,
      networkKey: networkKey ?? this.networkKey,
      applicationKey: applicationKey ?? this.applicationKey,
      unicastAddress: unicastAddress ?? this.unicastAddress,
      configuration: configuration ?? this.configuration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'devices': devices.map((d) => d.toJson()).toList(),
      'networkKey': networkKey,
      'applicationKey': applicationKey,
      'unicastAddress': unicastAddress,
      'configuration': configuration,
    };
  }

  factory MeshNetwork.fromJson(Map<String, dynamic> json) {
    return MeshNetwork(
      id: json['id'] as String,
      name: json['name'] as String,
      devices: (json['devices'] as List)
          .map((d) => MeshDevice.fromJson(d as Map<String, dynamic>))
          .toList(),
      networkKey: json['networkKey'] as String,
      applicationKey: json['applicationKey'] as String,
      unicastAddress: json['unicastAddress'] as int,
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        devices,
        networkKey,
        applicationKey,
        unicastAddress,
        configuration,
      ];
}
