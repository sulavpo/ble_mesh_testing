import 'package:flutter/material.dart';

class DeviceScanScreen extends StatelessWidget {
  const DeviceScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Advertiser')),
      body: const Center(
        child: Text('This screen is now reserved for advertising controls.'),
      ),
    );
  }
}
