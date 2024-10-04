import 'package:ble_testing/functions/mesh_sdk_manager.dart';
import 'package:flutter/material.dart';
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
    _initializeScanning();
  }

  Future<void> _initializeScanning() async {
    bool hasPermissions = await _checkAndRequestPermissions();
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
      // Configure the method channel before scanning
      CNMeshMethodChannel.instance.configureChannel(context);

      print('Starting scan for devices...');
      bool scanStarted = await CNMeshMethodChannel.instance.startScanDevices(true);
      if (!scanStarted) {
        print('Failed to start scanning.');
        _showErrorSnackBar('Failed to start scanning.');
        return;
      }

      // Fetch factory devices
      bool factoryDevicesRetrieved = await CNMeshMethodChannel.instance.getFactoryDevices();
      if (factoryDevicesRetrieved) {
        print('Factory devices retrieved successfully.');
        // Retrieve the devices from the method channel (dummy example here)
        List<MeshDevice> retrievedDevices = [
          MeshDevice(macAddress: '08:D1:F9:1E:D9:76', isProvisioned: false, isGateway: false),
          // Add more devices as needed
        ];

        setState(() {
          devices.addAll(retrievedDevices);
        });
      } else {
        print('Failed to retrieve factory devices.');
        _showErrorSnackBar('Failed to retrieve factory devices.');
      }
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
      // Call the provision method from CNMeshMethodChannel
      print('Provisioning device: ${device.macAddress}');
      int provisionResult = await CNMeshMethodChannel.instance.provisionDevice(device.macAddress, 1);

      if (provisionResult != 0) {
        _showErrorSnackBar('Device provisioned successfully.');
        startScanning(); // Refresh the list
      } else {
        _showErrorSnackBar('Failed to provision device.');
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
            child: const Text('Provision Device'),
            onPressed: () {
              provisionDevice(
                MeshDevice(
                  macAddress: '08:D1:F9:1E:D9:76',
                  isProvisioned: false,
                  isGateway: false,
                ),
              );
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

  factory MeshDevice.fromMap(Map<String, dynamic> map, {required bool isFactory}) {
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
