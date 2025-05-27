import 'package:flutter/material.dart';
import 'package:ble_testing/controller/ble_manager.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final BleManager _bleManager = BleManager();
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = '';
  String provisioningStatus = '';
  List<String> provisioningLogs = [];
  Uint8List? receivedCapabilities;
  Uint8List? receivedPublicKey;
  Uint8List? receivedConfirmation;
  Uint8List? receivedRandom;

  // Provisioning state management
  bool isProvisioningInProgress = false;
  bool isProvisioningComplete = false;

  @override
  void initState() {
    super.initState();
    setupBleCallbacks();
  }

  void setupBleCallbacks() {
    _bleManager.onConnectionStateChange = (state) {
      setState(() {
        isConnected = state == 'connected';
        connectionStatus = state;
        addLog('Connection state changed: $state');
      });
    };

    _bleManager.onProvisioningServiceFound = () {
      setState(() {
        provisioningStatus = 'Provisioning service found';
        addLog('Provisioning service found');
      });
    };

    _bleManager.onProvisioningCapabilities = (capabilities) {
      setState(() {
        receivedCapabilities = capabilities;
        provisioningStatus = 'Received capabilities';
        addLog('Received capabilities: ${_bytesToHex(capabilities)}');
      });
      // Automatically send provisioning start after capabilities are received
      sendProvisioningStart();
    };

    _bleManager.onProvisioningPublicKey = (publicKey) {
      setState(() {
        receivedPublicKey = publicKey;
        provisioningStatus = 'Received public key';
        addLog('Received public key: ${_bytesToHex(publicKey)}');
      });

      // Generate and send public key
      sendDummyPublicKey();
    };

    _bleManager.onProvisioningConfirmation = (confirmation) {
      setState(() {
        receivedConfirmation = confirmation;
        provisioningStatus = 'Received confirmation';
        addLog('Received confirmation: ${_bytesToHex(confirmation)}');
      });

      // Send our confirmation
      sendDummyConfirmation();
    };

    _bleManager.onProvisioningRandom = (random) {
      setState(() {
        receivedRandom = random;
        provisioningStatus = 'Received random';
        addLog('Received random: ${_bytesToHex(random)}');
      });

      // Send our random
      sendDummyRandom();
    };

    _bleManager.onProvisioningComplete = () {
      setState(() {
        provisioningStatus = 'Provisioning complete';
        isProvisioningInProgress = false;
        isProvisioningComplete = true;
        addLog('Provisioning complete');
      });
    };

    _bleManager.onProvisioningFailed = (errorCode) {
      setState(() {
        provisioningStatus = 'Provisioning failed: Error code $errorCode';
        isProvisioningInProgress = false;
        addLog('Provisioning failed: Error code $errorCode');
      });
      showErrorDialog('Provisioning failed: Error code $errorCode');
    };

    _bleManager.onCharacteristicWrite = (result) {
      addLog('Characteristic write result: $result');
    };

    _bleManager.onError = (error) {
      addLog('Error: $error');
      showErrorDialog(error);
    };
  }

  void addLog(String log) {
    setState(() {
      provisioningLogs.add('${DateTime.now().toString().substring(11, 19)}: $log');
      if (provisioningLogs.length > 100) {
        provisioningLogs.removeAt(0);
      }
    });
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}')
        .join(', ');
  }

  Future<void> connectToDevice() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
      addLog('Connecting to device: ${widget.device['address']}');
    });

    try {
      await _bleManager.connect(widget.device['address']);
    } catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connectionStatus = 'Connection error: $e';
        addLog('Connection error: $e');
      });
    }
  }

  Future<void> disconnectFromDevice() async {
    setState(() {
      connectionStatus = 'Disconnecting...';
      addLog('Disconnecting from device: ${widget.device['address']}');
    });

    try {
      await _bleManager.disconnect();
      setState(() {
        isConnected = false;
        connectionStatus = 'disconnected';
        isProvisioningInProgress = false;
        addLog('Disconnected from device');
      });
    } catch (e) {
      setState(() {
        addLog('Disconnect error: $e');
      });
      showErrorDialog('Disconnect error: $e');
    }
  }

  Future<void> startProvisioning() async {
    setState(() {
      provisioningStatus = 'Starting provisioning...';
      isProvisioningInProgress = true;
      addLog('Starting provisioning');
    });

    try {
      await _bleManager.startProvisioning(widget.device['address']);
      // After connection is established, send the invitation
      await sendProvisioningInvite();
    } catch (e) {
      setState(() {
        provisioningStatus = 'Provisioning failed: $e';
        isProvisioningInProgress = false;
        addLog('Provisioning failed: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendProvisioningInvite() async {
    setState(() {
      provisioningStatus = 'Sending provisioning invite...';
      addLog('Sending provisioning invite with attention duration of 5 seconds');
    });

    try {
      await _bleManager.sendProvisioningInvite(5);
      addLog('Provisioning invite sent');
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send provisioning invite: $e';
        addLog('Failed to send provisioning invite: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendProvisioningStart() async {
    setState(() {
      provisioningStatus = 'Sending provisioning start...';
      addLog('Sending provisioning start');
    });

    try {
      await _bleManager.sendProvisioningStart();
      addLog('Provisioning start sent');
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send provisioning start: $e';
        addLog('Failed to send provisioning start: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendDummyPublicKey() async {
    setState(() {
      provisioningStatus = 'Sending public key...';
      addLog('Sending public key');
    });

    try {
      final dummyPublicKey = generateRandomBytes(64);
      addLog('Generated public key: ${_bytesToHex(dummyPublicKey)}');

      await _bleManager.sendProvisioningPublicKey(dummyPublicKey);
      addLog('Public key sent');
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send public key: $e';
        addLog('Failed to send public key: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendDummyConfirmation() async {
    setState(() {
      provisioningStatus = 'Sending confirmation...';
      addLog('Sending confirmation');
    });

    try {
      final dummyConfirmation = generateRandomBytes(16);
      addLog('Generated confirmation: ${_bytesToHex(dummyConfirmation)}');

      await _bleManager.sendProvisioningConfirmation(dummyConfirmation);
      addLog('Confirmation sent');
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send confirmation: $e';
        addLog('Failed to send confirmation: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendDummyRandom() async {
    setState(() {
      provisioningStatus = 'Sending random...';
      addLog('Sending random');
    });

    try {
      final dummyRandom = generateRandomBytes(16);
      addLog('Generated random: ${_bytesToHex(dummyRandom)}');

      await _bleManager.sendProvisioningRandom(dummyRandom);
      addLog('Random sent');

      Future.delayed(const Duration(milliseconds: 500), () {
        sendDummyProvisioningData();
      });
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send random: $e';
        addLog('Failed to send random: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Future<void> sendDummyProvisioningData() async {
    setState(() {
      provisioningStatus = 'Sending provisioning data...';
      addLog('Sending provisioning data');
    });

    try {
      final dummyProvisioningData = generateRandomBytes(32);
      addLog('Generated provisioning data: ${_bytesToHex(dummyProvisioningData)}');

      await _bleManager.sendProvisioningData(dummyProvisioningData);
      addLog('Provisioning data sent');
    } catch (e) {
      setState(() {
        provisioningStatus = 'Failed to send provisioning data: $e';
        addLog('Failed to send provisioning data: $e');
      });
      showErrorDialog(e.toString());
    }
  }

  Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${widget.device['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Address: ${widget.device['address']}'),
                    Text('Is Mesh Device: ${widget.device['isMesh'] == true ? 'Yes' : 'No'}'),
                    if (widget.device['provisioningServiceUuid'] != null)
                      Text('Provisioning Service UUID: ${widget.device['provisioningServiceUuid']}'),
                    Row(
                      children: [
                        const Text('Status: '),
                        Text(
                          isProvisioningComplete
                              ? 'Provisioned'
                              : (widget.device['provisioningServiceUuid'] == '1827' ? 'Unprovisioned' : 'Unknown'),
                          style: TextStyle(
                              color: isProvisioningComplete
                                  ? Colors.green
                                  : (widget.device['provisioningServiceUuid'] == '1827' ? Colors.red : Colors.orange),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Connection Status: '),
                        Text(
                          connectionStatus,
                          style: TextStyle(
                              color: isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Provisioning Status: '),
                        Expanded(
                          child: Text(
                            provisioningStatus,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isConnected && !isProvisioningInProgress && !isProvisioningComplete
                      ? startProvisioning
                      : null,
                  child: const Text('Start Provisioning'),
                ),
                ElevatedButton(
                  onPressed: isConnecting ? null : (isConnected ? disconnectFromDevice : connectToDevice),
                  child: Text(isConnected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Provisioning Logs',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.clear_all),
                            onPressed: () {
                              setState(() {
                                provisioningLogs.clear();
                              });
                            },
                            tooltip: 'Clear logs',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: ListView.builder(
                            itemCount: provisioningLogs.length,
                            itemBuilder: (context, index) {
                              return Text(
                                provisioningLogs[index],
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}