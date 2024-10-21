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
                        "00001828-0000-1000-8000-00805f9b34fb" -> {
                            provisioningServiceUuid = "1828"
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
//
            if (!isServiceDiscoveryComplete) {
                android.util.Log.w("BleScanner", "Service discovery not complete, initiating discovery...")
                initiateServiceDiscovery()
                // Retry after a short delay
                handler.postDelayed({ writeProvisioningCharacteristic(data) }, SERVICE_DISCOVERY_TIMEOUT)
                return
            }

            val gattLocal = gatt
            if (gattLocal == null) {
                android.util.Log.e("BleScanner", "GATT is null")
                methodChannel.invokeMethod("onError", "GATT is null")
                return
            }

            val serviceUuid = provisioningServiceUuid
            if (serviceUuid == null) {
                android.util.Log.e("BleScanner", "Provisioning service UUID is null")
                methodChannel.invokeMethod("onError", "Provisioning service UUID is null")
                return
            }

            val characteristicUuid = provisioningCharacteristicUuid
            if (characteristicUuid == null) {
                android.util.Log.e("BleScanner", "Provisioning characteristic UUID is null")
                methodChannel.invokeMethod("onError", "Provisioning characteristic UUID is null")
                return
            }

            val service = gattLocal.getService(serviceUuid)
            if (service == null) {
                android.util.Log.e("BleScanner", "Service not found for UUID: $serviceUuid")
                logAvailableServices(gattLocal)
                methodChannel.invokeMethod("onError", "Provisioning service not found")
                // Attempt to rediscover services
                initiateServiceDiscovery()
                return
            }

            val characteristic = service.getCharacteristic(characteristicUuid)
            if (characteristic == null) {
                android.util.Log.e("BleScanner", "Characteristic not found for UUID: $characteristicUuid")
                methodChannel.invokeMethod("onError", "Provisioning characteristic not found")
                return
            }

            characteristic.value = data
            val writeResult = gattLocal.writeCharacteristic(characteristic)
            if (writeResult) {
                android.util.Log.i("BleScanner", "Write initiated successfully")
            } else {
                android.util.Log.e("BleScanner", "Failed to initiate write")
                methodChannel.invokeMethod("onError", "Failed to initiate characteristic write")
            }
        } catch (e: Exception) {
            android.util.Log.e("BleScanner", "Error writing characteristic: ${e.message}", e)
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

    private fun logAvailableServices(gatt: BluetoothGatt) {
        android.util.Log.d("BleScanner", "Available services:")
        gatt.services.forEach { service ->
            android.util.Log.d("BleScanner", "Service UUID: ${service.uuid}")
            service.characteristics.forEach { characteristic ->
                android.util.Log.d("BleScanner", "  Characteristic UUID: ${characteristic.uuid}")
            }
        }
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
                android.util.Log.i("BleScanner", "Services discovered successfully")
                logAvailableServices(gatt)

                for (service in gatt.services) {
                    if (service.uuid.toString().startsWith("00001827") || service.uuid.toString().startsWith("00001828")) {
                        provisioningServiceUuid = service.uuid
                        for (characteristic in service.characteristics) {
                            if (characteristic.uuid.toString().startsWith("00002adb")) {
                                provisioningCharacteristicUuid = characteristic.uuid
                                break
                            }
                        }
                        break
                    }
                }

                if (provisioningServiceUuid != null && provisioningCharacteristicUuid != null) {
                    isServiceDiscoveryComplete = true
                    serviceDiscoveryRetries = 0
                    handler.post {
                        methodChannel.invokeMethod("onProvisioningServiceFound", null)
                    }
                } else {
                    android.util.Log.e("BleScanner", "Provisioning service or characteristic not found")
                    handler.post {
                        methodChannel.invokeMethod("onError", "Provisioning service or characteristic not found")
                    }
                    initiateServiceDiscovery()
                }
            } else {
                android.util.Log.w("BleScanner", "onServicesDiscovered received: $status")
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