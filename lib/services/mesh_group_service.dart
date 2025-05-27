import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../models/mesh_device.dart';
import '../models/mesh_network.dart';
import '../models/mesh_group.dart';

class MeshGroupService {
  static final MeshGroupService _instance = MeshGroupService._internal();
  factory MeshGroupService() => _instance;
  MeshGroupService._internal();

  // Group management state
  final Rx<MeshNetwork?> currentNetwork = Rx<MeshNetwork?>(null);
  final RxList<MeshGroup> groups = <MeshGroup>[].obs;
  final Rx<GroupState> groupState = GroupState.idle.obs;

  // Initialize the service
  Future<void> init() async {
    // Load saved groups if any
    // TODO: Implement persistence
  }

  // Create a new group
  Future<bool> createGroup(String name) async {
    try {
      groupState.value = GroupState.creating;

      // Create a new group with a unique ID
      final group = MeshGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        devices: [],
      );

      groups.add(group);
      groupState.value = GroupState.idle;
      return true;
    } catch (e) {
      groupState.value = GroupState.error;
      return false;
    }
  }

  // Add device to group
  Future<bool> addDeviceToGroup(String groupId, MeshDevice device) async {
    try {
      groupState.value = GroupState.updating;

      final group = groups.firstWhere((g) => g.id == groupId);
      if (!group.devices.contains(device)) {
        group.devices.add(device);
        groups.refresh();
      }

      groupState.value = GroupState.idle;
      return true;
    } catch (e) {
      groupState.value = GroupState.error;
      return false;
    }
  }

  // Remove device from group
  Future<bool> removeDeviceFromGroup(String groupId, MeshDevice device) async {
    try {
      groupState.value = GroupState.updating;

      final group = groups.firstWhere((g) => g.id == groupId);
      group.devices.remove(device);
      groups.refresh();

      groupState.value = GroupState.idle;
      return true;
    } catch (e) {
      groupState.value = GroupState.error;
      return false;
    }
  }

  // Delete group
  Future<bool> deleteGroup(String groupId) async {
    try {
      groupState.value = GroupState.deleting;

      groups.removeWhere((g) => g.id == groupId);
      groups.refresh();

      groupState.value = GroupState.idle;
      return true;
    } catch (e) {
      groupState.value = GroupState.error;
      return false;
    }
  }

  // Send message to group
  Future<bool> sendMessageToGroup(
      String groupId, Map<String, dynamic> message) async {
    try {
      groupState.value = GroupState.sending;

      final group = groups.firstWhere((g) => g.id == groupId);
      // TODO: Implement group message sending logic

      groupState.value = GroupState.idle;
      return true;
    } catch (e) {
      groupState.value = GroupState.error;
      return false;
    }
  }

  // Cleanup
  void dispose() {
    groups.clear();
    groupState.value = GroupState.idle;
  }
}

enum GroupState { idle, creating, updating, deleting, sending, error }
