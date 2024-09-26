import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  static const platform = MethodChannel('com.example.ble_scanner/ble');
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = '';
  Map<String, dynamic>? deviceCapabilities;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  Future<void> connectToDevice() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      final result = await platform.invokeMethod('connectToDevice', {'address': widget.device['address']});
      setState(() {
        isConnecting = false;
        isConnected = result;
        connectionStatus = isConnected ? 'Connected' : 'Connection failed';
      });
    } on PlatformException catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connectionStatus = 'Connection error: ${e.message}';
      });
    }
  }

  Future<void> startProvisioning() async {
    try {
      final capabilities = await platform.invokeMethod('startProvisioning', {'address': widget.device['address']});
      setState(() {
        deviceCapabilities = capabilities;
      });

      showCapabilitiesDialog();  // Show capabilities in a dialog
    } on PlatformException catch (e) {
      print('Provisioning error: ${e.message}');
      showErrorDialog(e.message); // Handle provisioning errors
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
              : Text('No capabilities data available'),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showErrorDialog(String? errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(errorMessage ?? 'An error occurred'),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
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
            SizedBox(height: 20),
            Text('Connection Status: $connectionStatus'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnected ? startProvisioning : null,
              child: Text('Identify'),
            ),
          ],
        ),
      ),
    );
  }
}








// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class DeviceDetailScreen extends StatefulWidget {
//   final Map<String, dynamic> device;

//   const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

//   @override
//   _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
// }

// class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
//   static const platform = MethodChannel('com.example.ble_scanner/ble');
//   bool isConnecting = false;
//   bool isConnected = false;
//   String connectionStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     connectToDevice();
//   }

//   Future<void> connectToDevice() async {
//     setState(() {
//       isConnecting = true;
//       connectionStatus = 'Connecting...';
//     });

//     try {
//       final result = await platform.invokeMethod('connectToDevice', {'address': widget.device['address']});
//       setState(() {
//         isConnecting = false;
//         isConnected = result;
//         connectionStatus = isConnected ? 'Connected' : 'Connection failed';
//       });
//     } on PlatformException catch (e) {
//       setState(() {
//         isConnecting = false;
//         isConnected = false;
//         connectionStatus = 'Connection error: ${e.message}';
//       });
//     }
//   }

//   Future<void> startProvisioning() async {
//     try {
//       final capabilities = await platform.invokeMethod('startProvisioning', {'address': widget.device['address']});
//       // Handle the capabilities response
//       print('Device capabilities: $capabilities');
//       // You can update the UI or navigate to a new screen to show the capabilities
//     } on PlatformException catch (e) {
//       print('Provisioning error: ${e.message}');
//       // Show an error dialog or update the UI to indicate the error
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.device['name']),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Name: ${widget.device['name']}'),
//             Text('Address: ${widget.device['address']}'),
//             Text('Provisioning Service UUID: ${widget.device['provisioningServiceUuid']}'),
//             Text('Status: ${widget.device['provisioningServiceUuid'] == '1827' ? 'UnProvisioned' : 'Provisioned'}'),
//             SizedBox(height: 20),
//             Text('Connection Status: $connectionStatus'),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: isConnected ? startProvisioning : null,
//               child: Text('Identify'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }