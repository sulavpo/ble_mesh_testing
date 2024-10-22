package com.example.ble_testing

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.ContentValues.TAG
import android.util.Log
import java.util.*

class BleScanner(private val context: Context, flutterEngine: FlutterEngine) {
    private val CHANNEL = "com.example.ble_scanner/ble"
    private val bluetoothAdapter: BluetoothAdapter
    private val methodChannel: MethodChannel

    private val PERMISSION_REQUEST_CODE = 1
    private var pendingResult: MethodChannel.Result? = null
    private var scanCallback: ScanCallback? = null
    private var gatt: BluetoothGatt? = null
    private val handler = Handler(Looper.getMainLooper())
    private val EXPECTED_DATA_SIZE = 32 // for example, if the data must be 32 bytes

    // Provisioning-specific variables
    private var provisioningState: ProvisioningState = ProvisioningState.IDLE
    private lateinit var provisioningDevice: BluetoothDevice
    private var provisioningServiceUuid: UUID? = null
    private var provisioningCharacteristicUuid: UUID? = null
    private var isServiceDiscoveryComplete = false
    private var retryCount = 0
    private val MAX_RETRIES = 3
    private var serviceDiscoveryRetries = 0
    private val MAX_SERVICE_DISCOVERY_RETRIES = 5
    private val SERVICE_DISCOVERY_TIMEOUT = 10000L // 10 seconds
    private val PROVISIONING_SERVICE_UUID_1827 = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")
    private val PROVISIONING_SERVICE_UUID_1828 = UUID.fromString("00001828-0000-1000-8000-00805f9b34fb")
    private val PROVISIONING_CHARACTERISTIC_UUID = UUID.fromString("00002adb-0000-1000-8000-00805f9b34fb")
    // Add PDU type enum
    private enum class PduType {
        PROVISIONING,
        PROXY,
        UNKNOWN
    }

