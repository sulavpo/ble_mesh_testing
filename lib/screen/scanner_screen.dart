import 'dart:io';

import 'package:ble_testing/controller/ble_controller.dart';
import 'package:ble_testing/controller/ble_mesh_provisioning_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class ScannerScreen extends StatefulWidget {
  final BleController controller;
  final BleMeshProvisioningController controllerProvisioning;

  const ScannerScreen({
    super.key,
    required this.controller,
    required this.controllerProvisioning,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE MESH SCANNER"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: widget.controller.toggleBluetooth,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Obx(() {
                if (widget.controllerProvisioning.isProvisioning.value) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Provisioning: Step ${widget.controllerProvisioning.provisioningStep.value} of 5',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_getStepDescription(widget.controllerProvisioning.provisioningStep.value)),
                      ],
                    ),
                  );
                } 
               else if (widget.controller.isScanning.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black38,
                    ),
                  );
                } else if (widget.controller.meshNodes.isEmpty) {
                  return const Center(child: Text("No Mesh Nodes Found"));
                } else {
                  return ListView.builder(
                    itemCount: widget.controller.meshNodes.length,
                    itemBuilder: (context, index) {
                      final node = widget.controller.meshNodes[index];
                      return GestureDetector(
                        onLongPress: () => _showProvisionDialog(context, node),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                widget.controller.isMeshDevice(widget.controller.meshNodes[index], false)
                                    ? Image.asset(
                                        "assets/networking.png",
                                        width: 50,
                                        height: 50,
                                      )
                                    : Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Center(child: Icon(Icons.bluetooth)),
                                        ),
                                      ),
                                Expanded(
                                  child: ListTile(
                                    title: Text(
                                      node.advertisementData.advName.isNotEmpty
                                          ? node.advertisementData.advName
                                          : "Unknown Node",
                                    ),
                                    subtitle: Text(node.device.remoteId.toString()),
                                    trailing: Text(
                                      widget.controller.isMeshDevice(widget.controller.meshNodes[index], true)
                                          ? "Provisioned"
                                          : "Unprovisioned",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              }),
            ),
            const SizedBox(height: 10),
            Obx(() => ElevatedButton(
                  onPressed: widget.controller.isScanning.value
                      ? null
                      : widget.controller.scanForMeshDevices,
                  child: Text(widget.controller.isScanning.value
                      ? 'Scanning...'
                      : 'Scan for Mesh Nodes'),
                )),
          ],
        ),
      ),
    );
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 1:
        return "Beaconing";
      case 2:
        return "Invitation";
      case 3:
        return "Exchanging Public Keys";
      case 4:
        return "Authentication";
      case 5:
        return "Distributing Provisioning Data";
      default:
        return "";
    }
  }

  void _showProvisionDialog(BuildContext context, ScanResult node) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Provision Node'),
          content: Text('Do you want to provision ${node.advertisementData.advName}?'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.controllerProvisioning.startProvisioning(node.device);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Provision Node'),
          content: Text('Do you want to provision ${node.advertisementData.advName}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.controllerProvisioning.startProvisioning(node.device);
              },
            ),
          ],
        ),
      );
    }
  }
}


// import 'dart:async';
// import 'dart:io';
// import 'package:ble_testing/controller/ble_mesh_provisioning_controller.dart';
// import 'package:ble_testing/widget/mesh_network_data_widget.dart';
// import 'package:ble_testing/widget/mesh_network_database_widget.dart';
// import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
// // import 'package:nordic_nrf_mesh_example/src/widgets/mesh_network_widget.dart';
// import 'package:ble_testing/controller/ble_controller.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:get/get.dart';

// class ScannerScreen extends StatefulWidget {
//   final BleController controller;
//   final BleMeshProvisioningController controllerProvisioning;
//     // final NordicNrfMesh nordicNrfMesh;

//   const ScannerScreen({
//     super.key,
//     required this.controller,
//     required this.controllerProvisioning,
//     // required this.nordicNrfMesh
//   });

