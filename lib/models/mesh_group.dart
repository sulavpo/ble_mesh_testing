import 'mesh_device.dart';

class MeshGroup {
  final String id;
  final String name;
  final List<MeshDevice> devices;

  MeshGroup({
    required this.id,
    required this.name,
    required this.devices,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'devices': devices.map((device) => device.toJson()).toList(),
    };
  }

  factory MeshGroup.fromJson(Map<String, dynamic> json) {
    return MeshGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      devices: (json['devices'] as List)
          .map((device) => MeshDevice.fromJson(device as Map<String, dynamic>))
          .toList(),
    );
  }
}
