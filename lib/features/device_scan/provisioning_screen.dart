import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/mesh_provisioning_service.dart';

class AdvertisingScreen extends StatelessWidget {
  AdvertisingScreen({super.key});
  final MeshProvisioningService _advertisingService = MeshProvisioningService();

  Widget _infoSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device UUID: ${_advertisingService.deviceUuid}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Device Name: ${_advertisingService.deviceName}'),
            const SizedBox(height: 8),
            const Text('App Keys:'),
            ..._advertisingService.appKeys.map((k) => Text('  $k')),
            const SizedBox(height: 8),
            const Text('Capabilities:'),
            ..._advertisingService.capabilities.entries
                .map((e) => Text('  ${e.key}: ${e.value}')),
            const SizedBox(height: 8),
            const Text('Elements:'),
            ..._advertisingService.elements.map((el) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('  Location: ${el['location']}'),
                    Text('  Models: ${(el['models'] as List).join(", ")}'),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Advertiser'),
      ),
      body: Center(
        child: Obx(() => SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _infoSection(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _advertisingService.isAdvertising.value
                              ? Colors.green
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_advertisingService.isAdvertising.value
                          ? 'Advertising'
                          : 'Not Advertising'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _advertisingService.startAdvertising(),
                    child: const Text('Start Advertising'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _advertisingService.stopAdvertising(),
                    child: const Text('Stop Advertising'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _advertisingService.turnOn(),
                    child: const Text('Turn On'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _advertisingService.turnOff(),
                    child: const Text('Turn Off'),
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
