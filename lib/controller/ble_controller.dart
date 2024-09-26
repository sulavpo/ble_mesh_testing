import 'dart:async';
import 'dart:io' show Platform;
import 'package:ble_testing/model/ble_mesh_group.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'ble_mesh_node.dart';

class BleController extends GetxController {
  RxList<ScanResult> meshNodes = <ScanResult>[].obs;
  RxBool isScanning = false.obs;
  RxBool bluetoothOn = false.obs;
  RxList<BleMeshGroup> meshGroups = <BleMeshGroup>[].obs;
  Timer? _scanTimer;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  Future<void> initBle() async {
    await checkBluetoothState();
    _listenToAdapterStateChanges();
  }

  Future<void> checkBluetoothState() async {
    bluetoothOn.value = await FlutterBluePlus.isOn;
  }

  void _listenToAdapterStateChanges() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      bluetoothOn.value = state == BluetoothAdapterState.on;
    });
  }

  Future<void> toggleBluetooth() async {
    if (bluetoothOn.value) {
      showPlatformSpecificNotification(
        'Info',
        'Please turn off Bluetooth in system settings.',
      );
    } else {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        showPlatformSpecificNotification(
          'Error',
          'Failed to turn on Bluetooth. Please enable it manually.',
        );
      }
    }
  }

  Future<void> scanForMeshDevices() async {
    if (!bluetoothOn.value) {
      showPlatformSpecificNotification('Error', 'Bluetooth is turned off');
      return;
    }

    if (!await _requestPermissions()) {
      showPlatformSpecificNotification(
          'Error', 'Bluetooth permissions not granted');
      return;
    }

    meshNodes.clear();
    isScanning.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Add ScanResult to meshNodes if it's not already added
          if (!meshNodes.any((node) => node.device.id == r.device.id)) {
            meshNodes.add(r);
          }
        }
        print('Mesh nodes found: ${meshNodes.length}');
      });

      // FlutterBluePlus.scanResults.listen((results) {
      //   for (ScanResult r in results) {
      //     // if (isMeshDevice(r) &&
      //     //     !meshNodes.any((node) => node.id == r.device.id.id)) {
      //       meshNodes.add(ScanResult(r.device.id.id, r.device.name));
      //     // }
      //   }
      //   print('Mesh nodes found: ${meshNodes.length}');
      // });

      _scanTimer = Timer(const Duration(seconds: 10), () {
        stopScan();
      });
    } catch (e) {
      print('Error during mesh scan: $e');
      showPlatformSpecificNotification(
          'Error', 'An error occurred during mesh scanning');
      stopScan();
    }
  }

  bool isMeshDevice(ScanResult result, bool isProvising) {
    if (result.advertisementData.serviceUuids.isEmpty) {
      return false;
    }

    const String meshProvisioningServiceUuid = '1827';
    const String meshProxyServiceUuid = '1828';

    bool hasMeshServiceUuid;
    if (isProvising) {
      hasMeshServiceUuid = result.advertisementData.serviceUuids.any((guid) {
        String uuidStr = guid.str;
        return uuidStr == meshProxyServiceUuid;
      });
    } else {
      hasMeshServiceUuid = result.advertisementData.serviceUuids.any((guid) {
        String uuidStr = guid.str;
        return uuidStr == meshProvisioningServiceUuid ||
            uuidStr == meshProxyServiceUuid;
      });
    }

    // bool hasServiceData = result.advertisementData.serviceData
    //     .containsKey(meshProvisioningServiceUuid);
// if(isProvising){
//     return hasMeshServiceUuid || hasServiceData;

// }else{

    return hasMeshServiceUuid;

// }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    isScanning.value = false;
    _scanTimer?.cancel();
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Future<void> provisionMeshNode(ScanResult node) async {
  //   try {
  //     await Future.delayed(
  //         const Duration(seconds: 2));
  //     node.isProvisioned = true;
  //     showPlatformSpecificNotification(
  //         'Success', 'Node provisioned: ${node.id}');
  //   } catch (e) {
  //     print('Error provisioning node: $e');
  //     showPlatformSpecificNotification(
  //         'Error', 'Failed to provision node: ${node.id}');
  //   }
  // }

  void createMeshGroup(String groupName) {
    BleMeshGroup newGroup = BleMeshGroup(groupName, []);
    meshGroups.add(newGroup);
  }

  void addNodeToGroup(ScanResult node, BleMeshGroup group) {
    if (!group.nodes.contains(node)) {
      group.nodes.add(node);
    }
  }

  void publishToGroup(BleMeshGroup group, String message) {
    print('Publishing "$message" to group: ${group.name}');
  }

  void showPlatformSpecificNotification(String title, String message) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: Get.context!,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void onClose() {
    stopScan();
    _adapterStateSubscription?.cancel();
    super.onClose();
  }
}