    init {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    pendingResult = result
                    checkAndRequestPermissions()
                }
                "stopScan" -> stopScan(result)
                "connect" -> {
                    val deviceAddress = call.argument<String>("address")
                    if (deviceAddress != null) {
                        connectToDevice(deviceAddress, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device address is required", null)
                    }
                }
                "disconnect" -> disconnect(result)
                "startProvisioning" -> {
                    val deviceAddress = call.argument<String>("address")
                    if (deviceAddress != null) {
                        startProvisioning(deviceAddress, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device address is required", null)
                    }
                }
                "sendProvisioningInvite" -> {
                    val attentionDuration = call.argument<Int>("attentionDuration")
                    if (attentionDuration != null) {
                        sendProvisioningInvite(attentionDuration, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Attention duration is required", null)
                    }
                }
                "sendProvisioningStart" -> sendProvisioningStart(result)
                "sendProvisioningPublicKey" -> {
                    val publicKey = call.argument<ByteArray>("publicKey")
                    if (publicKey != null) {
                        sendProvisioningPublicKey(publicKey, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Public key is required", null)
                    }
                }
                "sendProvisioningConfirmation" -> {
                    val confirmation = call.argument<ByteArray>("confirmation")
                    if (confirmation != null) {
                        sendProvisioningConfirmation(confirmation, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Confirmation data is required", null)
                    }
                }
                "sendProvisioningRandom" -> {
                    val random = call.argument<ByteArray>("random")
                    if (random != null) {
                        sendProvisioningRandom(random, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Random data is required", null)
                    }
                }
                "sendProvisioningData" -> {
                    val provisioningData = call.argument<ByteArray>("provisioningData")
                    if (provisioningData != null) {
                        sendProvisioningData(provisioningData, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Provisioning data is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    // Function to determine PDU type based on service UUID
    private fun determineServiceType(serviceUuid: UUID): PduType {
        return when (serviceUuid.toString().toLowerCase()) {
            "00001827-0000-1000-8000-00805f9b34fb" -> PduType.PROVISIONING
            "00001828-0000-1000-8000-00805f9b34fb" -> PduType.PROXY
            else -> PduType.UNKNOWN
        }
    }

    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
            if (!hasPermissions(context, *permissions)) {
                ActivityCompat.requestPermissions(
                    context as Activity, permissions, PERMISSION_REQUEST_CODE
                )
            } else {
                startScan()
            }
        } else {
            val permissions = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN
            )
            if (!hasPermissions(context, *permissions)) {
                ActivityCompat.requestPermissions(
                    context as Activity, permissions, PERMISSION_REQUEST_CODE
                )
            } else {
                startScan()
            }
        }
    }

    private fun hasPermissions(context: Context, vararg permissions: String): Boolean {
        for (permission in permissions) {
            if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                startScan()
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Necessary permissions were denied", null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startScan() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingResult?.error("PERMISSION_DENIED", "Bluetooth scan permission not granted", null)
            return
        }

        val scanner = bluetoothAdapter.bluetoothLeScanner
        if (scanner == null) {
            methodChannel.invokeMethod("onError", "Bluetooth LE Scanner is null, make sure Bluetooth is enabled")
            return
        }

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device
                if (device == null) {
                    android.util.Log.d("BLE_SCAN", "Device is null")
                    return
                }

                var provisioningServiceUuid: String? = null
                val isMesh = result.scanRecord?.serviceUuids?.any {
                    val uuidString = it.uuid.toString()
                    when (uuidString.toLowerCase()) {
                        "00001827-0000-1000-8000-00805f9b34fb" -> {
                            provisioningServiceUuid = "1827"
                            true
                        }
                        else -> false
                    }
                } ?: false

                val deviceInfo = mapOf(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "isMesh" to isMesh,
                    "provisioningServiceUuid" to (result.scanRecord?.serviceUuids?.firstOrNull()?.uuid?.toString() ?: "None")
                )

                methodChannel.invokeMethod("onDeviceFound", deviceInfo)
            }

            override fun onScanFailed(errorCode: Int) {
                methodChannel.invokeMethod("onError", "Scan failed with error code: $errorCode")
            }
        }

        try {
            scanner.startScan(null, scanSettings, scanCallback)
            pendingResult?.success(null)
        } catch (e: Exception) {
            pendingResult?.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
        } finally {
            pendingResult = null
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter.bluetoothLeScanner
        scanCallback?.let { scanner?.stopScan(it) }
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun connectToDevice(address: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
            return
        }

        val device = bluetoothAdapter.getRemoteDevice(address)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Could not find device with address $address", null)
            return
        }

        disconnect(null)

        gatt = device.connectGatt(context, false, gattCallback)
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(result: MethodChannel.Result?) {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
//        isServiceDiscoveryComplete = false
        result?.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun startProvisioning(address: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
            ) {
                return result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
            }

            provisioningDevice = bluetoothAdapter.getRemoteDevice(address)
                ?: return result.error("DEVICE_NOT_FOUND", "Device not found", null)

            disconnect(null)

            provisioningState = ProvisioningState.INVITE
            gatt = provisioningDevice.connectGatt(context, false, gattCallback)
            result.success(null)
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_ADDRESS", "Invalid Bluetooth address: $address", e.message)
        } catch (e: Exception) {
            result.error("START_PROVISIONING_FAILED", "Failed to start provisioning: ${e.message}", null)
        }
    }

    private fun sendProvisioningInvite(attentionDuration: Int, result: MethodChannel.Result) {
        try {
            if (provisioningState != ProvisioningState.INVITE) {
                return result.error("INVALID_STATE", "Not in the invitation state", null)
            }

            if (attentionDuration < 0 || attentionDuration > 255) {
                return result.error("INVALID_PARAMETER", "Attention duration must be between 0 and 255", null)
            }

            val invitePdu = byteArrayOf(0x00, 0x00, attentionDuration.toByte())
            writeProvisioningCharacteristic(invitePdu)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_INVITE_FAILED", "Failed to send provisioning invite: ${e.message}", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun sendProvisioningStart(result: MethodChannel.Result) {
        if (provisioningState != ProvisioningState.START) {
            return result.error("INVALID_STATE", "Not in the start state", null)
        }

        try {
            val algorithm = 0x00 // Example: FIPS P-256 Elliptic Curve
            val publicKey = 0x00 // Example: No OOB public key
            val authenticationMethod = 0x00 // Example: No OOB authentication
            val authenticationAction = 0x00 // Example: No action required
            val authenticationSize = 0x00 // Example: No input size

            val startPdu = byteArrayOf(
                0x02, // Opcode for Provisioning Start
                algorithm.toByte(),
                publicKey.toByte(),
                authenticationMethod.toByte(),
                authenticationAction.toByte(),
                authenticationSize.toByte()
            )

            writeProvisioningCharacteristic(startPdu)
            provisioningState = ProvisioningState.PUBLIC_KEY_EXCHANGE
            result.success(null)
        } catch (e: Exception) {
            result.error("PROVISIONING_START_FAILED", "Failed to send provisioning start: ${e.message}", null)
        }
    }

    private fun sendProvisioningPublicKey(publicKey: ByteArray, result: MethodChannel.Result) {
        try {
            if (provisioningState != ProvisioningState.PUBLIC_KEY_EXCHANGE) {
                return result.error("INVALID_STATE", "Not in the public key exchange state", null)
            }

            if (publicKey.size != 64) {  // Ensure public key is of correct length
                return result.error("INVALID_KEY_SIZE", "Public key must be 64 bytes", null)
            }

            val publicKeyPdu = byteArrayOf(0x03) + publicKey
            writeProvisioningCharacteristic(publicKeyPdu)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_PUBLIC_KEY_FAILED", "Failed to send public key: ${e.message}", null)
        }
    }

    private fun sendProvisioningConfirmation(confirmation: ByteArray, result: MethodChannel.Result) {
        try {
            if (provisioningState != ProvisioningState.CONFIRMATION) {
                return result.error("INVALID_STATE", "Not in the confirmation state", null)
            }

            if (confirmation.size != 16) {  // Ensure confirmation is of correct length
                return result.error("INVALID_CONFIRMATION_SIZE", "Confirmation data must be 16 bytes", null)
            }

            val confirmationPdu = byteArrayOf(0x05) + confirmation
            writeProvisioningCharacteristic(confirmationPdu)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_CONFIRMATION_FAILED", "Failed to send confirmation: ${e.message}", null)
        }
    }

    private fun sendProvisioningRandom(random: ByteArray, result: MethodChannel.Result) {
        try {
            if (provisioningState != ProvisioningState.RANDOM) {
                return result.error("INVALID_STATE", "Not in the random state", null)
            }

            if (random.size != 16) {  // Ensure random is of correct length
                return result.error("INVALID_RANDOM_SIZE", "Random data must be 16 bytes", null)
            }

            val randomPdu = byteArrayOf(0x06) + random
            writeProvisioningCharacteristic(randomPdu)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_RANDOM_FAILED", "Failed to send random: ${e.message}", null)
        }
    }

    private fun sendProvisioningData(provisioningData: ByteArray, result: MethodChannel.Result) {
        try {
            if (provisioningState != ProvisioningState.DATA) {
                return result.error("INVALID_STATE", "Not in the DATA state for provisioning", null)
            }

            if (provisioningData.isEmpty()) {
                return result.error("INVALID_DATA", "Provisioning data cannot be empty", null)
            }

            if (provisioningData.size != EXPECTED_DATA_SIZE) {
                return result.error("INVALID_DATA_SIZE", "Provisioning data must be $EXPECTED_DATA_SIZE bytes", null)
            }

            val dataPdu = byteArrayOf(0x07) + provisioningData
            writeProvisioningCharacteristic(dataPdu)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_PROVISIONING_DATA_FAILED", "Failed to send provisioning data: ${e.message}", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeProvisioningCharacteristic(data: ByteArray) {
        try {
            if (!isServiceDiscoveryComplete) {
                Log.w(TAG, "Service discovery not complete, initiating discovery...")
                initiateServiceDiscovery()
                handler.postDelayed({ writeProvisioningCharacteristic(data) }, SERVICE_DISCOVERY_TIMEOUT)
                return
            }

            val gattLocal = gatt ?: throw IllegalStateException("GATT is null")
            val serviceUuid = provisioningServiceUuid ?: throw IllegalStateException("Provisioning service UUID is null")
            val characteristicUuid = provisioningCharacteristicUuid ?: throw IllegalStateException("Provisioning characteristic UUID is null")

            // Determine PDU type based on service
            val pduType = determineServiceType(serviceUuid)
            Log.d(TAG, "Attempting to write ${pduType.name} PDU")
            Log.d(TAG, "PDU Data: ${data.joinToString(", ") { "0x%02X".format(it) }}")

            // Validate PDU type matches service
            if (pduType == PduType.UNKNOWN) {
                Log.e(TAG, "Unknown service type for UUID: $serviceUuid")
                methodChannel.invokeMethod("onError", "Unknown service type")
                return
            }

            val service = gattLocal.getService(serviceUuid) ?: throw IllegalStateException("Service not found for UUID: $serviceUuid")
            val characteristic = service.getCharacteristic(characteristicUuid) ?: throw IllegalStateException("Characteristic not found for UUID: $characteristicUuid")

            // Log PDU details
            Log.d(TAG, """
                Writing ${pduType.name} PDU:
                - Service UUID: $serviceUuid
                - Characteristic UUID: $characteristicUuid
                - Data Length: ${data.size}
                - First Byte (Opcode): 0x${"%02X".format(data[0])}
                - Full Data: ${data.joinToString(", ") { "0x%02X".format(it) }}
            """.trimIndent())

            characteristic.value = data
            val writeResult = gattLocal.writeCharacteristic(characteristic)

            if (writeResult) {
                Log.i(TAG, "${pduType.name} PDU write initiated successfully")
            } else {
                Log.e(TAG, "${pduType.name} PDU write failed to initiate")
                methodChannel.invokeMethod("onError", "Failed to initiate characteristic write")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing characteristic: ${e.message}", e)
            methodChannel.invokeMethod("onError", "Error writing characteristic: ${e.message}")
        }
    }
    private fun initiateServiceDiscovery() {
        if (serviceDiscoveryRetries < MAX_SERVICE_DISCOVERY_RETRIES) {
            serviceDiscoveryRetries++
            android.util.Log.w("BleScanner", "Initiating service discovery (Attempt $serviceDiscoveryRetries)")
            gatt?.discoverServices()

            // Set a timeout for service discovery
            handler.postDelayed({
                if (!isServiceDiscoveryComplete) {
                    android.util.Log.e("BleScanner", "Service discovery timed out")
                    methodChannel.invokeMethod("onError", "Service discovery timed out")
                    disconnect(null)
                }
            }, SERVICE_DISCOVERY_TIMEOUT)
        } else {
            android.util.Log.e("BleScanner", "Service discovery failed after $MAX_SERVICE_DISCOVERY_RETRIES attempts")
            methodChannel.invokeMethod("onError", "Service discovery failed after multiple attempts")
            disconnect(null)
        }
    }

    // Enhanced logging for service discovery
    private fun logAvailableServices(gatt: BluetoothGatt) {
        Log.d(TAG, "=== Available Services ===")
        gatt.services.forEach { service ->
            val serviceType = determineServiceType(service.uuid)
            Log.d(TAG, "Service UUID: ${service.uuid} (Type: $serviceType)")
            service.characteristics.forEach { characteristic ->
                Log.d(TAG, "  └── Characteristic UUID: ${characteristic.uuid}")
                Log.d(TAG, "      Properties: ${getCharacteristicProperties(characteristic)}")
            }
        }
        Log.d(TAG, "=====================")
    }
    // Helper function to decode characteristic properties
    private fun getCharacteristicProperties(characteristic: BluetoothGattCharacteristic): String {
        val props = mutableListOf<String>()
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) props.add("READ")
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) props.add("WRITE")
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) props.add("NOTIFY")
        return props.joinToString(", ")
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    android.util.Log.i("BleScanner", "Connected to GATT server.")
                    handler.post {
                        methodChannel.invokeMethod("onConnectionStateChange", "connected")
                    }
                    // Reset service discovery related variables
                    isServiceDiscoveryComplete = false
                    serviceDiscoveryRetries = 0
                    // Initiate service discovery
                    initiateServiceDiscovery()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    android.util.Log.i("BleScanner", "Disconnected from GATT server.")
                    handler.post {
                        methodChannel.invokeMethod("onConnectionStateChange", "disconnected")
                    }
                    gatt.close()
                    isServiceDiscoveryComplete = false
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.i(TAG, "Services discovered successfully")
                logAvailableServices(gatt)

                var foundService: BluetoothGattService? = null
                var serviceType: PduType = PduType.UNKNOWN

                // Try to find either Provisioning or Proxy service
                for (service in gatt.services) {
                    val currentType = determineServiceType(service.uuid)
                    if (currentType != PduType.UNKNOWN) {
                        foundService = service
                        serviceType = currentType
                        break
                    }
                }

                when (serviceType) {
                    PduType.PROVISIONING -> {
                        Log.i(TAG, "Found Provisioning service")
                        provisioningServiceUuid = foundService?.uuid
                        provisioningCharacteristicUuid = foundService?.characteristics?.find {
                            it.uuid == PROVISIONING_CHARACTERISTIC_UUID
                        }?.uuid
                    }
                    PduType.PROXY -> {
                        Log.i(TAG, "Found Proxy service")
                        // Handle proxy service if needed
                    }
                    PduType.UNKNOWN -> {
                        Log.e(TAG, "Neither Provisioning nor Proxy service found")
                    }
                }

                if (provisioningServiceUuid != null && provisioningCharacteristicUuid != null) {
                    isServiceDiscoveryComplete = true
                    serviceDiscoveryRetries = 0
                    handler.post {
                        methodChannel.invokeMethod("onProvisioningServiceFound", null)
                    }
                } else {
                    Log.e(TAG, "Required service or characteristic not found")
                    handler.post {
                        methodChannel.invokeMethod("onError", "Required service or characteristic not found")
                    }
                    initiateServiceDiscovery()
                }
            } else {
                Log.w(TAG, "Service discovery failed with status: $status")
                initiateServiceDiscovery()
            }
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (characteristic.uuid == provisioningCharacteristicUuid) {
                val value = characteristic.value
                if (value != null && value.isNotEmpty()) {
                    when (value[0].toInt()) {
                        0x01 -> {
                            provisioningState = ProvisioningState.START
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningCapabilities", value.slice(1 until value.size).toByteArray())
                            }
                        }
                        0x04 -> {
                            provisioningState = ProvisioningState.PUBLIC_KEY_EXCHANGE
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningPublicKey", value.slice(1 until value.size).toByteArray())
                            }
                        }
                        0x05 -> {
                            provisioningState = ProvisioningState.CONFIRMATION
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningConfirmation", value.slice(1 until value.size).toByteArray())
                            }
                        }
                        0x06 -> {
                            provisioningState = ProvisioningState.RANDOM
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningRandom", value.slice(1 until value.size).toByteArray())
                            }
                        }
                        0x08 -> {
                            provisioningState = ProvisioningState.COMPLETE
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningComplete", null)
                            }
                        }
                        0x09 -> {
                            provisioningState = ProvisioningState.FAILED
                            handler.post {
                                methodChannel.invokeMethod("onProvisioningFailed", value[1].toInt())
                            }
                        }
                    }
                }
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handler.post {
                    methodChannel.invokeMethod("onCharacteristicRead", characteristic.value)
                }
            } else {
                handler.post {
                    methodChannel.invokeMethod("onError", "Characteristic read failed")
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handler.post {
                    methodChannel.invokeMethod("onCharacteristicWrite", "success")
                }
            } else {
                handler.post {
                    methodChannel.invokeMethod("onError", "Characteristic write failed")
                }
            }
        }
    }

    private enum class ProvisioningState {
        IDLE, INVITE, START, PUBLIC_KEY_EXCHANGE, CONFIRMATION, RANDOM, DATA, COMPLETE, FAILED
    }
}