//   @override
//   State<ScannerScreen> createState() => _ScannerScreenState();
// }

// class _ScannerScreenState extends State<ScannerScreen> {
//   // late IMeshNetwork? meshNetwork;
//   // late final MeshManagerApi _meshManagerApi;
//   // late final StreamSubscription<IMeshNetwork?> onNetworkUpdateSubscription;
//   // late final StreamSubscription<IMeshNetwork?> onNetworkImportSubscription;
//   // late final StreamSubscription<IMeshNetwork?> onNetworkLoadingSubscription;


//    @override
//   void initState() {
//     super.initState();
//     _meshManagerApi = widget.nordicNrfMesh.meshManagerApi;
//     meshNetwork = _meshManagerApi.meshNetwork;
//     onNetworkUpdateSubscription = _meshManagerApi.onNetworkUpdated.listen((event) {
//       setState(() {
//         meshNetwork = event;
//       });
//     });
//     onNetworkImportSubscription = _meshManagerApi.onNetworkImported.listen((event) {
//       setState(() {
//         meshNetwork = event;
//       });
//     });
//     onNetworkLoadingSubscription = _meshManagerApi.onNetworkLoaded.listen((event) {
//       setState(() {
//         meshNetwork = event;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     onNetworkUpdateSubscription.cancel();
//     onNetworkLoadingSubscription.cancel();
//     onNetworkImportSubscription.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE MESH SCANNER"),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.bluetooth),
//             onPressed: widget.controller.toggleBluetooth,
//           ),
//         ],
//       ),
//       body:ListView(
//         children: [
//           // PlatformVersion(nordicNrfMesh: widget.nordicNrfMesh),
//           ExpansionTile(
//             title: const Text('Mesh network database'),
//             expandedAlignment: Alignment.topLeft,
//             children: [MeshNetworkDatabaseWidget(nordicNrfMesh: widget.nordicNrfMesh)],
//           ),
//           // ExpansionTile(
//           //   title: const Text('Mesh network manager'),
//           //   expandedAlignment: Alignment.topLeft,
//           //   children: [MeshNetworkManagerWidget(nordicNrfMesh: widget.nordicNrfMesh)],
//           // ),
//           const Divider(),
//           if (meshNetwork != null)
//             MeshNetworkDataWidget(meshNetwork: meshNetwork!)
//           else
//             const Text('No meshNetwork loaded'),
//         ],
//       ),
//     );
//   }

//   String _getStepDescription(int step) {
//     switch (step) {
//       case 1:
//         return "Beaconing";
//       case 2:
//         return "Invitation";
//       case 3:
//         return "Exchanging Public Keys";
//       case 4:
//         return "Authentication";
//       case 5:
//         return "Distributing Provisioning Data";
//       default:
//         return "";
//     }
//   }

//   void _showProvisionDialog(BuildContext context, ScanResult node) {
//     if (Platform.isIOS) {
//       showCupertinoDialog(
//         context: context,
//         builder: (BuildContext context) => CupertinoAlertDialog(
//           title: const Text('Provision Node'),
//           content: Text('Do you want to provision ${node.advertisementData.advName}?'),
//           actions: <CupertinoDialogAction>[
//             CupertinoDialogAction(
//               child: const Text('No'),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//             CupertinoDialogAction(
//               child: const Text('Yes'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 widget.controllerProvisioning.startProvisioning(node.device);
//               },
//             ),
//           ],
//         ),
//       );
//     } else {
//       showDialog(
//         context: context,
//         builder: (BuildContext context) => AlertDialog(
//           title: const Text('Provision Node'),
//           content: Text('Do you want to provision ${node.advertisementData.advName}?'),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('No'),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//             TextButton(
//               child: const Text('Yes'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 widget.controllerProvisioning.startProvisioning(node.device);
//               },
//             ),
//           ],
//         ),
//       );
//     }
//   }
// }


