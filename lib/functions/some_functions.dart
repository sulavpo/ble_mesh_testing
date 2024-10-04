import 'package:ble_testing/functions/mesh_sdk_manager.dart';

void someFunction() async {
  try {
    print('Updating mesh username and password...');
    await MeshSdkManager.updateMeshUserNameAndPassword('Test', '1234');

    print('Starting provision mode...');
    await MeshSdkManager.startProvisionMode();

    print('Getting factory mesh devices...');
    List<Map<String, dynamic>> factoryDevices =
        await MeshSdkManager.getFactoryMeshDevices();
    for (var device in factoryDevices) {
      print('Found device: ${MeshDevice.fromMap(device).macAddress}');
    }
    print('Provisioning device: 08:D1:F9:1E:D9:76');
    bool provisionSuccess =
        await MeshSdkManager.provisionDevice('08:D1:F9:1E:D9:76', 1, 32769);
    if (provisionSuccess) {
      print('Device provisioned successfully');

      print('Sending "On" command...');
      bool commandSuccess =
          await MeshSdkManager.sendCommand(1, 'On', {'delay': 0});
      if (commandSuccess) {
        print('Command sent successfully');
      } else {
        print('Failed to send command');
      }
    } else {
      print('Failed to provision device');
    }

    if (factoryDevices.isNotEmpty) {
      String macToProvision = factoryDevices.first['macAddress'];

      if (provisionSuccess) {
        print('Device provisioned successfully');

        print('Sending "On" command...');
        bool commandSuccess =
            await MeshSdkManager.sendCommand(1, 'On', {'delay': 0});
        if (commandSuccess) {
          print('Command sent successfully');
        } else {
          print('Failed to send command');
        }
      } else {
        print('Failed to provision device');
      }

      print('Sending multiple commands...');
      List<MeshCommand> commands = [
        BlinkCommand(delay: 0),
        OnCommand(delay: 2000),
        OffCommand(delay: 2000),
        BrightnessCommand(brightness: 50, delay: 2000),
      ];

      bool multiCommandSuccess = await MeshSdkManager.connectAndSendCommand(
        macToProvision,
        commands.map((c) => c.toMap()).toList(),
      );
      if (multiCommandSuccess) {
        print('Multiple commands sent successfully');
      } else {
        print('Failed to send multiple commands');
      }
    }
  } catch (e) {
    print('Error in someFunction: $e');
  }
}
