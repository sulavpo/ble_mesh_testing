
import 'package:ble_testing/functions/mesh_sdk_manager.dart';

void someFunction() async {
  try {
    await MeshSdkManager.updateMeshUserNameAndPassword('Test', '1234');
    await MeshSdkManager.startProvisionMode();
    
    List<Map<String, dynamic>> factoryDevices = await MeshSdkManager.getFactoryMeshDevices();
    for (var device in factoryDevices) {
      print('Found device: ${MeshDevice.fromMap(device).macAddress}');
    }
    
    bool provisionSuccess = await MeshSdkManager.provisionDevice('08:D1:F9:1E:D9:76', 1, 32769);
    if (provisionSuccess) {
      print('Device provisioned successfully');
      
      bool commandSuccess = await MeshSdkManager.sendCommand(1, 'On', {'delay': 0});
      if (commandSuccess) {
        print('Command sent successfully');
      }
    }
    
    List<MeshCommand> commands = [
      BlinkCommand(delay: 0),
      OnCommand(delay: 2000),
      OffCommand(delay: 2000),
      BrightnessCommand(brightness: 50, delay: 2000),
    ];
    
    bool multiCommandSuccess = await MeshSdkManager.connectAndSendCommand(
      '08:D1:F9:1E:D9:76',
      commands.map((c) => c.toMap()).toList(),
    );
    if (multiCommandSuccess) {
      print('Multiple commands sent successfully');
    }
  } catch (e) {
    print('Error: $e');
  }
}