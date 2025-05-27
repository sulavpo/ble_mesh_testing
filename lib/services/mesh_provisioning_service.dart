import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../models/mesh_device.dart';
import '../models/mesh_network.dart';
import 'package:pointycastle/export.dart';

// Helper for AES-CMAC using pointycastle
Uint8List aesCmac(Uint8List key, Uint8List message) {
  final cmac = CMac(AESEngine(), 16);
  cmac.init(KeyParameter(key));
  cmac.update(message, 0, message.length);
  final out = Uint8List(16);
  cmac.doFinal(out, 0);
  return out;
}

class MeshProvisioningService {
  static final MeshProvisioningService _instance =
      MeshProvisioningService._internal();
  factory MeshProvisioningService() => _instance;
  MeshProvisioningService._internal();

  // Provisioning state
  final Rx<MeshDevice?> targetDevice = Rx<MeshDevice?>(null);
  final Rx<ProvisioningState> provisioningState = ProvisioningState.idle.obs;
  final RxInt provisioningProgress = 0.obs;

  BluetoothCharacteristic? _dataInCharacteristic;
  BluetoothCharacteristic? _dataOutCharacteristic;
  StreamSubscription? _dataOutSubscription;

  // ECDH key pair and shared secret
  SimpleKeyPair? _ecdhKeyPair;
  List<int>? _publicKeyBytes; // 64 bytes (X || Y)
  List<int>? _devicePublicKeyBytes;
  List<int>? _sharedSecret;

  // Add state variables for confirmation and random
  List<int>? _provisionerRandom;
  List<int>? _provisionerConfirmation;
  List<int>? _deviceConfirmation;

  // Initialize the service
  Future<MeshProvisioningService> init() async {
    return this;
  }

