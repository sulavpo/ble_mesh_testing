import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/mesh_device.dart';
import '../../services/mesh_message_service.dart';

class DeviceControlScreen extends StatelessWidget {
  final MeshMessageService _messageService = Get.find<MeshMessageService>();

  DeviceControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
      ),
      body: Obx(() {
        if (_messageService.messageState.value == MessageState.error) {
          return const Center(
            child: Text('Error controlling device'),
          );
        }

        return ListView.builder(
          itemCount: _messageService.availableDevices.length,
          itemBuilder: (context, index) {
            final device = _messageService.availableDevices[index];
            return DeviceControlCard(
              device: device,
              onToggle: () => _toggleDevice(device),
              onBrightnessChange: (value) => _setBrightness(device, value),
            );
          },
        );
      }),
    );
  }

  Future<void> _toggleDevice(MeshDevice device) async {
    await _messageService.sendMessage(
      device,
      {
        'opcode': 0x8202,
        'data': {'on': !device.isOn}
      },
    );
  }

  Future<void> _setBrightness(MeshDevice device, double value) async {
    await _messageService.sendMessage(
      device,
      {
        'opcode': 0x8246,
        'data': {'brightness': (value * 100).round()}
      },
    );
  }
}

class DeviceControlCard extends StatelessWidget {
  final MeshDevice device;
  final VoidCallback onToggle;
  final ValueChanged<double> onBrightnessChange;

  const DeviceControlCard({
    super.key,
    required this.device,
    required this.onToggle,
    required this.onBrightnessChange,
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
                  device.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Switch(
                  value: device.isOn,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Brightness',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: device.brightness / 100,
              onChanged: onBrightnessChange,
            ),
          ],
        ),
      ),
    );
  }
}
