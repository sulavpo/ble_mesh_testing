import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/mesh_device.dart';
import '../services/mesh_message_service.dart';

class DeviceControlScreen extends StatelessWidget {
  final MeshDevice device;
  final MeshMessageService _messageService = Get.find<MeshMessageService>();

  DeviceControlScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control ${device.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDeviceInfo(),
            const SizedBox(height: 24),
            _buildPowerControl(),
            const SizedBox(height: 24),
            _buildBrightnessControl(),
            const SizedBox(height: 24),
            _buildStatusIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Get.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Name: ${device.name}'),
            Text('Address: ${device.address}'),
            Text('Mesh Version: ${device.meshVersion ?? 'Unknown'}'),
            Text('Layer: ${device.meshLayer}'),
            if (device.parentAddress != null)
              Text('Parent: ${device.parentAddress}'),
            if (device.childAddresses.isNotEmpty)
              Text('Children: ${device.childAddresses.join(', ')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Control',
              style: Get.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Obx(() {
              final isOn = _messageService.targetDevice.value?.isOn ?? false;
              return SwitchListTile(
                title: Text(isOn ? 'On' : 'Off'),
                value: isOn,
                onChanged: (value) {
                  _messageService.sendMessage(
                    device,
                    {'command': value ? 'turn_on' : 'turn_off'},
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brightness Control',
              style: Get.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Obx(() {
              final brightness =
                  _messageService.targetDevice.value?.brightness ?? 0;
              return Column(
                children: [
                  Slider(
                    value: brightness.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '$brightness%',
                    onChanged: (value) {
                      _messageService.sendMessage(
                        device,
                        {
                          'command': 'set_brightness',
                          'brightness': value.toInt()
                        },
                      );
                    },
                  ),
                  Text('$brightness%'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Obx(() {
      final state = _messageService.messageState.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: Get.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildStatusText(state),
              if (state == MessageState.sending)
                const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusText(MessageState state) {
    String text;
    Color color;

    switch (state) {
      case MessageState.idle:
        text = 'Ready';
        color = Colors.green;
        break;
      case MessageState.sending:
        text = 'Sending...';
        color = Colors.blue;
        break;
      case MessageState.sent:
        text = 'Message Sent';
        color = Colors.green;
        break;
      case MessageState.received:
        text = 'Response Received';
        color = Colors.green;
        break;
      case MessageState.failed:
        text = 'Failed';
        color = Colors.red;
        break;
      case MessageState.error:
        text = 'Error';
        color = Colors.red;
        break;
    }

    return Text(
      text,
      style: TextStyle(color: color),
    );
  }
}
