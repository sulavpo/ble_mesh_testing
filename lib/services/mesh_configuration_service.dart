import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mesh_network.dart';
import '../models/mesh_device.dart';

class MeshConfigurationService extends GetxService {
  static final MeshConfigurationService _instance =
      MeshConfigurationService._internal();
  factory MeshConfigurationService() => _instance;
  MeshConfigurationService._internal();

  static const String MESH_CONFIGURATION_SERVICE_UUID = '1828';
  static const String MESH_CONFIGURATION_DATA_IN_UUID = '2ADB';
  static const String MESH_CONFIGURATION_DATA_OUT_UUID = '2ADC';

  final Rx<MeshNetwork?> currentNetwork = Rx<MeshNetwork?>(null);
  final RxList<MeshNetwork> savedNetworks = <MeshNetwork>[].obs;
  final Rx<ConfigurationState> configurationState = ConfigurationState.idle.obs;
  final Rx<MeshDevice?> targetDevice = Rx<MeshDevice?>(null);
  final RxBool isInitialized = false.obs;

  BluetoothCharacteristic? _dataInCharacteristic;
  BluetoothCharacteristic? _dataOutCharacteristic;
  StreamSubscription? _dataOutSubscription;
  SharedPreferences? _prefs;

  Future<MeshConfigurationService> init() async {
    if (!isInitialized.value) {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedNetworks();
      isInitialized.value = true;
    }
    return this;
  }

  Future<void> _ensureInitialized() async {
    if (!isInitialized.value) {
      await init();
    }
  }

  Future<void> _loadSavedNetworks() async {
    try {
      savedNetworks.clear();
      final networksJson = _prefs?.getStringList('saved_networks') ?? [];
      savedNetworks.value = networksJson
          .map((id) {
            final jsonString = _prefs?.getString(id);
            if (jsonString == null) return null;
            final map = jsonDecode(jsonString) as Map<String, dynamic>;
            return MeshNetwork.fromJson(map);
          })
          .whereType<MeshNetwork>()
          .toList();
    } catch (e) {
      configurationState.value = ConfigurationState.error;
      rethrow;
    }
  }

  Future<void> saveNetwork(MeshNetwork network) async {
    await _ensureInitialized();
    try {
      configurationState.value = ConfigurationState.saving;
      final networkJson = network.toJson();
      await _prefs?.setString(network.id, jsonEncode(networkJson));
      final networks = _prefs?.getStringList('saved_networks') ?? [];
      if (!networks.contains(network.id)) {
        networks.add(network.id);
        await _prefs?.setStringList('saved_networks', networks);
      }
      if (!savedNetworks.any((n) => n.id == network.id)) {
        savedNetworks.add(network);
      }
      configurationState.value = ConfigurationState.idle;
    } catch (e) {
      configurationState.value = ConfigurationState.error;
      rethrow;
    }
  }

  Future<void> deleteNetwork(String networkId) async {
    try {
      configurationState.value = ConfigurationState.deleting;
      await _prefs?.remove(networkId);
      final networks = _prefs?.getStringList('saved_networks') ?? [];
      networks.remove(networkId);
      await _prefs?.setStringList('saved_networks', networks);
      savedNetworks.removeWhere((network) => network.id == networkId);
      configurationState.value = ConfigurationState.idle;
    } catch (e) {
      configurationState.value = ConfigurationState.error;
      rethrow;
    }
  }

  Future<void> configureDevice(MeshDevice device, MeshNetwork network) async {
    try {
      configurationState.value = ConfigurationState.configuring;
      targetDevice.value = device;
      currentNetwork.value = network;

      await device.device.connect();

      final services = await device.device.discoverServices();
      final configService = services.firstWhere(
        (service) => service.uuid
            .toString()
            .toUpperCase()
            .contains(MESH_CONFIGURATION_SERVICE_UUID),
        orElse: () => throw Exception('Mesh configuration service not found'),
      );

      _dataInCharacteristic = configService.characteristics.firstWhere(
        (c) => c.uuid
            .toString()
            .toUpperCase()
            .contains(MESH_CONFIGURATION_DATA_IN_UUID),
        orElse: () => throw Exception('Data In characteristic not found'),
      );

      _dataOutCharacteristic = configService.characteristics.firstWhere(
        (c) => c.uuid
            .toString()
            .toUpperCase()
            .contains(MESH_CONFIGURATION_DATA_OUT_UUID),
        orElse: () => throw Exception('Data Out characteristic not found'),
      );

      await _dataOutCharacteristic!.setNotifyValue(true);
      _dataOutSubscription = _dataOutCharacteristic!.lastValueStream
          .listen(_handleConfigurationData);

      final configData = _createConfigurationData(network);
      await _dataInCharacteristic!.write(configData);

      configurationState.value = ConfigurationState.idle;
      targetDevice.value = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting configuration: $e');
      }
      configurationState.value = ConfigurationState.error;
      targetDevice.value = null;
      rethrow;
    }
  }

  List<int> _createConfigurationData(MeshNetwork network) {
    // TODO: Implement configuration data creation
    return [];
  }

  void _handleConfigurationData(List<int> data) {
    if (data.isEmpty) return;

    final opcode = data[0];
    switch (opcode) {
      case 0x01: // Configuration Capabilities
        _handleConfigurationCapabilities(data);
        break;
      case 0x02: // Configuration Start
        _handleConfigurationStart(data);
        break;
      case 0x03: // Configuration Data
        _handleConfigurationDataMessage(data);
        break;
      case 0x04: // Configuration Complete
        _handleConfigurationComplete();
        break;
      case 0x05: // Configuration Failed
        _handleConfigurationFailed(data);
        break;
    }
  }

  void _handleConfigurationCapabilities(List<int> data) {
    configurationState.value = ConfigurationState.capabilitiesReceived;
  }

  void _handleConfigurationStart(List<int> data) {
    configurationState.value = ConfigurationState.started;
  }

  void _handleConfigurationDataMessage(List<int> data) {
    configurationState.value = ConfigurationState.dataReceived;
  }

  void _handleConfigurationComplete() {
    configurationState.value = ConfigurationState.completed;
    _cleanup();
  }

  void _handleConfigurationFailed(List<int> data) {
    configurationState.value = ConfigurationState.failed;
    _cleanup();
  }

  void _cleanup() {
    _dataOutSubscription?.cancel();
    _dataOutSubscription = null;
    _dataInCharacteristic = null;
    _dataOutCharacteristic = null;
  }

  MeshNetwork? getNetworkById(String networkId) {
    return savedNetworks.firstWhereOrNull((network) => network.id == networkId);
  }

  MeshNetwork? getNetworkByName(String name) {
    return savedNetworks.firstWhereOrNull((network) => network.name == name);
  }

  void dispose() {
    currentNetwork.value = null;
    savedNetworks.clear();
    configurationState.value = ConfigurationState.idle;
    targetDevice.value = null;
  }

  // Clear all saved networks and their data
  Future<void> clearAllNetworks() async {
    await _ensureInitialized();
    await _prefs?.clear(); // Wipe all keys
    savedNetworks.clear();
    currentNetwork.value = null;
  }
}

enum ConfigurationState {
  idle,
  saving,
  deleting,
  configuring,
  started,
  capabilitiesReceived,
  dataReceived,
  completed,
  failed,
  error,
}
