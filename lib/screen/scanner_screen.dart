import 'dart:io';

import 'package:ble_testing/controller/ble_controller.dart';
import 'package:ble_testing/model/ble_node_group.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class ScannerScreen extends StatefulWidget {
  final BleController controller;

  const ScannerScreen({super.key, required this.controller});

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
              child: Obx(() => widget.controller.isScanning.value
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: Colors.black38,
                    ))
                  : (widget.controller.meshNodes.isEmpty
                      ? const Center(child: Text("No Mesh Nodes Found"))
                      : ListView.builder(
                          itemCount: widget.controller.meshNodes.length,
                          itemBuilder: (context, index) {
                            final node = widget.controller.meshNodes[index];
                            return GestureDetector(
                              onLongPress: () =>
                                  _showProvisionDialog(context, node),
                              child: Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      widget.controller.isMeshDevice(
                                              widget
                                                  .controller.meshNodes[index],
                                              false)
                                          ? Image.asset(
                                              "assets/networking.png",
                                              width: 50,
                                              height: 50,
                                            )
                                          : Container(
                                              decoration: const BoxDecoration(
                                                  color: Colors.grey,
                                                  shape: BoxShape.circle),
                                              child: const Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Center(
                                                    child:
                                                        Icon(Icons.bluetooth)),
                                              )),
                                      Expanded(
                                        child: ListTile(
                                          // contentPadding: const EdgeInsets.all(5),
                                          title: Text(node.advertisementData
                                                  .advName.isNotEmpty
                                              ? node.advertisementData.advName
                                              : "Unknown Node"),
                                          subtitle: Text(
                                              node.device.remoteId.toString()),
                                          trailing: Text(widget.controller
                                                  .isMeshDevice(
                                                      widget.controller
                                                          .meshNodes[index],
                                                      true)
                                              ? "Provisioned"
                                              : "Unprovisioned"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ))),
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

  void _showProvisionDialog(BuildContext context, ScanResult node) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Provision Node'),
          content: Text(
              'Do you want to provision ${node.advertisementData.advName}?'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                // widget.controller.provisionMeshNode(node);
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
          content: Text(
              'Do you want to provision ${node.advertisementData.advName}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                // widget.controller.provisionMeshNode(node);
              },
            ),
          ],
        ),
      );
    }
  }
}
