import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/mesh_device.dart';
import '../../services/ota_upgrade_service.dart';
import '../../services/mesh_topology_service.dart';

class OTAAndTopologyScreen extends StatelessWidget {
  final OTAUpgradeService _otaService = Get.find<OTAUpgradeService>();
  final MeshTopologyService _topologyService = Get.find<MeshTopologyService>();

  OTAAndTopologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OTA & Topology'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'OTA Upgrade'),
              Tab(text: 'Mesh Topology'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOTATab(),
            _buildTopologyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOTATab() {
    return Obx(() {
      if (_otaService.upgradeState.value == UpgradeState.error) {
        return const Center(
          child: Text('Error during OTA upgrade'),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => _selectFirmwareFile(),
              child: const Text('Select Firmware File'),
            ),
            const SizedBox(height: 16),
            if (_otaService.selectedFile.value != null)
              Text('Selected file: ${_otaService.selectedFile.value!.path}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _otaService.selectedFile.value != null
                  ? () => _startOTAUpgrade()
                  : null,
              child: const Text('Start OTA Upgrade'),
            ),
            if (_otaService.upgradeState.value == UpgradeState.upgrading)
              const LinearProgressIndicator(),
          ],
        ),
      );
    });
  }

  Widget _buildTopologyTab() {
    return Obx(() {
      if (_topologyService.topologyState.value == TopologyState.error) {
        return const Center(
          child: Text('Error loading topology'),
        );
      }

      return ListView.builder(
        itemCount: _topologyService.topology.length,
        itemBuilder: (context, index) {
          final device = _topologyService.topology[index];
          return TopologyCard(device: device);
        },
      );
    });
  }

  Future<void> _selectFirmwareFile() async {
    // TODO: Implement file selection
  }

  Future<void> _startOTAUpgrade() async {
    if (_otaService.selectedFile.value != null) {
      await _otaService.startOTA(
        _otaService.selectedFile.value!,
        _topologyService.topology,
      );
    }
  }

  // void _startOTAWithFile() async {
  //   // TODO: Implement file picker and call OTAUpgradeService.startOTA
  //   // Example: await _otaService.startOTA(selectedFile, _topologyService.topology);
  // }

  // void _startOTAWithUrl() async {
  //   // TODO: Implement URL input and call OTAUpgradeService.startOTAFromUrl
  //   // Example: await _otaService.startOTAFromUrl(url, _topologyService.topology);
  // }
}

class TopologyCard extends StatelessWidget {
  final MeshDevice device;

  const TopologyCard({
    super.key,
    required this.device,
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
            Text(
              device.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Address: ${device.address}'),
            Text('Mesh Layer: ${device.meshLayer}'),
            if (device.parentAddress != null)
              Text('Parent: ${device.parentAddress}'),
            if (device.childAddresses.isNotEmpty)
              Text('Children: ${device.childAddresses.join(", ")}'),
          ],
        ),
      ),
    );
  }
}
