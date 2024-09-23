import 'package:ble_testing/controller/ble_controller.dart';
import 'package:ble_testing/controller/ble_mesh_provisioning_controller.dart';
import 'package:ble_testing/screen/bluetooth_off_screen.dart';
import 'package:ble_testing/screen/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  final BleController controller = Get.put(BleController());
  final BleMeshProvisioningController controllerProvisioning = Get.put(BleMeshProvisioningController());


  @override
  void initState() {
    super.initState();
    controller.initBle();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.bluetoothOn.value
        ? ScannerScreen(controller: controller
        ,controllerProvisioning: controllerProvisioning,
        )
        : BluetoothOffScreen(controller: controller));
  }
}
