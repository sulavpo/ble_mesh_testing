import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/mesh_device.dart';

class LANDeviceDiscoveryService {
  static final LANDeviceDiscoveryService _instance =
      LANDeviceDiscoveryService._internal();
  factory LANDeviceDiscoveryService() => _instance;
  LANDeviceDiscoveryService._internal();

  // LAN discovery state
  final RxList<MeshDevice> discoveredDevices = <MeshDevice>[].obs;
  final Rx<DiscoveryState> discoveryState = DiscoveryState.idle.obs;
  Timer? _discoveryTimer;
  RawDatagramSocket? _socket;

  // Initialize the service
  Future<LANDeviceDiscoveryService> init() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;
      return this;
    } catch (e) {
      discoveryState.value = DiscoveryState.error;
      rethrow;
    }
  }

  // Start discovering devices
  Future<void> startDiscovery() async {
    try {
      discoveryState.value = DiscoveryState.discovering;
      discoveredDevices.clear();

      // Send discovery message
      final message = _createDiscoveryMessage();
      _socket?.send(message, InternetAddress('255.255.255.255'), 1900);

      // Listen for responses
      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            final device = _parseDeviceResponse(datagram);
            if (device != null &&
                !discoveredDevices.any((d) => d.id == device.id)) {
              discoveredDevices.add(device);
            }
          }
        }
      });

      // Set timeout
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer(const Duration(seconds: 10), () {
        stopDiscovery();
      });
    } catch (e) {
      discoveryState.value = DiscoveryState.error;
      rethrow;
    }
  }

  // Stop discovering devices
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _socket?.close();
    discoveryState.value = DiscoveryState.idle;
  }

  // Create discovery message
  List<int> _createDiscoveryMessage() {
    // This is a placeholder - actual implementation depends on your device's protocol
    return 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nST: urn:schemas-upnp-org:device:Basic:1\r\n\r\n'
        .codeUnits;
  }

  // Parse device response
  MeshDevice? _parseDeviceResponse(Datagram datagram) {
    try {
      final response = String.fromCharCodes(datagram.data);
      // This is a placeholder - actual implementation depends on your device's protocol
      final lines = response.split('\r\n');
      String? name;
      String? address;
      int rssi = 0;

      for (final line in lines) {
        if (line.startsWith('LOCATION:')) {
          final uri = Uri.parse(line.substring(9).trim());
          address = uri.host;
        } else if (line.startsWith('SERVER:')) {
          name = line.substring(7).trim();
        }
      }

      if (name != null && address != null) {
        // Create a dummy BluetoothDevice for LAN devices
        final dummyDevice = BluetoothDevice.fromId('lan:$address');
        return MeshDevice(
          id: const Uuid().v4(),
          name: name,
          address: address,
          rssi: rssi,
          device: dummyDevice,
          deviceInfo: {
            'protocol': 'LAN',
            'port': datagram.port,
          },
        );
      }
    } catch (e) {
      // Handle parsing error
    }
    return null;
  }

  // Cleanup
  void dispose() {
    stopDiscovery();
    discoveredDevices.clear();
  }
}

enum DiscoveryState {
  idle,
  discovering,
  error,
}
