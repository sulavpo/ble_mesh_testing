import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/mesh_device.dart';
import '../models/mesh_network.dart';

class MeshTopologyService {
  static final MeshTopologyService _instance = MeshTopologyService._internal();
  factory MeshTopologyService() => _instance;
  MeshTopologyService._internal();

  // Topology state
  final RxList<MeshDevice> topology = <MeshDevice>[].obs;
  final Rx<TopologyState> topologyState = TopologyState.idle.obs;
  final Rx<MeshDevice?> targetDevice = Rx<MeshDevice?>(null);

  BluetoothCharacteristic? _dataInCharacteristic;
  BluetoothCharacteristic? _dataOutCharacteristic;
  StreamSubscription? _dataOutSubscription;

  // Initialize the service
  Future<MeshTopologyService> init() async {
    return this;
  }

  // Fetch mesh topology
  Future<void> fetchTopology(MeshDevice device) async {
    try {
      topologyState.value = TopologyState.fetching;
      targetDevice.value = device;

      // Connect to device
      await device.device.connect();

      // Discover services
      final services = await device.device.discoverServices();
      final topologyService = services.firstWhere(
        (service) =>
            service.uuid.toString().toUpperCase() == MESH_TOPOLOGY_SERVICE_UUID,
      );

      // Get characteristics
      _dataInCharacteristic = topologyService.characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == MESH_TOPOLOGY_DATA_IN_UUID,
      );
      _dataOutCharacteristic = topologyService.characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == MESH_TOPOLOGY_DATA_OUT_UUID,
      );

      // Enable notifications
      await _dataOutCharacteristic?.setNotifyValue(true);
      _dataOutSubscription = _dataOutCharacteristic?.onValueReceived
          .listen(_handleTopologyResponse);

      // Request topology
      await _requestTopology();
    } catch (e) {
      topologyState.value = TopologyState.error;
      targetDevice.value = null;
      rethrow;
    }
  }

  // Request topology
  Future<void> _requestTopology() async {
    try {
      final requestData = _createTopologyRequest();
      await _dataInCharacteristic?.write(requestData);
    } catch (e) {
      topologyState.value = TopologyState.error;
      rethrow;
    }
  }

  // Handle topology response
  void _handleTopologyResponse(List<int> value) {
    try {
      // Parse response
      final opcode = value[0];
      switch (opcode) {
        case 0x01: // Topology Data
          final devices = _parseTopologyData(value);
          topology.value = devices;
          topologyState.value = TopologyState.idle;
          _cleanup();
          break;
        case 0x02: // Topology Error
          topologyState.value = TopologyState.error;
          _cleanup();
          break;
      }
    } catch (e) {
      topologyState.value = TopologyState.error;
      _cleanup();
    }
  }

  // Parse topology data
  List<MeshDevice> _parseTopologyData(List<int> data) {
    // TODO: Implement topology data parsing
    return [];
  }

  // Create topology request
  List<int> _createTopologyRequest() {
    // TODO: Implement topology request creation
    return [];
  }

  // Add device to topology
  void addDevice(MeshDevice device) {
    if (!topology.any((d) => d.id == device.id)) {
      topology.add(device);
    }
  }

  // Remove device from topology
  void removeDevice(String deviceId) {
    topology.removeWhere((device) => device.id == deviceId);
  }

  // Update device in topology
  void updateDevice(MeshDevice device) {
    final index = topology.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      topology[index] = device;
    }
  }

  // Get device by ID
  MeshDevice? getDeviceById(String deviceId) {
    return topology.firstWhereOrNull((device) => device.id == deviceId);
  }

  // Get devices by parent
  List<MeshDevice> getDevicesByParent(String parentAddress) {
    return topology
        .where((device) => device.parentAddress == parentAddress)
        .toList();
  }

  // Get devices by layer
  List<MeshDevice> getDevicesByLayer(int layer) {
    return topology.where((device) => device.meshLayer == layer).toList();
  }

  // Cleanup
  void _cleanup() {
    _dataOutSubscription?.cancel();
    _dataInCharacteristic = null;
    _dataOutCharacteristic = null;
    targetDevice.value = null;
  }

  // Dispose
  void dispose() {
    _cleanup();
    topology.clear();
    topologyState.value = TopologyState.idle;
  }
}

enum TopologyState {
  idle,
  fetching,
  error,
}

// UUIDs
const String MESH_TOPOLOGY_SERVICE_UUID = '1829';
const String MESH_TOPOLOGY_DATA_IN_UUID = '2ADD';
const String MESH_TOPOLOGY_DATA_OUT_UUID = '2ADE';
