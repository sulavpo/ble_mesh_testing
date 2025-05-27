import 'package:get/get.dart';
import '../models/mesh_device.dart';

class DeviceInfoService extends GetxService {
  final Rx<MeshDevice?> selectedDevice = Rx<MeshDevice?>(null);
  final RxList<MeshDevice> deviceInfoList = <MeshDevice>[].obs;
  final RxBool isLoading = false.obs;

  Future<DeviceInfoService> init() async {
    // Any initialization if needed
    return this;
  }

  Future<void> fetchDeviceInfo(MeshDevice device) async {
    isLoading.value = true;
    // Placeholder: Replace with actual device info fetch logic (e.g., via LAN or BLE)
    await Future.delayed(const Duration(seconds: 1));
    selectedDevice.value = device;
    isLoading.value = false;
  }

  Future<void> fetchDevicesInfo(List<MeshDevice> devices) async {
    isLoading.value = true;
    // Placeholder: Replace with actual batch info fetch logic
    await Future.delayed(const Duration(seconds: 2));
    deviceInfoList.value = devices;
    isLoading.value = false;
  }
}
