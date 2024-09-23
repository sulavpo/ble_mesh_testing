import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:pointycastle/export.dart';

class BleMeshProvisioningController extends GetxController {
  final isProvisioning = false.obs;
  final provisioningStep = 0.obs;
  final isProvisioned = false.obs;
  final errorMessage = ''.obs;

  static const int MAX_RETRIES = 3;
  static const int RETRY_DELAY = 2; // seconds
  static const String PROVISIONING_SERVICE_UUID = '1827';
  static const String PROVISIONING_DATA_IN_UUID = '2adb';
  static const String PROVISIONING_DATA_OUT_UUID = '2adc';

  ECDomainParameters? _params;
  AsymmetricKeyPair<PublicKey, PrivateKey>? _keyPair;
  Uint8List? sharedSecret;
  SecureRandom? _random;

  //for authentication
  Uint8List? _confirmationKey;
  Uint8List? _confirmationSalt;
  Uint8List? _provisionerRandom;
  Uint8List? _deviceRandom;

  // Add these properties to store capabilities
  int numberOfElements = 0;
  List<String> algorithms = [];
  List<String> publicKeyTypes = [];
  List<String> staticOOBTypes = [];
  int outputOOBSize = 0;
  List<String> outputOOBActions = [];
  int inputOOBSize = 0;
  List<String> inputOOBActions = [];

  BleMeshProvisioningController() {
    _initializeCrypto();
  }

  void _initializeCrypto() {
    try {
      _params = ECDomainParameters('prime256v1');
      _random = SecureRandom('Fortuna')
        ..seed(KeyParameter(
            Uint8List.fromList(List.generate(32, (_) => _getRandomByte()))));
      _keyPair = _generateKeyPair();
    } catch (e) {
      log('Error initializing crypto components: $e');
      errorMessage.value = 'Failed to initialize crypto components';
    }
  }

  int _getRandomByte() => DateTime.now().microsecondsSinceEpoch % 256;

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateKeyPair() {
    final keyGen = ECKeyGenerator();
    keyGen.init(ParametersWithRandom(
      ECKeyGeneratorParameters(_params!),
      _random!,
    ));
    return keyGen.generateKeyPair();
  }

