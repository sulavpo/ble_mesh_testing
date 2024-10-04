import 'package:ble_testing/functions/mesh_sdk_manager.dart';
import 'package:flutter/material.dart';

void someFunction(BuildContext context) async {
  try {
    // Initialize the CNMeshMethodChannel with the context
    CNMeshMethodChannel.instance.configureChannel(context);

    print('Starting scan for devices...');
    bool scanStarted = await CNMeshMethodChannel.instance.startScanDevices(true);
    if (!scanStarted) {
      print('Failed to start scanning for devices.');
      return;
    }

    // After scanning, retrieve factory devices
    print('Getting factory mesh devices...');
    bool factoryDevicesRetrieved = await CNMeshMethodChannel.instance.getFactoryDevices();
    
    if (factoryDevicesRetrieved) {
      print('Factory devices retrieved successfully.');
      // You should handle displaying the devices to the user here

      // For demonstration, we'll assume you want to provision a specific device.
      String macToProvision = '08:D1:F9:1E:D9:76';  // Replace with actual mac address from devices
      int groupAddress = 1;
      print('Provisioning device: $macToProvision');
      int provisionResult = await CNMeshMethodChannel.instance.provisionDevice(macToProvision, groupAddress);

      if (provisionResult != 0) {
        print('Device provisioned successfully.');

        // Send a command to turn on the light
        print('Sending "On" command...');
        bool lightOn = await CNMeshMethodChannel.instance.lightOn(provisionResult);
        if (lightOn) {
          print('Light turned on successfully.');
        } else {
          print('Failed to turn on the light.');
        }

        // Optionally, you can send other commands, like multiple commands.
        print('Sending multiple commands...');

        // Example commands:
        bool brightnessSet = await CNMeshMethodChannel.instance.brightness(provisionResult, 50);
        bool colorSet = await CNMeshMethodChannel.instance.color(provisionResult, 255, 0, 0);  // Red color
        bool sceneLoaded = await CNMeshMethodChannel.instance.loadScene(1);  // Loading scene 1, for example

        if (brightnessSet && colorSet && sceneLoaded) {
          print('Multiple commands sent successfully.');
        } else {
          print('Failed to send multiple commands.');
        }

      } else {
        print('Failed to provision device.');
      }
    } else {
      print('Failed to retrieve factory devices.');
    }

  } catch (e) {
    print('Error in someFunction: $e');
  }
}
