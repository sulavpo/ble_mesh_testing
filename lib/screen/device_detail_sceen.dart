import 'package:ble_testing/controller/ble_manager.dart';
import 'package:flutter/material.dart';

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
  Map<String, dynamic>? deviceCapabilities;

  @override
  void initState() {
    super.initState();
    connectToDevice();
    _setupBleListeners();
  }

  void _setupBleListeners() {
    _bleManager.onProvisioningComplete = (capabilities) {
      setState(() {
        deviceCapabilities = capabilities;
        connectionStatus = 'Provisioning completed successfully.';
      });
      showCapabilitiesDialog();
    };

    _bleManager.onError = (error) {
      setState(() {
        connectionStatus = 'Error: $error';
      });
      showErrorDialog(error);
    };

    _bleManager.onProvisioningStateChanged = (state) {
      setState(() {
        connectionStatus = 'Provisioning state: ${state['state']}';
      });
    };
  }

  Future<void> connectToDevice() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      await _bleManager.connect(widget.device['address']);
      setState(() {
        isConnecting = false;
        isConnected = true; // Assume connection is successful
        connectionStatus = isConnected ? 'Connected' : 'Connection failed';
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connectionStatus = 'Connection error: $e';
      });
    }
  }

  Future<void> startProvisioning() async {
    try {
      await _bleManager.provisionDevice(widget.device['address']);
      setState(() {
        connectionStatus = 'Provisioning started...';
      });
    } catch (e) {
      setState(() {
        connectionStatus = 'Provisioning error: $e';
      });
      showErrorDialog(e.toString());
    }
  }

  void showCapabilitiesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Device Capabilities'),
          content: deviceCapabilities != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Number of Elements: ${deviceCapabilities!['numberOfElements']}'),
                    Text('Algorithms: ${deviceCapabilities!['algorithms']}'),
                    Text('Public Key Type: ${deviceCapabilities!['publicKeyType']}'),
                    Text('Static OOB Type: ${deviceCapabilities!['staticOobType']}'),
                    Text('Output OOB Size: ${deviceCapabilities!['outputOobSize']}'),
                    Text('Output OOB Actions: ${deviceCapabilities!['outputOobActions']}'),
                    Text('Input OOB Size: ${deviceCapabilities!['inputOobSize']}'),
                    Text('Input OOB Actions: ${deviceCapabilities!['inputOobActions']}'),
                  ],
                )
              : const Text('No capabilities data available'),
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
            Text('Status: ${widget.device['provisioningServiceUuid'] == '1827' ? 'UnProvisioned' : 'Provisioned'}'),
            const SizedBox(height: 20),
            Text('Connection Status: $connectionStatus'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnected ? startProvisioning : null,
              child: const Text('Identify'),
            ),
          ],
        ),
      ),
    );
  }
}