  Future<void> startProvisioning(BluetoothDevice device) async {
    if (_params == null || _keyPair == null) {
      log('Crypto components not initialized. Reinitializing...');
      _initializeCrypto();
    }

    isProvisioning.value = true;
    provisioningStep.value = 1;
    isProvisioned.value = false;
    errorMessage.value = '';
    update();

    try {
      await _connectToDevice(device);
      await _sendProvisioningInvite(device);
      await _receiveProvisioningCapabilities(device);
      await _sendProvisioningStart(device);
      await _exchangePublicKeys(device);
      await _performAuthentication(device);
      await _distributeProvisioningData(device);
      await _confirmProvisioningComplete(device);

      isProvisioned.value = true;
      log('Device provisioned successfully');
    } catch (e) {
      log('Provisioning failed: $e');
      errorMessage.value = 'Provisioning failed: ${e.toString()}';
    } finally {
      isProvisioning.value = false;
      provisioningStep.value = 0;
      update();
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    log('Connecting to device...');
    await device.connect(timeout: const Duration(seconds: 15));
    log('Connected successfully');

    var services = await device.discoverServices();
    for (var service in services) {
      log('Service: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        log('Characteristic: ${characteristic.uuid}, properties: ${characteristic.properties}');
      }
    }
  }

  Future<void> _sendProvisioningInvite(BluetoothDevice device) async {
    log('Sending Provisioning Invite');
    provisioningStep.value = 2;
    update();

    Uint8List invitePDU = _createProvisioningInvitePDU();
    await _sendPDU(device, invitePDU);
  }

  Future<void> _receiveProvisioningCapabilities(BluetoothDevice device) async {
    log('Waiting for Provisioning Capabilities');
    provisioningStep.value = 3;
    update();

    Uint8List capabilitiesPDU = await _receivePDU(device);
    _parseProvisioningCapabilities(capabilitiesPDU);
  }

  Future<void> _sendProvisioningStart(BluetoothDevice device) async {
    log('Sending Provisioning Start');
    provisioningStep.value = 4;
    update();

    Uint8List startPDU = _createProvisioningStartPDU();
    await _sendPDU(device, startPDU);
  }

  Future<void> _exchangePublicKeys(BluetoothDevice device) async {
    log('Exchanging Public Keys');
    provisioningStep.value = 5;
    update();

    Uint8List publicKeyPDU = _createPublicKeyPDU();
    await _sendPDU(device, publicKeyPDU);

    Uint8List devicePublicKeyPDU = await _receivePDU(device);
    ECPoint devicePublicKey = _parsePublicKeyPDU(devicePublicKeyPDU);
    sharedSecret = _performECDH(devicePublicKey);
  }

  Future<void> _performAuthentication(BluetoothDevice device) async {
    log('Performing Authentication');
    provisioningStep.value = 6;
    update();

    try {
      // Generate confirmation key and salt
      _generateConfirmationKeyAndSalt();

      // Generate and send provisioner confirmation
      Uint8List provisionerConfirmation =
          await _generateAndSendConfirmation(device);

      // Receive device confirmation
      Uint8List deviceConfirmation = await _receiveConfirmation(device);

      // Generate and send provisioner random
      await _generateAndSendProvisionerRandom(device);

      // Receive device random
      _deviceRandom = await _receiveDeviceRandom(device);

      // Verify device confirmation
      if (!_verifyDeviceConfirmation(deviceConfirmation)) {
        throw Exception('Device confirmation verification failed');
      }

      log('Authentication completed successfully');
    } catch (e) {
      log('Authentication failed: $e');
      rethrow;
    }
  }

  void _generateConfirmationKeyAndSalt() {
    var confirmationInputs = Uint8List.fromList([
      ...sharedSecret!,
      // Add other inputs as per the Bluetooth Mesh specification
    ]);

    _confirmationSalt = _calculateSalt(confirmationInputs);
    _confirmationKey = _calculateK1(sharedSecret!, _confirmationSalt!,
        Uint8List.fromList(utf8.encode("prck")));
  }

  Future<Uint8List> _generateAndSendConfirmation(BluetoothDevice device) async {
    _provisionerRandom = _generateRandom();
    var provisionerConfirmation =
        _calculateCMAC(_confirmationKey!, _provisionerRandom!);

    // Send Provisioner Confirmation PDU
    await _sendPDU(
        device, Uint8List.fromList([0x05, ...provisionerConfirmation]));

    return provisionerConfirmation;
  }

  Future<Uint8List> _receiveConfirmation(BluetoothDevice device) async {
    var confirmationPDU = await _receivePDU(device);
    if (confirmationPDU[0] != 0x05) {
      throw Exception('Invalid confirmation PDU received');
    }
    return confirmationPDU.sublist(1);
  }

  Future<void> _generateAndSendProvisionerRandom(BluetoothDevice device) async {
    // Send Provisioner Random PDU
    await _sendPDU(device, Uint8List.fromList([0x06, ..._provisionerRandom!]));
  }

  Future<Uint8List> _receiveDeviceRandom(BluetoothDevice device) async {
    var randomPDU = await _receivePDU(device);
    if (randomPDU[0] != 0x06) {
      throw Exception('Invalid random PDU received');
    }
    return randomPDU.sublist(1);
  }

  bool _verifyDeviceConfirmation(Uint8List deviceConfirmation) {
    var calculatedConfirmation =
        _calculateCMAC(_confirmationKey!, _deviceRandom!);
    return _constantTimeEquals(deviceConfirmation, calculatedConfirmation);
  }

  Uint8List _generateRandom() {
    return Uint8List.fromList(
        List.generate(16, (index) => _random!.nextUint8()));
  }

  Uint8List _calculateSalt(Uint8List inputs) {
    // Implement s1 function as per Bluetooth Mesh specification
    return Uint8List.fromList(sha256.convert(inputs).bytes.sublist(0, 16));
  }

  Uint8List _calculateK1(Uint8List n, Uint8List salt, Uint8List p) {
    // Implement k1 function as per Bluetooth Mesh specification
    var t = _calculateCMAC(_calculateSalt(n), salt);
    return _calculateCMAC(t, p);
  }

  Uint8List _calculateCMAC(Uint8List key, Uint8List data) {
    // Implement CMAC algorithm
    // This is a placeholder implementation
    var hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes.sublist(0, 16));
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  Future<void> _distributeProvisioningData(BluetoothDevice device) async {
    log('Distributing Provisioning Data');
    provisioningStep.value = 7;
    update();

    Uint8List provisioningData = _generateProvisioningData();
    Uint8List encryptedData = _encryptProvisioningData(provisioningData);
    await _sendPDU(device, encryptedData);
  }

  Future<void> _confirmProvisioningComplete(BluetoothDevice device) async {
    log('Waiting for Provisioning Complete');
    provisioningStep.value = 8;
    update();

    Uint8List completePDU = await _receivePDU(device);
    if (!_isProvisioningComplete(completePDU)) {
      throw Exception('Provisioning completion confirmation failed');
    }
  }

  Future<void> _sendPDU(BluetoothDevice device, Uint8List pdu) async {
  // Prepend PDU type (e.g., 0x03 for Provisioning PDU)
  Uint8List proxyPDU = Uint8List.fromList([0x03] + pdu);

  const int maxChunkSize = 20; // Maximum size for BLE write without response

  var services = await device.discoverServices();
  var provisioningService = services.firstWhere(
    (s) => s.uuid.toString().toLowerCase() == PROVISIONING_SERVICE_UUID,
    orElse: () => throw Exception('Mesh Provisioning Service not found'),
  );

  var provisioningCharacteristic =
      provisioningService.characteristics.firstWhere(
    (c) => c.uuid.toString().toLowerCase() == PROVISIONING_DATA_IN_UUID,
    orElse: () => throw Exception('Mesh Provisioning Data In characteristic not found'),
  );

  if (!provisioningCharacteristic.properties.write &&
      !provisioningCharacteristic.properties.writeWithoutResponse) {
    throw Exception('The characteristic does not support writing.');
  }
Stream<Uint8List> chunkPDU(Uint8List pdu, int chunkSize) async* {
  for (int i = 0; i < pdu.length; i += chunkSize) {
    yield pdu.sublist(i, i + chunkSize > pdu.length ? pdu.length : i + chunkSize);
  }
}


  // Use Stream to send data in chunks
  await for (Uint8List chunk in chunkPDU(proxyPDU, maxChunkSize)) {
    print('Sending PDU chunk: ${chunk.toString()}');
    await provisioningCharacteristic.write(chunk,
        withoutResponse: provisioningCharacteristic.properties.writeWithoutResponse);
  }
}


//   Future<void> _sendPDU(BluetoothDevice device, Uint8List pdu) async {
// //     // Prepend PDU type (e.g., 0x03 for Provisioning PDU)
// // Uint8List proxyPDU = Uint8List.fromList([0x00]);
//     Uint8List proxyPDU = Uint8List.fromList([0x03] + pdu);

//     // Define maximum chunk size
//     const int maxChunkSize = 20; // Maximum size for BLE write without response

//     var services = await device.discoverServices();
//     var provisioningService = services.firstWhere(
//       (s) => s.uuid.toString().toLowerCase() == PROVISIONING_SERVICE_UUID,
//       orElse: () => throw Exception('Mesh Provisioning Service not found'),
//     );

//     var provisioningCharacteristic =
//         provisioningService.characteristics.firstWhere(
//       (c) => c.uuid.toString().toLowerCase() == PROVISIONING_DATA_IN_UUID,
//       orElse: () =>
//           throw Exception('Mesh Provisioning Data In characteristic not found'),
//     );

//     if (!provisioningCharacteristic.properties.write &&
//         !provisioningCharacteristic.properties.writeWithoutResponse) {
//       throw Exception('The characteristic does not support writing.');
//     }

//     // Send data in chunks
//     for (int i = 0; i < proxyPDU.length; i += maxChunkSize) {
//       int end = (i + maxChunkSize < proxyPDU.length)
//           ? i + maxChunkSize
//           : proxyPDU.length;
//       Uint8List chunk = proxyPDU.sublist(i, end);
//       print('Sending PDU chunk: ${chunk.toString()}');

//       await provisioningCharacteristic.write(chunk,
//           withoutResponse:
//               provisioningCharacteristic.properties.writeWithoutResponse);
//     }
//   }

  Future<Uint8List> _receivePDU(BluetoothDevice device) async {
    // Check if the device is connected
    bool connected = device.isConnected;
    if (!connected) {
      throw Exception('Device not connected');
    }

    // Discover services and look for the provisioning service
    var services = await device.discoverServices();
    var provisioningService = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == PROVISIONING_SERVICE_UUID,
      orElse: () => throw Exception('Mesh Provisioning Service not found'),
    );

    // Find the characteristic for Provisioning Data Out
    var provisioningCharacteristic =
        provisioningService.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == PROVISIONING_DATA_OUT_UUID,
      orElse: () => throw Exception(
          'Mesh Provisioning Data Out characteristic not found'),
    );

