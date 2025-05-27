import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'features/device_scan/device_scan_screen.dart';
import 'features/device_control/device_control_screen.dart';
import 'features/ota_and_topology/ota_and_topology_screen.dart';
import 'screens/group_management_screen.dart';
import 'services/ble_service.dart';
import 'services/mesh_provisioning_service.dart';
import 'services/device_info_service.dart';
import 'services/ota_upgrade_service.dart';
import 'services/mesh_topology_service.dart';
import 'services/mesh_configuration_service.dart';
import 'services/mesh_message_service.dart';
import 'services/mesh_group_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions
  await Permission.bluetooth.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  await Permission.bluetoothAdvertise.request();
  await Permission.location.request();

  // Initialize services
  await Get.putAsync(() => BLEService().init());
  await Get.putAsync(() => MeshProvisioningService().init());
  Get.put(DeviceInfoService());
  Get.put(OTAUpgradeService());
  Get.put(MeshTopologyService());
  Get.put(MeshConfigurationService());
  Get.put(MeshMessageService());
  Get.put(MeshGroupService());

  // Set BLE logging level
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Mesh Testing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Mesh Testing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Get.to(() => const DeviceScanScreen()),
              child: const Text('Scan Devices'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.to(() => DeviceControlScreen()),
              child: const Text('Control Devices'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.to(() => OTAAndTopologyScreen()),
              child: const Text('OTA & Topology'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.to(() => GroupManagementScreen()),
              child: const Text('Group Management'),
            ),
          ],
        ),
      ),
    );
  }
}
