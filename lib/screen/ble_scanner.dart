import 'package:flutter/material.dart';
import 'package:ble_testing/functions/mesh_sdk_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class BleMeshScannerTesting extends StatefulWidget {
  const BleMeshScannerTesting({super.key});

  @override
  _BleMeshScannerTestingState createState() => _BleMeshScannerTestingState();
}

class _BleMeshScannerTestingState extends State<BleMeshScannerTesting> {
  List<MeshDevice> gateways = [];         // List of gateways
  bool isScanningForGateways = false;     // To track scanning state
  bool scanComplete = false;              // To track whether the scan has completed

  @override
  void initState() {
    super.initState();
    _initializeScanning();  // Automatically start scanning on app start
  }

  Future<void> _initializeScanning() async {
    bool hasPermissions = await _checkAndRequestPermissions();
    if (hasPermissions) {
      startScanningForGateways();  // Start scanning if permissions are granted
    }
  }

  // Check and request necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Function to start scanning for gateways (with a 10-second timeout)
  void startScanningForGateways() async {
  if (isScanningForGateways) return;

  setState(() {
    isScanningForGateways = true;
    scanComplete = false;  // Reset the scan complete state
    gateways.clear();      // Clear any previous gateways before scanning
  });

  try {
    await MeshSdkManager.startProvisionMode();  // Start provisioning mode to scan

    // Start a 10-second scan
    Future.delayed(const Duration(seconds: 10), () async {
      await stopScanningForGateways();  // Stop the scan after 10 seconds
    });

    // Scan for gateways during the 10-second window
    List<Map<String, dynamic>> foundGateways = await MeshSdkManager.getGateways();

    // Print the list of gateways in the background
    if (foundGateways.isNotEmpty) {
      print("Gateways found:");
      for (var gateway in foundGateways) {
        print("Gateway MAC: ${gateway['macAddress']}, Name: ${gateway['name'] ?? 'Unknown'}");
      }
    } else {
      print("No gateways found.");
    }

    // Update the UI to display the gateways
    setState(() {
      gateways.addAll(
        foundGateways.map(
          (d) => MeshDevice.fromGatewayMap(d),
        ),
      );
    });
  } catch (e) {
    print("Error during gateway scanning: $e");
    _showErrorSnackBar('Failed to scan for gateways: ${e.toString()}');
  }
}


  // Stop scanning for gateways
  Future<void> stopScanningForGateways() async {
    try {
      await MeshSdkManager.stopProvisionMode();  // Stop provision mode after scanning
    } catch (e) {
      print("Error stopping provision mode: $e");
    } finally {
      setState(() {
        isScanningForGateways = false;  // Mark scanning as finished
        scanComplete = true;            // Mark scan as complete
      });
    }
  }

  // Show error messages as a snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Mesh Scanner'),
      ),
      body: Center(
        child: isScanningForGateways
            ? const CircularProgressIndicator()  // Show loading indicator while scanning
            : scanComplete
                ? gateways.isNotEmpty
                    ? Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: gateways.length,
                              itemBuilder: (context, index) {
                                final gateway = gateways[index];
                                return ListTile(
                                  title: Text('Gateway Name: ${gateway.macAddress}'),
                                  subtitle: Text('MAC Address: ${gateway.macAddress}'),
                                );
                              },
                            ),
                          ),
                          ElevatedButton(
                            onPressed: startScanningForGateways,  // Restart scanning
                            child: const Text('Scan Again'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const Text('No gateways found.'),
                          ElevatedButton(
                            onPressed: startScanningForGateways,  // Restart scanning
                            child: const Text('Scan Again'),
                          ),
                        ],
                      )
                : ElevatedButton(
                    onPressed: startScanningForGateways,  // Button to start scanning
                    child: const Text('Start Scanning'),
                  ),
      ),
    );
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








// import 'package:ble_testing/functions/some_functions.dart';
// import 'package:flutter/material.dart';
// import 'package:ble_testing/functions/mesh_sdk_manager.dart';
// import 'package:permission_handler/permission_handler.dart';

// class BleMeshScannerTesting extends StatefulWidget {
//   const BleMeshScannerTesting({super.key});

//   @override
//   _BleMeshScannerTestingState createState() => _BleMeshScannerTestingState();
// }

// class _BleMeshScannerTestingState extends State<BleMeshScannerTesting> {
//   List<MeshDevice> devices = [];
//   bool isScanning = false;

//   @override
//   void initState() {
//     super.initState();
//     someFunction();

//     // _initializeScanning();
//   }

