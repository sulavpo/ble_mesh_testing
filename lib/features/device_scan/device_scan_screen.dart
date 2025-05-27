import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/ble_service.dart';
import '../../models/mesh_device.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'provisioning_screen.dart';
import '../../services/mesh_configuration_service.dart';
import '../../models/mesh_network.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final BLEService _bleService = Get.find<BLEService>();
  final MeshConfigurationService _configService =
      Get.find<MeshConfigurationService>();
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _configService.init();
  }

  void _onRefresh() async {
    // Only clear BLEService's discoveredDevices on pull-to-refresh
    _bleService.discoveredDevices.clear();
    setState(() {});
    await _startScanWithTimeout();
    _refreshController.refreshCompleted();
  }

  Future<void> _startScanWithTimeout() async {
    await _bleService.startScan();
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 15), () {
      _bleService.stopScan();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _showNetworkSelectionDialog(MeshDevice device) async {
    await _configService.init(); // Ensure service is initialized
    final networks = _configService.savedNetworks;
    if (networks.isEmpty) {
      // If no networks exist, create a new one
      final newNetwork = MeshNetwork(name: 'New Network');
      await _configService.saveNetwork(newNetwork);
      _configService.currentNetwork.value = newNetwork;
      Get.to(() => ProvisioningScreen(device: device, network: newNetwork));
      return;
    }

    return Get.dialog(
      AlertDialog(
        title: const Text('Select Network'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: networks.length,
            itemBuilder: (context, index) {
              final network = networks[index];
              return ListTile(
                title: Text(network.name),
                subtitle: Text('${network.devices.length} devices'),
                onTap: () {
                  _configService.currentNetwork.value = network;
                  Get.back();
                  Get.to(() =>
                      ProvisioningScreen(device: device, network: network));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Create new network
              final newNetwork = MeshNetwork(name: 'New Network');
              await _configService.saveNetwork(newNetwork);
              _configService.currentNetwork.value = newNetwork;
              Get.back();
              Get.to(() =>
                  ProvisioningScreen(device: device, network: newNetwork));
            },
            child: const Text('Create New Network'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Mesh Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear All Networks',
            onPressed: () async {
              await MeshConfigurationService().clearAllNetworks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All networks cleared.')),
                );
              }
            },
          ),
          Obx(() => IconButton(
                icon: Icon(
                    _bleService.isScanning.value ? Icons.stop : Icons.refresh),
                onPressed: () {
                  if (_bleService.isScanning.value) {
                    _bleService.stopScan();
                    _scanTimer?.cancel();
                  } else {
                    _startScanWithTimeout();
                  }
                  setState(() {});
                },
              )),
        ],
      ),
      body: Obx(() {
        // Deduplicate devices by address
        final Map<String, MeshDevice> uniqueDevices = {};
        for (final device in _bleService.discoveredDevices) {
          uniqueDevices[device.address] = device;
        }
        final devices = uniqueDevices.values.toList();
        return SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          child: devices.isEmpty
              ? const Center(
                  child: Text('No devices found. Pull to refresh.'),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return DeviceListItem(
                      device: device,
                      onTap: () => _showNetworkSelectionDialog(device),
                    );
                  },
                ),
        );
      }),
    );
  }
}

class DeviceListItem extends StatelessWidget {
  final MeshDevice device;
  final VoidCallback onTap;

  const DeviceListItem({
    super.key,
    required this.device,
    required this.onTap,
  });

  int _rssiBars(int rssi) {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _rssiBars(device.rssi);
    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(device.name),
      subtitle: Text(device.address),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${device.rssi} dBm'),
          const SizedBox(width: 8),
          Row(
            children: List.generate(4, (index) {
              return Icon(
                Icons.signal_cellular_4_bar,
                size: 16,
                color: index < bars ? Colors.green : Colors.grey[300],
              );
            }),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
