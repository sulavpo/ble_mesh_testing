import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../models/mesh_network.dart';
import '../models/mesh_device.dart';

class MeshMessageService {
  static final MeshMessageService _instance = MeshMessageService._internal();
  factory MeshMessageService() => _instance;
  MeshMessageService._internal();

  // Message service state
  final Rx<MeshNetwork?> currentNetwork = Rx<MeshNetwork?>(null);
  final Rx<MeshDevice?> targetDevice = Rx<MeshDevice?>(null);
  final Rx<MessageState> messageState = MessageState.idle.obs;
  final RxList<MeshDevice> availableDevices = <MeshDevice>[].obs;

  // BLE characteristics
  BluetoothCharacteristic? _proxyDataIn;
  BluetoothCharacteristic? _proxyDataOut;
  StreamSubscription<List<int>>? _dataOutSubscription;

  // Initialize the service
  Future<void> init() async {
    // Load saved network if any
    // TODO: Implement persistence
  }

  // Send message to device
  Future<bool> sendMessage(
    MeshDevice device,
    Map<String, dynamic> message,
  ) async {
    try {
      messageState.value = MessageState.sending;
      targetDevice.value = device;

      // Discover services and characteristics
      final services = await device.device.discoverServices();
      final proxyService = services.firstWhere(
        (s) => s.uuid == _proxyServiceUuid,
        orElse: () => throw Exception('Proxy service not found'),
      );

      _proxyDataIn = proxyService.characteristics.firstWhere(
        (c) => c.uuid == _proxyDataInUuid,
        orElse: () => throw Exception('Data In characteristic not found'),
      );

      _proxyDataOut = proxyService.characteristics.firstWhere(
        (c) => c.uuid == _proxyDataOutUuid,
        orElse: () => throw Exception('Data Out characteristic not found'),
      );

      // Subscribe to data out characteristic
      _dataOutSubscription?.cancel();
      _dataOutSubscription =
          _proxyDataOut!.onValueReceived.listen(_handleResponse);

      // Send message
      final encryptedMessage = _encryptMessage(message);
      await _proxyDataIn!.write(encryptedMessage);

      messageState.value = MessageState.sent;
      return true;
    } catch (e) {
      messageState.value = MessageState.error;
      return false;
    }
  }

  // Handle response from device
  void _handleResponse(List<int> data) {
    try {
      final decryptedData = _decryptMessage(data);
      // Process response based on opcode
      final opcode = decryptedData['opcode'];
      switch (opcode) {
        case 0x8202: // Status response
          _handleStatusResponse(decryptedData);
          break;
        case 0x8246: // Brightness response
          _handleBrightnessResponse(decryptedData);
          break;
        default:
          // Handle unknown opcode
          break;
      }
      messageState.value = MessageState.received;
    } catch (e) {
      messageState.value = MessageState.error;
    }
  }

  // Handle status response
  void _handleStatusResponse(Map<String, dynamic> data) {
    if (targetDevice.value != null) {
      final device = targetDevice.value!;
      final isOn = data['data']['on'] as bool;
      availableDevices[availableDevices.indexOf(device)] =
          device.copyWith(isOn: isOn);
    }
  }

  // Handle brightness response
  void _handleBrightnessResponse(Map<String, dynamic> data) {
    if (targetDevice.value != null) {
      final device = targetDevice.value!;
      final brightness = data['data']['brightness'] as int;
      availableDevices[availableDevices.indexOf(device)] =
          device.copyWith(brightness: brightness);
    }
  }

  // Encrypt message
  List<int> _encryptMessage(Map<String, dynamic> message) {
    // TODO: Implement message encryption
    return [];
  }

  // Decrypt message
  Map<String, dynamic> _decryptMessage(List<int> data) {
    // TODO: Implement message decryption
    return {};
  }

  // Cleanup
  void dispose() {
    _dataOutSubscription?.cancel();
    _proxyDataIn = null;
    _proxyDataOut = null;
    messageState.value = MessageState.idle;
    targetDevice.value = null;
  }
}

enum MessageState {
  idle,
  sending,
  sent,
  received,
  failed,
  error,
}

// UUIDs for mesh proxy service and characteristics
const _proxyServiceUuid = '00001827-0000-1000-8000-00805f9b34fb';
const _proxyDataInUuid = '00002add-0000-1000-8000-00805f9b34fb';
const _proxyDataOutUuid = '00002ade-0000-1000-8000-00805f9b34fb';
