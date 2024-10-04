import 'dart:async'; // Import for Timer
import 'dart:developer';
import 'package:ble_testing/controller/ble_manager.dart';
import 'package:ble_testing/screen/device_detail_sceen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BleScanner extends StatefulWidget {
  const BleScanner({super.key});

  @override
  _BleScannerState createState() => _BleScannerState();
}

class _BleScannerState extends State<BleScanner> {
  final BleManager _bleManager = BleManager(); // Instantiate BleManager
  List<Map<String, dynamic>> devices = [];
  bool isScanning = false;
  Timer? _scanTimer; // Timer to stop scan after 10 seconds

  @override
  void initState() {
    super.initState();

    // Set callbacks from BleManager
    _bleManager.onDeviceFound = (device) {
      // Check if the device is already in the list
      if (devices.any((d) => d['address'] == device['address'])) return;

      setState(() {
        devices.add(device);
      });
    };

    _bleManager.onError = (error) {
      log('Error: $error');
      _showAlertDialog(title: 'Error', content: error);
    };
  }

  Future<void> startScan() async {
    setState(() {
      isScanning = true; // Indicate that scanning has started
      devices.clear(); // Clear the previous device list
    });

    try {
      await _bleManager.startScan();

      // Set a timer to stop scanning after 10 seconds
      _scanTimer = Timer(const Duration(seconds: 10), () {
        stopScan();
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
      await _bleManager.stopScan();
    } catch (e) {
      print("Failed to stop scan: '$e'.");
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
                        // trailing: device['isMesh']
                        //     ? Text(device['provisioningServiceUuid'] == '1827'
                        //         ? 'UnProvisioned'
                        //         : 'Provisioned')
                        //     : null,
                        // leading: Icon(
                        //   device['isMesh']
                        //       ? Icons.network_wifi
                        //       : Icons.bluetooth,
                        //   color: device['isMesh'] ? Colors.green : Colors.blue,
                        // ),
                        title: Text(device['device']),
                        subtitle: Text(device['device']),
                        onTap: () {
                          if (device['isMesh']) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DeviceDetailScreen(device: device),
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
