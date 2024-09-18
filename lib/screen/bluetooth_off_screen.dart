
import 'package:ble_testing/controller/ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BluetoothOffScreen extends StatelessWidget {
  final BleController controller;

  const BluetoothOffScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            const Text(
              'Bluetooth Adapter is Off',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            Obx(() => Switch(
                  value: controller.bluetoothOn.value,
                  onChanged: (bool value) => controller.toggleBluetooth(),
                )),
          ],
        ),
      ),
    );
  }
}