  // Start provisioning
  Future<void> startProvisioning(MeshDevice device, MeshNetwork network) async {
    const int maxRetries = 3;
    int attempt = 0;
    bool connected = false;
    Exception? lastError;

    while (attempt < maxRetries && !connected) {
      attempt++;
      try {
        await device.device.connect(autoConnect: false).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            device.device.disconnect();
            throw Exception('Connection timed out');
          },
        );
        connected = true;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        await Future.delayed(const Duration(seconds: 1));
        await device.device.disconnect();
      }
    }

    if (!connected) {
      throw lastError ??
          Exception('Failed to connect to device after $maxRetries attempts');
    }

    try {
      provisioningState.value = ProvisioningState.starting;
      targetDevice.value = device;
      provisioningProgress.value = 0;

      // Discover services
      final services = await device.device.discoverServices();
      final provisioningService = services.firstWhere(
        (service) =>
            service.uuid.toString().toUpperCase() ==
            MESH_PROVISIONING_SERVICE_UUID,
      );

      // Print all characteristics and their properties for debugging
      for (final c in provisioningService.characteristics) {
        if (kDebugMode) {
          print('Characteristic: \\${c.uuid}, properties: \\${c.properties}');
        }
      }
      // Find the characteristic with the correct UUID and WRITE property
      _dataInCharacteristic = provisioningService.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toUpperCase() == MESH_PROVISIONING_DATA_IN_UUID &&
            (c.properties.write || c.properties.writeWithoutResponse),
        orElse: () => throw Exception('Data In characteristic not writable'),
      );
      _dataOutCharacteristic = provisioningService.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toUpperCase() == MESH_PROVISIONING_DATA_OUT_UUID,
      );

      // Enable notifications BEFORE sending Invite
      print('[PROVISION] Enabling notifications on Data Out characteristic...');
      await _dataOutCharacteristic?.setNotifyValue(true);
      _dataOutSubscription = _dataOutCharacteristic?.onValueReceived
          .listen(_handleProvisioningResponse);
      print(
          '[PROVISION] Notifications enabled. Waiting 200ms before sending Invite...');
      await Future.delayed(const Duration(milliseconds: 200));

      // Start the provisioning state machine
      await _provisioningStateMachine(network);
    } catch (e) {
      provisioningState.value = ProvisioningState.error;
      targetDevice.value = null;
      rethrow;
    }
  }

  // Provisioning state machine
  Future<void> _provisioningStateMachine(MeshNetwork network) async {
    try {
      // 1. Invite
      provisioningState.value = ProvisioningState.inProgress;
      provisioningProgress.value = (0.05 * 100).toInt();
      print('[PROVISION] Sending Invite PDU: [0x00, 0x00]');
      await _sendAndAwaitResponse([0x00, 0x00], 0x01,
          ProvisioningState.capabilitiesReceived, (0.2 * 100).toInt());

      // 2. Start (spec-compliant)
      final startPDU = [0x02, 0x00, 0x00, 0x00, 0x00, 0x00];
      print('[PROVISION] Sending Start PDU: $startPDU');
      await _sendAndAwaitResponse(
          startPDU, 0x02, ProvisioningState.startSent, (0.3 * 100).toInt());

      // 3. Public Key (real ECDH)
      await _generateEcdhKeyPair();
      print('[PROVISION] Sending Public Key PDU');
      // Wait for device public key and compute shared secret
      await _sendAndAwaitResponse([0x03, ..._publicKeyBytes!], 0x03,
          ProvisioningState.publicKeySent, (0.4 * 100).toInt(),
          expectDevicePublicKey: true);
      print('[PROVISION] Device Public Key received, shared secret computed.');

      // 4. Confirmation (real)
      await _generateProvisionerRandom();
      await _calculateProvisionerConfirmation();
      print('[PROVISION] Sending Confirmation PDU: [0x04, ...16 bytes]');
      await _sendAndAwaitResponse([0x04, ..._provisionerConfirmation!], 0x04,
          ProvisioningState.confirmationSent, (0.6 * 100).toInt(),
          expectDeviceConfirmation: true);
      print('[PROVISION] Device Confirmation received.');

      // 5. Random (real)
      print('[PROVISION] Sending Random PDU: [0x05, ...16 bytes]');
      await _sendAndAwaitResponse([0x05, ..._provisionerRandom!], 0x05,
          ProvisioningState.randomSent, (0.8 * 100).toInt());

      // 6. Data (stub)
      print('[PROVISION] Sending Data PDU: [0x06, 0x00]');
      await _sendAndAwaitResponse(
          [0x06, 0x00], 0x04, ProvisioningState.completed, 100);

      provisioningProgress.value = 100;
      _cleanup();
    } catch (e) {
      print('[PROVISION] Error in state machine: $e');
      provisioningState.value = ProvisioningState.failed;
      _cleanup();
      rethrow;
    }
  }

  // Generate ECDH key pair
  Future<void> _generateEcdhKeyPair() async {
    final algorithm = Ecdh.p256(length: 32);
    _ecdhKeyPair = await algorithm.newKeyPair() as SimpleKeyPair;
    final publicKey = await _ecdhKeyPair!.extractPublicKey();
    _publicKeyBytes = publicKey.bytes; // 64 bytes (X || Y)
  }

  // Generate a random value for the provisioner (16 bytes)
  Future<void> _generateProvisionerRandom() async {
    final random = Random.secure();
    _provisionerRandom = List<int>.generate(16, (_) => random.nextInt(256));
  }

  // Calculate the provisioner's confirmation value (AES-CMAC)
  Future<void> _calculateProvisionerConfirmation() async {
    // For demo: use all zeros for auth value (no OOB)
    final authValue = List<int>.filled(16, 0);
    final confirmationInputs = <int>[];
    confirmationInputs.addAll(_provisionerRandom!);
    confirmationInputs.addAll(authValue);
    final key = Uint8List.fromList(_sharedSecret!);
    final message = Uint8List.fromList(confirmationInputs);
    _provisionerConfirmation = aesCmac(key, message);
  }

  // Helper to send a PDU, wait for the expected response, retry up to 3 times
  Future<void> _sendAndAwaitResponse(List<int> pdu, int expectedOpcode,
      ProvisioningState nextState, int progress,
      {bool expectDevicePublicKey = false,
      bool expectDeviceConfirmation = false}) async {
    const maxRetries = 3;
    int attempt = 0;
    bool success = false;
    Exception? lastError;
    final completer = Completer<void>();
    StreamSubscription? sub;

    void responseHandler(List<int> value) async {
      if (value.isNotEmpty) {
        print(
            '[PROVISION] Received response opcode: 0x${value[0].toRadixString(16)}');
      }
      if (value.isNotEmpty && value[0] == expectedOpcode) {
        if (expectDevicePublicKey && value.length >= 65) {
          _devicePublicKeyBytes = value.sublist(1, 65);
          await _computeSharedSecret();
        }
        if (expectDeviceConfirmation && value.length >= 17) {
          _deviceConfirmation = value.sublist(1, 17);
        }
        success = true;
        completer.complete();
      } else if (value.isNotEmpty && value[0] == 0x09) {
        // Failed PDU
        final errorCode = value[1];
        final errorMessage = _getProvisioningFailureMessage(errorCode);
        print(
            '[PROVISION] Received Failed PDU: $errorMessage (code: 0x${errorCode.toRadixString(16)})');
        completer.completeError(Exception(errorMessage));
      }
    }

    while (attempt < maxRetries && !success) {
      attempt++;
      print(
          '[PROVISION] Attempt $attempt: Sending PDU: $pdu, waiting for opcode 0x${expectedOpcode.toRadixString(16)}');
      sub = _dataOutCharacteristic?.onValueReceived.listen(responseHandler);
      await _writeProvisioningPDU(pdu);
      try {
        await completer.future.timeout(const Duration(seconds: 10));
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('[PROVISION] Timeout or error on attempt $attempt: $e');
      }
      await sub?.cancel();
      if (!success) {
        print('[PROVISION] Retrying after 1 second...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (!success) {
      print(
          '[PROVISION] Failed to receive expected response opcode 0x${expectedOpcode.toRadixString(16)} after $maxRetries attempts');
      throw lastError ??
          Exception('Provisioning step failed after $maxRetries attempts');
    }
    provisioningState.value = nextState;
    provisioningProgress.value = progress;
  }

  // Compute shared secret using ECDH
  Future<void> _computeSharedSecret() async {
    if (_ecdhKeyPair == null || _devicePublicKeyBytes == null) return;
    final algorithm = Ecdh.p256(length: 32);
    final devicePublicKey =
        SimplePublicKey(_devicePublicKeyBytes!, type: KeyPairType.p256);
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: _ecdhKeyPair!,
      remotePublicKey: devicePublicKey,
    );
    _sharedSecret = await sharedSecret.extractBytes();
  }

  // Handle provisioning response and step through the state machine
  void _handleProvisioningResponse(List<int> value) async {
    try {
      final opcode = value[0];
      switch (opcode) {
        case 0x01: // Capabilities
          provisioningState.value = ProvisioningState.capabilitiesReceived;
          provisioningProgress.value = 20;
          await _sendStartPDU();
          break;
        case 0x02: // Start
          provisioningState.value = ProvisioningState.startSent;
          provisioningProgress.value = 30;
          await _sendPublicKeyPDU();
          break;
        case 0x03: // Public Key
          provisioningState.value = ProvisioningState.publicKeySent;
          provisioningProgress.value = 40;
          // TODO: Continue with Confirmation, Random, Data, etc.
          break;
        case 0x04: // Provisioning Complete
          provisioningState.value = ProvisioningState.completed;
          provisioningProgress.value = 100;
          _cleanup();
          break;
        case 0x05: // Provisioning Failed
          provisioningState.value = ProvisioningState.failed;
          _cleanup();
          break;
        default:
          provisioningState.value = ProvisioningState.unknown;
          break;
      }
    } catch (e) {
      provisioningState.value = ProvisioningState.error;
      _cleanup();
    }
  }

  // Send Start PDU (stub)
  Future<void> _sendStartPDU() async {
    // Example: [0x02, ...] (Start PDU, fill with real data as needed)
    final startPDU = [0x02, 0x00];
    await _writeProvisioningPDU(startPDU);
  }

  // Send Public Key PDU (stub)
  Future<void> _sendPublicKeyPDU() async {
    // Example: [0x03, ...] (Public Key PDU, fill with real data as needed)
    final publicKeyPDU = [0x03, 0x00];
    await _writeProvisioningPDU(publicKeyPDU);
  }

  // Helper to write a provisioning PDU (with header and chunking)
  Future<void> _writeProvisioningPDU(List<int> pdu) async {
    final proxyPDU = Uint8List.fromList([0x03] + pdu);
    const int chunkSize = 20;
    for (int i = 0; i < proxyPDU.length; i += chunkSize) {
      final chunk = proxyPDU.sublist(i,
          (i + chunkSize > proxyPDU.length) ? proxyPDU.length : i + chunkSize);
      await _dataInCharacteristic?.write(
        chunk,
        withoutResponse:
            _dataInCharacteristic?.properties.writeWithoutResponse ?? false,
      );
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  // Create provisioning data (Invite PDU for step 1)
  List<int> _createProvisioningData(MeshNetwork network) {
    // Invite PDU: [0x00, 0x00] (Invite, Attention Timer = 0)
    return [0x00, 0x00];
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
    provisioningState.value = ProvisioningState.idle;
    provisioningProgress.value = 0;
  }

  String _getProvisioningFailureMessage(int errorCode) {
    switch (errorCode) {
      case 0x00:
        return "Prohibited";
      case 0x01:
        return "Invalid PDU";
      case 0x02:
        return "Invalid format";
      case 0x03:
        return "Unexpected PDU";
      case 0x04:
        return "Confirmation failed";
      case 0x05:
        return "Out of resources";
      case 0x06:
        return "Decryption failed";
      case 0x07:
        return "Unexpected error";
      case 0x08:
        return "Cannot assign addresses";
      default:
        return "Unknown error (code: 0x${errorCode.toRadixString(16)})";
    }
  }
}

enum ProvisioningState {
  idle,
  starting,
  inProgress,
  capabilitiesReceived,
  startSent,
  publicKeySent,
  confirmationSent,
  randomSent,
  completed,
  failed,
  error,
  unknown,
}

// UUIDs
const String MESH_PROVISIONING_SERVICE_UUID = '1827';
const String MESH_PROVISIONING_DATA_IN_UUID = '2ADB';
const String MESH_PROVISIONING_DATA_OUT_UUID = '2ADC';
