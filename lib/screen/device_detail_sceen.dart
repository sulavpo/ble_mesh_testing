import 'package:flutter/material.dart';
import 'package:ble_testing/controller/ble_manager.dart';
import 'dart:typed_data';

class DeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final BleManager _bleManager = BleManager();
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = '';
  String provisioningStatus = '';

  @override
  void initState() {
    super.initState();
    connectToDevice();
    setupBleCallbacks();
  }

  void setupBleCallbacks() {
    _bleManager.onConnectionStateChange = (state) {
      setState(() {
        isConnected = state == 'connected';
        connectionStatus = state;
      });
    };

    _bleManager.onProvisioningServiceFound = () {
      setState(() {
        provisioningStatus = 'Provisioning service found';
      });
    };

    _bleManager.onProvisioningCapabilities = (capabilities) {
      setState(() {
        provisioningStatus = 'Received capabilities: ${capabilities.toString()}';
      });
      // Process capabilities here
    };

    _bleManager.onProvisioningPublicKey = (publicKey) {
      setState(() {
        provisioningStatus = 'Received public key: ${publicKey.toString()}';
      });
      // Process public key here
    };

    _bleManager.onProvisioningConfirmation = (confirmation) {
      setState(() {
        provisioningStatus = 'Received confirmation: ${confirmation.toString()}';
      });
      // Process confirmation here
    };

    _bleManager.onProvisioningRandom = (random) {
      setState(() {
        provisioningStatus = 'Received random: ${random.toString()}';
      });
      // Process random here
    };

    _bleManager.onProvisioningComplete = () {
      setState(() {
        provisioningStatus = 'Provisioning complete';
      });
    };

    _bleManager.onProvisioningFailed = (errorData) {
      setState(() {
        provisioningStatus = 'Provisioning failed: ${errorData.toString()}';
      });
      showErrorDialog('Provisioning failed: ${errorData.toString()}');
    };

    _bleManager.onError = (error) {
      showErrorDialog(error);
    };
  }

  Future<void> connectToDevice() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      await _bleManager.connect(widget.device['address']);
    } catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connectionStatus = 'Connection error: $e';
      });
    }
  }

  Future<void> startProvisioning() async {
    setState(() {
      provisioningStatus = 'Starting provisioning...';
    });

    try {
      await _bleManager.startProvisioning(widget.device['address']);
      // After starting provisioning, send the invitation
      await sendProvisioningInvite();
    } catch (e) {
      setState(() {
        provisioningStatus = 'Provisioning failed: $e';
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendProvisioningInvite() async {
    setState(() {
      provisioningStatus = 'Sending provisioning invite...';
    });

    try {
      // Send a provisioning invite with an attention duration of 5 seconds
      await _bleManager.sendProvisioningInvite(5);
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send provisioning invite: $e';
      });
      showErrorDialog(e.toString());
    }
  }

  void showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${widget.device['name']}'),
            Text('Address: ${widget.device['address']}'),
            Text('Provisioning Service UUID: ${widget.device['provisioningServiceUuid']}'),
            Text('Status: ${widget.device['provisioningServiceUuid'] == '1827' ? 'Unprovisioned' : 'Provisioned'}'),
            const SizedBox(height: 20),
            Text('Connection Status: $connectionStatus'),
            const SizedBox(height: 20),
            Text('Provisioning Status: $provisioningStatus'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnected ? startProvisioning : null,
              child: const Text('Start Provisioning'),
            ),
          ],
        ),
      ),
    );
  }
}