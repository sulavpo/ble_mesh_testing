import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/mesh_group_service.dart';
import '../models/mesh_device.dart';
import '../models/mesh_group.dart';

class GroupManagementScreen extends StatelessWidget {
  final MeshGroupService _groupService = Get.find<MeshGroupService>();

  GroupManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Management'),
      ),
      body: Obx(() {
        if (_groupService.groupState.value == GroupState.error) {
          return const Center(
            child: Text('Error loading groups'),
          );
        }

        return ListView.builder(
          itemCount: _groupService.groups.length,
          itemBuilder: (context, index) {
            final group = _groupService.groups[index];
            return GroupCard(
              group: group,
              onDelete: () => _deleteGroup(group.id),
              onAddDevice: () => _showAddDeviceDialog(context, group),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final nameController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _groupService.createGroup(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDeviceDialog(
      BuildContext context, MeshGroup group) async {
    // TODO: Show list of available devices to add to group
    // This would require a list of available devices from the mesh network
  }

  Future<void> _deleteGroup(String groupId) async {
    await _groupService.deleteGroup(groupId);
  }
}

class GroupCard extends StatelessWidget {
  final MeshGroup group;
  final VoidCallback onDelete;
  final VoidCallback onAddDevice;

  const GroupCard({
    super.key,
    required this.group,
    required this.onDelete,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: onAddDevice,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${group.devices.length} devices',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: group.devices.map((device) {
                return Chip(
                  label: Text(device.name),
                  onDeleted: () {
                    // TODO: Implement remove device from group
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
