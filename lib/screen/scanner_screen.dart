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