    // Enable notifications and ensure it's successfully set
    await provisioningCharacteristic.setNotifyValue(true);
    bool isNotifying = provisioningCharacteristic.isNotifying;
    if (!isNotifying) {
      throw Exception(
          'Failed to enable notifications for Provisioning Data Out characteristic');
    }

    // Retry mechanism to handle timeout errors and attempt to receive the PDU
    int retryCount = 0;
    Uint8List receivedData;

    while (retryCount < 3) {
      try {
        // Wait for the data from the characteristic
        List<int> value = await provisioningCharacteristic.lastValueStream
            .where((value) => value.isNotEmpty)
            .first
            .timeout(const Duration(seconds: 20)); // Increased timeout to 60s

        receivedData = Uint8List.fromList(value);

        // Check if the data starts with the correct Proxy PDU type
        if (receivedData.isNotEmpty && receivedData[0] == 0x03) {
          // Remove the Proxy PDU type and return the rest
          return receivedData.sublist(1);
        } else {
          throw Exception('Received invalid Proxy PDU type');
        }
      } on TimeoutException {
        retryCount++;
        if (retryCount == 3) {
          throw TimeoutException('PDU receive timeout after multiple retries');
        }
      }
    }

    throw Exception('Failed to receive PDU');
  }

  Uint8List _createProvisioningInvitePDU({int attentionTimer = 30}) {
    // Ensure the attention timer is within the valid range (0-255)
    if (attentionTimer < 0 || attentionTimer > 255) {
      throw ArgumentError('Attention Timer must be between 0 and 255');
    }

    // Create the Provisioning Invite PDU
    // First byte (0x00) is the PDU type for Provisioning Invite
    // Second byte is the Attention Timer value
    return Uint8List.fromList([0x00, attentionTimer]);
  }

  void _parseProvisioningCapabilities(Uint8List capabilitiesPDU) {
    if (capabilitiesPDU[0] != 0x01 || capabilitiesPDU.length != 12) {
      throw const FormatException('Invalid Provisioning Capabilities PDU');
    }

    int index = 1; // Start after the PDU type byte

    // Number of Elements (1 byte)
    numberOfElements = capabilitiesPDU[index++];

    // Supported Algorithms (2 bytes)
    int algorithmsValue =
        (capabilitiesPDU[index++] << 8) | capabilitiesPDU[index++];
    algorithms = _parseAlgorithms(algorithmsValue);

    // Public Key Type (1 byte)
    int publicKeyValue = capabilitiesPDU[index++];
    publicKeyTypes = _parsePublicKeyTypes(publicKeyValue);

    // Static OOB Type (1 byte)
    int staticOOBValue = capabilitiesPDU[index++];
    staticOOBTypes = _parseStaticOOBTypes(staticOOBValue);

    // Output OOB Size (1 byte)
    outputOOBSize = capabilitiesPDU[index++];

    // Output OOB Action (2 bytes)
    int outputOOBActionValue =
        (capabilitiesPDU[index++] << 8) | capabilitiesPDU[index++];
    outputOOBActions = _parseOOBActions(outputOOBActionValue, isOutput: true);

    // Input OOB Size (1 byte)
    inputOOBSize = capabilitiesPDU[index++];

    // Input OOB Action (2 bytes)
    int inputOOBActionValue =
        (capabilitiesPDU[index++] << 8) | capabilitiesPDU[index];
    inputOOBActions = _parseOOBActions(inputOOBActionValue, isOutput: false);

    log('Parsed Capabilities:');
    log('Number of Elements: $numberOfElements');
    log('Algorithms: $algorithms');
    log('Public Key Types: $publicKeyTypes');
    log('Static OOB Types: $staticOOBTypes');
    log('Output OOB Size: $outputOOBSize');
    log('Output OOB Actions: $outputOOBActions');
    log('Input OOB Size: $inputOOBSize');
    log('Input OOB Actions: $inputOOBActions');
  }

  List<String> _parseAlgorithms(int value) {
    List<String> result = [];
    if (value & 0x0001 != 0) result.add('FIPS P-256 Elliptic Curve');
    if (value & 0x0002 != 0) result.add('BTM_ECDH_P256_HMAC_SHA256_AES_CCM');
    return result;
  }

  List<String> _parsePublicKeyTypes(int value) {
    List<String> result = [];
    if (value & 0x01 != 0) result.add('Public Key OOB information available');
    return result;
  }

  List<String> _parseStaticOOBTypes(int value) {
    List<String> result = [];
    if (value & 0x01 != 0) result.add('Static OOB information available');
    return result;
  }

  List<String> _parseOOBActions(int value, {required bool isOutput}) {
    List<String> result = [];
    if (isOutput) {
      if (value & 0x0001 != 0) result.add('Blink');
      if (value & 0x0002 != 0) result.add('Beep');
      if (value & 0x0004 != 0) result.add('Vibrate');
      if (value & 0x0008 != 0) result.add('Output Numeric');
      if (value & 0x0010 != 0) result.add('Output Alphanumeric');
    } else {
      if (value & 0x0001 != 0) result.add('Push');
      if (value & 0x0002 != 0) result.add('Twist');
      if (value & 0x0004 != 0) result.add('Input Numeric');
      if (value & 0x0008 != 0) result.add('Input Alphanumeric');
    }
    return result;
  }

  Uint8List _createProvisioningStartPDU() {
    // Implement the creation of Provisioning Start PDU based on device capabilities
    // return Uint8List.fromList([0x02, 0x00, 0x00, 0x00, 0x00]); // Example
    return Uint8List.fromList([0x00, 0x05]); // Provisioning Invite with 5 elements
  }

  Uint8List _createPublicKeyPDU() {
    // Extract public key from _keyPair and format it for transmission
    var publicKey = (_keyPair!.publicKey as ECPublicKey).Q!.getEncoded(false);
    return Uint8List.fromList([0x03, ...publicKey]);
  }

  ECPoint _parsePublicKeyPDU(Uint8List publicKeyPDU) {
    // Parse the received public key PDU
    return _params!.curve.decodePoint(publicKeyPDU.sublist(1))!;
  }

  Uint8List _performECDH(ECPoint devicePublicKey) {
    // Perform ECDH key exchange
    var privateKey = (_keyPair!.privateKey as ECPrivateKey).d;
    var sharedSecret = devicePublicKey * privateKey;
    return sharedSecret!.getEncoded();
  }

  Uint8List _generateProvisioningData() {
    // Generate provisioning data (network key, device key, etc.)
    // This is a placeholder implementation
    return Uint8List.fromList(
        List.generate(16, (index) => _random!.nextUint8()));
  }

  Uint8List _encryptProvisioningData(Uint8List provisioningData) {
    // Implement encryption of provisioning data using the shared secret
    // This is a placeholder implementation
    return provisioningData; // In reality, this should be encrypted
  }

  bool _isProvisioningComplete(Uint8List completePDU) {
    // Check if the received PDU indicates successful provisioning completion
    return completePDU.isNotEmpty && completePDU[0] == 0x08;
  }
}