//   Future<void> _initializeScanning() async {
//     bool hasPermissions = true;
//     if (hasPermissions) {
//       startScanning();
//     }
//   }
//   void provisionGateway() async {
//   try {
//     // Start provision mode before scanning
//     await MeshSdkManager.startProvisionMode();

//     // Scan for gateways
//     List<Map<String, dynamic>> gateways = await MeshSdkManager.getGateways();
    
//     if (gateways.isNotEmpty) {
//       String macAddress = gateways.first['macAddress'];
//       // Provision the first found gateway
//       bool success = await MeshSdkManager.provisionGateway(macAddress);
      
//       if (success) {
//         print('Gateway provisioned successfully with MAC: $macAddress');
//       } else {
//         print('Failed to provision gateway');
//       }
//     } else {
//       print('No gateways found');
//     }
    
//     // Stop provision mode after scanning/provisioning
//     await MeshSdkManager.stopProvisionMode();
//   } catch (e) {
//     print('Error during gateway provisioning: $e');
//   }
// }


//   Future<bool> _checkAndRequestPermissions() async {
//     Map<Permission, PermissionStatus> statuses = await [
//       Permission.bluetooth,
//       Permission.location,
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//     ].request();

//     return statuses.values.every((status) => status.isGranted);
//   }

//   void startScanning() async {
//     if (isScanning) return;

//     setState(() {
//       isScanning = true;
//       devices.clear();
//     });

//     try {
//       await MeshSdkManager.startProvisionMode();

//       List<Map<String, dynamic>> factoryDevices =
//           await MeshSdkManager.getFactoryMeshDevices();
//       List<Map<String, dynamic>> provisionedDevices =
//           await MeshSdkManager.getProvisionedMeshDevices();
//       List<Map<String, dynamic>> gateways = await MeshSdkManager.getGateways();

//       setState(() {
//         devices.addAll(
//             factoryDevices.map((d) => MeshDevice.fromMap(d, isFactory: true)));
//         devices.addAll(provisionedDevices
//             .map((d) => MeshDevice.fromMap(d, isFactory: false)));
//         devices.addAll(gateways.map((d) => MeshDevice.fromGatewayMap(d)));
//       });
//     } catch (e) {
//       print("Error during scanning: $e");
//       _showErrorSnackBar('Failed to start scanning: ${e.toString()}');
//     } finally {
//       setState(() {
//         isScanning = false;
//       });
//     }
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   Future<void> provisionDevice(MeshDevice device) async {
//     try {
//       // For simplicity, we're using fixed values for meshAddress and groupAddress
//       // In a real application, you'd want to manage these addresses properly
//       bool success =
//           await MeshSdkManager.provisionDevice(device.macAddress, 1, 32769);
//       if (success) {
//         _showErrorSnackBar('Device provisioned successfully');
//         startScanning(); // Refresh the list
//       } else {
//         _showErrorSnackBar('Failed to provision device');
//       }
//     } catch (e) {
//       print("Error during device provisioning: $e");
//       _showErrorSnackBar('Error during provisioning: ${e.toString()}');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: const Text('BLE Mesh Scanner'),
//           actions: [
//             IconButton(
//               icon: Icon(isScanning ? Icons.stop : Icons.refresh),
//               onPressed: isScanning ? null : startScanning,
//             ),
//           ],
//         ),
//         body: Center(
//           child: ElevatedButton(
//             child: const Text('Hello'),
//             onPressed: () {
//               someFunction();
//               provisionDevice(MeshDevice(
//                   macAddress: '08:D1:F9:1E:D9:76',
//                   // "D8:13:2A:2C:E8:A6",
//                   isProvisioned: false,
//                   isGateway: false));
//             },
//           ),
//         ));
//   }
// }

// class MeshDevice {
//   final String macAddress;
//   final bool isProvisioned;
//   final bool isGateway;

//   MeshDevice({
//     required this.macAddress,
//     required this.isProvisioned,
//     required this.isGateway,
//   });

//   factory MeshDevice.fromMap(Map<String, dynamic> map,
//       {required bool isFactory}) {
//     return MeshDevice(
//       macAddress: map['macAddress'] as String? ?? '',
//       isProvisioned: !isFactory,
//       isGateway: false,
//     );
//   }

//   factory MeshDevice.fromGatewayMap(Map<String, dynamic> map) {
//     return MeshDevice(
//       macAddress: map['macAddress'] as String? ?? '',
//       isProvisioned: true,
//       isGateway: true,
//     );
//   }
// }
