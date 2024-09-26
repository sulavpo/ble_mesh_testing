// import 'package:ble_testing/controller/ble_controller.dart';
// import 'package:ble_testing/controller/ble_mesh_provisioning_controller.dart';
// // import 'package:ble_testing/nordic_nrf_mesh.dart';
// import 'package:ble_testing/screen/bluetooth_off_screen.dart';
// import 'package:ble_testing/screen/scanner_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:get/get.dart';

// class FlutterBlueApp extends StatefulWidget {
//   const FlutterBlueApp({super.key});

//   @override
//   State<FlutterBlueApp> createState() => _FlutterBlueAppState();
// }

// class _FlutterBlueAppState extends State<FlutterBlueApp> {
//   //  late final NordicNrfMesh nordicNrfMesh = NordicNrfMesh();
//   final BleController controller = Get.put(BleController());
//   final BleMeshProvisioningController controllerProvisioning = Get.put(BleMeshProvisioningController());

//   @override
//   void initState() {
//     super.initState();
//     controller.initBle();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Obx(() => controller.bluetoothOn.value
//         ? ScannerScreen(controller: controller
//         ,controllerProvisioning: controllerProvisioning,
//         )
//         : BluetoothOffScreen(controller: controller));
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class BLEScannerScreen extends StatefulWidget {
//   const BLEScannerScreen({super.key});

//   @override
//   _BLEScannerScreenState createState() => _BLEScannerScreenState();
// }

// class _BLEScannerScreenState extends State<BLEScannerScreen> {
//   static const platform = MethodChannel('com.example.ble_testing/bluetooth');
//   List<Map<String, String>> devices = [];

//   @override
//   void initState() {
//     super.initState();
//     scanForBLEDevices();
//   }

//   Future<void> scanForBLEDevices() async {
//     try {
//       // Call the native method to scan for BLE devices
//       final List<dynamic> result =
//           await platform.invokeMethod('scanBLEDevices');

//       // Convert result to List<Map<String, String>>
//       List<Map<String, String>> scannedDevices = result.map((device) {
//         return Map<String, String>.from(device);
//       }).toList();

//       // Update the device list in the UI
//       setState(() {
//         devices = scannedDevices;
//       });
//     } on PlatformException catch (e) {
//       print("Failed to scan BLE devices: '${e.message}'.");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('BLE Devices'),
//       ),
//       body: devices.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: devices.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text(devices[index]['name'] ?? 'Unknown'),
//                   subtitle:
//                       Text(devices[index]['macAddress'] ?? 'No MAC Address'),
//                   trailing: Icon(
//                     devices[index]['isMesh'] == 'true'
//                         ? Icons.bluetooth_connected // Mesh device icon
//                         : Icons.bluetooth, // Regular BLE icon
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }

import 'dart:async'; // Import for Timer
import 'dart:developer';

import 'package:ble_testing/screen/device_detail_sceen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BleScanner extends StatefulWidget {
  const BleScanner({super.key});

  @override
  _BleScannerState createState() => _BleScannerState();
}

class _BleScannerState extends State<BleScanner> {
  static const platform = MethodChannel('com.example.ble_scanner/ble');
  List<Map<String, dynamic>> devices = [];
  bool isScanning = false;
  Timer? _scanTimer; // Timer to stop scan after 10 seconds

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        Map<String, dynamic> device = Map<String, dynamic>.from(call.arguments);

        // Check if the device is already in the list
        if (devices.any((d) => d['address'] == device['address'])) return;

        setState(() {
          devices.add(device);
        });
        break;
      default:
        print('Unimplemented method ${call.method}');
        throw MissingPluginException();
    }
  }

  Future<void> startScan() async {
    setState(() {
      isScanning = true; // Indicate that scanning has started
      devices.clear(); // Clear the previous device list
    });

    try {
      await platform.invokeMethod('startScan');

      // Set a timer to stop scanning after 10 seconds
      _scanTimer = Timer(const Duration(seconds: 10), () {
        stopScan();
      });
    } on PlatformException catch (e) {
      log('Failed to start scan: ${e.message}');
      if (e.code == 'PERMISSION_DENIED') {
        _showAlertDialog(
          title: 'Permission Denied',
          content:
              'Bluetooth scan permission is required for this functionality. Please grant the permission in the app settings.',
        );
      } else {
        _showAlertDialog(
          title: 'Error',
          content:
              'An error occurred while starting the Bluetooth scan: ${e.message}',
        );
      }
      setState(() {
        isScanning = false;
      });
    } catch (e) {
      print('An unexpected error occurred: $e');
      _showAlertDialog(
        title: 'Unexpected Error',
        content: 'An unexpected error occurred: $e',
      );
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> stopScan() async {
    try {
      await platform.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      print("Failed to stop scan: '${e.message}'.");
    }

    setState(() {
      isScanning = false; // Scanning is stopped
    });

    // Cancel the timer if it hasn't already been called
    _scanTimer?.cancel();
  }

  void _showAlertDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
      ),
      body: Column(
        children: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: const Text('Start Scan'),
          ),
          ElevatedButton(
            onPressed: isScanning ? stopScan : null,
            child: const Text('Stop Scan'),
          ),
          Expanded(
            child: devices.isNotEmpty
                ? ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        trailing: device['isMesh']
                            ? Text(device['provisioningServiceUuid'] == '1827'
                                ? 'UnProvisioned'
                                : 'Provisioned')
                            : null,
                        leading: Icon(
                          device['isMesh'] ? Icons.network_wifi : Icons.bluetooth,
                          color: device['isMesh'] ? Colors.green : Colors.blue,
                        ),
                        title: Text(device['name']),
                        subtitle: Text(device['address']),
                        onTap: () {
                          if (device['isMesh']) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeviceDetailScreen(device: device),
                              ),
                            );
                          }
                        },
                      );
                    },
                  )
                : Center(
                    child: Text(isScanning
                        ? 'Scanning for devices...'
                        : 'No devices found.'),
                  ),
          ),
        ],
      ),
    );
  }
}
