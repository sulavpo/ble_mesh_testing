import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/ota_upgrade_service.dart';
import '../services/mesh_topology_service.dart';

class OTAAndTopologyScreen extends StatelessWidget {
  OTAAndTopologyScreen({super.key});

  final OTAUpgradeService _otaService = Get.find<OTAUpgradeService>();
  final MeshTopologyService _topologyService = Get.find<MeshTopologyService>();
  final TextEditingController _fileController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  void _startOTAWithFile() async {
    // TODO: Implement file picker and call OTAUpgradeService.startOTA
    // Example: await _otaService.startOTA(selectedFile, _topologyService.topology);
  }

  void _startOTAWithUrl() async {
    // TODO: Implement URL input and call OTAUpgradeService.startOTAFromUrl
    // Example: await _otaService.startOTAFromUrl(url, _topologyService.topology);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTA & Topology')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OTA Upgrade'),
            TextField(
              controller: _fileController,
              decoration:
                  const InputDecoration(labelText: 'Firmware File Path'),
            ),
            ElevatedButton(
              onPressed: _startOTAWithFile,
              child: const Text('Start OTA (File)'),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'Firmware URL'),
            ),
            ElevatedButton(
              onPressed: _startOTAWithUrl,
              child: const Text('Start OTA (URL)'),
            ),
            Obx(() => Text('OTA Status: ${_otaService.upgradeState.value}')),
            const SizedBox(height: 32),
            const Text('Mesh Topology'),
            ElevatedButton(
              onPressed: () {
                // Example: fetch topology for a selected device
                // _topologyService.fetchTopology(selectedDevice);
              },
              child: const Text('Refresh Topology'),
            ),
            Obx(() => Expanded(
                  child: ListView.builder(
                    itemCount: _topologyService.topology.length,
                    itemBuilder: (context, index) {
                      final node = _topologyService.topology[index];
                      return ListTile(
                        title: Text(node.name),
                        subtitle: Text(node.address),
                        trailing: Text('Layer: ${node.meshLayer}'),
                        onTap: () {
                          // TODO: Implement device detail or control
                        },
                      );
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
