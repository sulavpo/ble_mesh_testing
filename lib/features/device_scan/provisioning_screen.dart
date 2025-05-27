import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/mesh_provisioning_service.dart';
import '../../models/mesh_device.dart';
import '../../models/mesh_network.dart';

class ProvisioningScreen extends StatelessWidget {
  final MeshDevice device;
  final MeshProvisioningService _provisioningService =
      Get.find<MeshProvisioningService>();
  final MeshNetwork network;

  ProvisioningScreen({super.key, required this.device, required this.network});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Provisioning ${device.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDeviceInfo(),
            const SizedBox(height: 24),
            _buildProvisioningStatus(),
            const SizedBox(height: 24),
            _buildProvisioningButton(),
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
              style: Theme.of(Get.context!).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Name: ${device.name}'),
            Text('Address: ${device.address}'),
            Text('RSSI: ${device.rssi} dBm'),
          ],
        ),
      ),
    );
  }

  Widget _buildProvisioningStatus() {
    return Obx(() {
      final state = _provisioningService.provisioningState.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provisioning Status',
                style: Theme.of(Get.context!).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_getStatusMessage(state)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _getProgressValue(state),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProvisioningButton() {
    return Obx(() {
      final state = _provisioningService.provisioningState.value;
      final isProvisioning = state != ProvisioningState.idle &&
          state != ProvisioningState.completed &&
          state != ProvisioningState.failed &&
          state != ProvisioningState.error;

      return ElevatedButton(
        onPressed: isProvisioning ? null : () => _startProvisioning(),
        child: Text(isProvisioning ? 'Provisioning...' : 'Start Provisioning'),
      );
    });
  }

  String _getStatusMessage(ProvisioningState state) {
    switch (state) {
      case ProvisioningState.idle:
        return 'Ready to start provisioning';
      case ProvisioningState.starting:
        return 'Starting provisioning process...';
      case ProvisioningState.inProgress:
        return 'Provisioning in progress...';
      case ProvisioningState.completed:
        return 'Provisioning completed successfully';
      case ProvisioningState.failed:
        return 'Provisioning failed - Please try again';
      case ProvisioningState.error:
        return 'An error occurred during provisioning - Please check device connection';
      case ProvisioningState.capabilitiesReceived:
        return 'Device capabilities received - Starting key exchange';
      case ProvisioningState.startSent:
        return 'Start message sent - Waiting for device response';
      case ProvisioningState.publicKeySent:
        return 'Public key exchange in progress - This may take a few seconds';
      case ProvisioningState.confirmationSent:
        return 'Confirmation sent - Verifying device';
      case ProvisioningState.randomSent:
        return 'Random value sent - Finalizing provisioning';
      case ProvisioningState.unknown:
        return 'Unknown state - Please try again';
      default:
        return 'Unknown status';
    }
  }

  double _getProgressValue(ProvisioningState state) {
    switch (state) {
      case ProvisioningState.idle:
        return 0.0;
      case ProvisioningState.starting:
        return 0.1;
      case ProvisioningState.inProgress:
        return 0.5;
      case ProvisioningState.completed:
        return 1.0;
      case ProvisioningState.failed:
      case ProvisioningState.error:
        return 0.0;
      case ProvisioningState.capabilitiesReceived:
        return 0.2;
      case ProvisioningState.startSent:
        return 0.3;
      case ProvisioningState.publicKeySent:
        return 0.7;
      case ProvisioningState.unknown:
        return 0.0;
      default:
        return 0.0;
    }
  }

  void _startProvisioning() async {
    try {
      await _provisioningService.startProvisioning(device, network);
    } catch (e) {
      print('[PROVISION] Error during provisioning: $e');
      // Show error dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Provisioning Error'),
          content: Text('Failed to provision device: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
