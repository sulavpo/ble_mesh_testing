import 'package:ble_testing/functions/some_functions.dart';
import 'package:flutter/material.dart';
import 'package:ble_testing/functions/mesh_sdk_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class BleMeshScannerTesting extends StatefulWidget {
  const BleMeshScannerTesting({super.key});

  @override
  _BleMeshScannerTestingState createState() => _BleMeshScannerTestingState();
}

class _BleMeshScannerTestingState extends State<BleMeshScannerTesting> {
  List<MeshDevice> devices = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    someFunction();

    // _initializeScanning();
  }

  Future<void> _initializeScanning() async {
    bool hasPermissions = true;
    if (hasPermissions) {
      startScanning();
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  void startScanning() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      devices.clear();
    });

    try {
      await MeshSdkManager.startProvisionMode();

      List<Map<String, dynamic>> factoryDevices =
          await MeshSdkManager.getFactoryMeshDevices();
      List<Map<String, dynamic>> provisionedDevices =
          await MeshSdkManager.getProvisionedMeshDevices();
      List<Map<String, dynamic>> gateways = await MeshSdkManager.getGateways();

      setState(() {
        devices.addAll(
            factoryDevices.map((d) => MeshDevice.fromMap(d, isFactory: true)));
        devices.addAll(provisionedDevices
            .map((d) => MeshDevice.fromMap(d, isFactory: false)));
        devices.addAll(gateways.map((d) => MeshDevice.fromGatewayMap(d)));
      });
    } catch (e) {
      print("Error during scanning: $e");
      _showErrorSnackBar('Failed to start scanning: ${e.toString()}');
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> provisionDevice(MeshDevice device) async {
    try {
      // For simplicity, we're using fixed values for meshAddress and groupAddress
      // In a real application, you'd want to manage these addresses properly
      bool success =
          await MeshSdkManager.provisionDevice(device.macAddress, 1, 32769);
      if (success) {
        _showErrorSnackBar('Device provisioned successfully');
        startScanning(); // Refresh the list
      } else {
        _showErrorSnackBar('Failed to provision device');
      }
    } catch (e) {
      print("Error during device provisioning: $e");
      _showErrorSnackBar('Error during provisioning: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('BLE Mesh Scanner'),
          actions: [
            IconButton(
              icon: Icon(isScanning ? Icons.stop : Icons.refresh),
              onPressed: isScanning ? null : startScanning,
            ),
          ],
        ),
        body: Center(
          child: ElevatedButton(
            child: const Text('Hello'),
            onPressed: () {
              someFunction();
              provisionDevice(MeshDevice(
                  macAddress: '08:D1:F9:1E:D9:76',
                  // "D8:13:2A:2C:E8:A6",
                  isProvisioned: false,
                  isGateway: false));
            },
          ),
        ));
  }
}

class MeshDevice {
  final String macAddress;
  final bool isProvisioned;
  final bool isGateway;

  MeshDevice({
    required this.macAddress,
    required this.isProvisioned,
    required this.isGateway,
  });

  factory MeshDevice.fromMap(Map<String, dynamic> map,
      {required bool isFactory}) {
    return MeshDevice(
      macAddress: map['macAddress'] as String? ?? '',
      isProvisioned: !isFactory,
      isGateway: false,
    );
  }

  factory MeshDevice.fromGatewayMap(Map<String, dynamic> map) {
    return MeshDevice(
      macAddress: map['macAddress'] as String? ?? '',
      isProvisioned: true,
      isGateway: true,
    );
  }
}
