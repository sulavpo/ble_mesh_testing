// package com.example.ble_testing

// import android.Manifest
// import android.annotation.SuppressLint
// import android.bluetooth.*
// import android.bluetooth.le.ScanCallback
// import android.bluetooth.le.ScanResult
// import android.bluetooth.le.ScanSettings
// import android.content.Context
// import android.content.pm.PackageManager
// import android.os.Build
// import android.os.Handler
// import android.os.Looper
// import androidx.core.app.ActivityCompat
// import androidx.core.content.ContextCompat
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import android.app.Activity
// import android.content.ContentValues.TAG
// import android.util.Log
// import java.util.*

// class BleScanner(private val context: Context, flutterEngine: FlutterEngine) {
//     private val CHANNEL = "com.example.ble_scanner/ble"
//     private val bluetoothAdapter: BluetoothAdapter
//     private val methodChannel: MethodChannel

//     private val PERMISSION_REQUEST_CODE = 1
//     private var pendingResult: MethodChannel.Result? = null
//     private var scanCallback: ScanCallback? = null
//     private var gatt: BluetoothGatt? = null
//     private val handler = Handler(Looper.getMainLooper())
//     private val EXPECTED_DATA_SIZE = 32

//     // Timeouts and retry configurations
//     private val PROVISIONING_TIMEOUT = 30000L // 30 seconds overall timeout
//     private val PDU_EXCHANGE_TIMEOUT = 5000L // 5 seconds for PDU exchanges
//     private val MAX_RETRIES = 3
//     private val MAX_SERVICE_DISCOVERY_RETRIES = 5
//     private val SERVICE_DISCOVERY_TIMEOUT = 10000L // 10 seconds
    
//     // State tracking variables
//     private var currentProvisioningState: ProvisioningState = ProvisioningState.IDLE
//     private lateinit var provisioningDevice: BluetoothDevice
//     private var isServiceDiscoveryComplete = false
//     private var retryCount = 0
//     private var serviceDiscoveryRetries = 0
//     private var provisioningTimeoutRunnable: Runnable? = null
//     private var isProvisioningTimeout = false
    
//     // BLE Mesh UUIDs
//     private val PROVISIONING_SERVICE_UUID = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")
//     private val PROVISIONING_DATA_IN_UUID = UUID.fromString("00002adb-0000-1000-8000-00805f9b34fb")
//     private val PROVISIONING_DATA_OUT_UUID = UUID.fromString("00002adc-0000-1000-8000-00805f9b34fb")
//     private val CLIENT_CHARACTERISTIC_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    
//     private var provisioningDataOutCharacteristic: BluetoothGattCharacteristic? = null
//     private var provisioningDataInCharacteristic: BluetoothGattCharacteristic? = null

//     init {
//         val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
//         bluetoothAdapter = bluetoothManager.adapter
//         methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

//         methodChannel.setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "startScan" -> {
//                     pendingResult = result
//                     checkAndRequestPermissions()
//                 }
//                 "stopScan" -> stopScan(result)
//                 "connect" -> {
//                     val deviceAddress = call.argument<String>("address")
//                     if (deviceAddress != null) {
//                         connectToDevice(deviceAddress, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Device address is required", null)
//                     }
//                 }
//                 "disconnect" -> disconnect(result)
//                 "startProvisioning" -> {
//                     val deviceAddress = call.argument<String>("address")
//                     if (deviceAddress != null) {
//                         startProvisioning(deviceAddress, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Device address is required", null)
//                     }
//                 }
//                 "sendProvisioningInvite" -> {
//                     val attentionDuration = call.argument<Int>("attentionDuration")
//                     if (attentionDuration != null) {
//                         sendProvisioningInvite(attentionDuration, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Attention duration is required", null)
//                     }
//                 }
//                 "sendProvisioningStart" -> sendProvisioningStart(result)
//                 "sendProvisioningPublicKey" -> {
//                     val publicKey = call.argument<ByteArray>("publicKey")
//                     if (publicKey != null) {
//                         sendProvisioningPublicKey(publicKey, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Public key is required", null)
//                     }
//                 }
//                 "sendProvisioningConfirmation" -> {
//                     val confirmation = call.argument<ByteArray>("confirmation")
//                     if (confirmation != null) {
//                         sendProvisioningConfirmation(confirmation, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Confirmation data is required", null)
//                     }
//                 }
//                 "sendProvisioningRandom" -> {
//                     val random = call.argument<ByteArray>("random")
//                     if (random != null) {
//                         sendProvisioningRandom(random, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Random data is required", null)
//                     }
//                 }
//                 "sendProvisioningData" -> {
//                     val provisioningData = call.argument<ByteArray>("provisioningData")
//                     if (provisioningData != null) {
//                         sendProvisioningData(provisioningData, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Provisioning data is required", null)
//                     }
//                 }
//                 else -> result.notImplemented()
//             }
//         }
//     }

//     private fun checkAndRequestPermissions() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
//             val permissions = arrayOf(
//                 Manifest.permission.BLUETOOTH_SCAN,
//                 Manifest.permission.BLUETOOTH_CONNECT,
//                 Manifest.permission.ACCESS_FINE_LOCATION
//             )
//             if (!hasPermissions(context, *permissions)) {
//                 ActivityCompat.requestPermissions(
//                     context as Activity, permissions, PERMISSION_REQUEST_CODE
//                 )
//             } else {
//                 startScan()
//             }
//         } else {
//             val permissions = arrayOf(
//                 Manifest.permission.ACCESS_FINE_LOCATION,
//                 Manifest.permission.BLUETOOTH,
//                 Manifest.permission.BLUETOOTH_ADMIN
//             )
//             if (!hasPermissions(context, *permissions)) {
//                 ActivityCompat.requestPermissions(
//                     context as Activity, permissions, PERMISSION_REQUEST_CODE
//                 )
//             } else {
//                 startScan()
//             }
//         }
//     }

//     private fun hasPermissions(context: Context, vararg permissions: String): Boolean {
//         for (permission in permissions) {
//             if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
//                 return false
//             }
//         }
//         return true
//     }

//     fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
//         if (requestCode == PERMISSION_REQUEST_CODE) {
//             if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
//                 startScan()
//             } else {
//                 pendingResult?.error("PERMISSION_DENIED", "Necessary permissions were denied", null)
//             }
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun startScan() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//             ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED
//         ) {
//             pendingResult?.error("PERMISSION_DENIED", "Bluetooth scan permission not granted", null)
//             return
//         }

//         val scanner = bluetoothAdapter.bluetoothLeScanner
//         if (scanner == null) {
//             methodChannel.invokeMethod("onError", "Bluetooth LE Scanner is null, make sure Bluetooth is enabled")
//             pendingResult?.error("BLE_SCANNER_NULL", "Bluetooth LE Scanner is null", null)
//             return
//         }

//         val scanSettings = ScanSettings.Builder()
//             .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
//             .build()

//         scanCallback = object : ScanCallback() {
//             override fun onScanResult(callbackType: Int, result: ScanResult) {
//                 val device = result.device
//                 if (device == null) {
//                     Log.d("BLE_SCAN", "Device is null")
//                     return
//                 }

//                 var isMesh = false
//                 var provisioningServiceUuid: String? = null
//                 result.scanRecord?.serviceUuids?.forEach {
//                     when (it.uuid.toString().lowercase()) {
//                         "00001827-0000-1000-8000-00805f9b34fb" -> {
//                             isMesh = true
//                             provisioningServiceUuid = "1827"
//                         }
//                         "00001828-0000-1000-8000-00805f9b34fb" -> {
//                             isMesh = true
//                             provisioningServiceUuid = "1828"
//                         }
//                     }
//                 }

//                 val deviceInfo = mapOf(
//                     "name" to (device.name ?: "Unknown"),
//                     "address" to device.address,
//                     "isMesh" to isMesh,
//                     "provisioningServiceUuid" to provisioningServiceUuid
//                 )

//                 handler.post {
//                     methodChannel.invokeMethod("onDeviceFound", deviceInfo)
//                 }
//             }

//             override fun onScanFailed(errorCode: Int) {
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Scan failed with error code: $errorCode")
//                     pendingResult?.error("SCAN_FAILED", "Scan failed with error code: $errorCode", null)
//                 }
//             }
//         }

//         try {
//             scanner.startScan(null, scanSettings, scanCallback)
//             pendingResult?.success(null)
//         } catch (e: Exception) {
//             pendingResult?.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
//         } finally {
//             pendingResult = null
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun stopScan(result: MethodChannel.Result) {
//         val scanner = bluetoothAdapter.bluetoothLeScanner
//         scanCallback?.let { scanner?.stopScan(it) }
//         result.success(null)
//     }

//     @SuppressLint("MissingPermission")
//     private fun connectToDevice(address: String, result: MethodChannel.Result) {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//             ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
//         ) {
//             result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
//             return
//         }

//         try {
//             val device = bluetoothAdapter.getRemoteDevice(address)
//             disconnect(null)
//             gatt = device.connectGatt(context, false, gattCallback)
//             result.success(null)
//         } catch (e: IllegalArgumentException) {
//             result.error("DEVICE_NOT_FOUND", "Could not find device with address $address", e.message)
//         } catch (e: Exception) {
//             result.error("CONNECTION_ERROR", "Error connecting to device: ${e.message}", null)
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun disconnect(result: MethodChannel.Result?) {
//         cancelProvisioningTimeout()
//         gatt?.disconnect()
//         gatt?.close()
//         gatt = null
//         isServiceDiscoveryComplete = false
//         provisioningDataOutCharacteristic = null
//         provisioningDataInCharacteristic = null
//         currentProvisioningState = ProvisioningState.IDLE
//         result?.success(null)
//     }

//     private fun cancelProvisioningTimeout() {
//         provisioningTimeoutRunnable?.let { handler.removeCallbacks(it) }
//         provisioningTimeoutRunnable = null
//         isProvisioningTimeout = false
//     }

//     @SuppressLint("MissingPermission")
//     private fun startProvisioning(address: String, result: MethodChannel.Result) {
//         try {
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//                 ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
//             ) {
//                 result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
//                 return
//             }

//             provisioningDevice = bluetoothAdapter.getRemoteDevice(address)
//                 ?: return result.error("DEVICE_NOT_FOUND", "Device not found", null)

//             disconnect(null)
            
//             // Reset all state variables
//             currentProvisioningState = ProvisioningState.PROVISIONING_INVITE
//             retryCount = 0
//             serviceDiscoveryRetries = 0
//             isProvisioningTimeout = false
//             isServiceDiscoveryComplete = false

//             // Set overall provisioning timeout
//             provisioningTimeoutRunnable = Runnable {
//                 Log.e(TAG, "Provisioning timed out after ${PROVISIONING_TIMEOUT/1000} seconds")
//                 isProvisioningTimeout = true
//                 handleProvisioningError(1, "Provisioning timed out")
//                 disconnect(null)
//             }
//             handler.postDelayed(provisioningTimeoutRunnable!!, PROVISIONING_TIMEOUT)

//             gatt = provisioningDevice.connectGatt(context, false, gattCallback)
//             result.success(mapOf("message" to "Connecting and discovering services..."))
//         } catch (e: IllegalArgumentException) {
//             result.error("INVALID_ADDRESS", "Invalid Bluetooth address: $address", e.message)
//         } catch (e: Exception) {
//             result.error("START_PROVISIONING_FAILED", "Failed to start provisioning: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningInvite(attentionDuration: Int, result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_INVITE) {
//                 return result.error("INVALID_STATE", "Not in invitation state (current: $currentProvisioningState)", null)
//             }

//             if (attentionDuration < 0 || attentionDuration > 255) {
//                 return result.error("INVALID_PARAMETER", "Attention duration must be 0-255", null)
//             }

//             // Correctly formatted invitation PDU
//             val invitePdu = byteArrayOf(0x00, attentionDuration.toByte())
//             writeProvisioningCharacteristic(invitePdu)

//             // // State transition will happen when we receive capabilities response
//             // result.success(null)
//             if (!isServiceDiscoveryComplete || provisioningDataInCharacteristic == null) {
//                 result.error("SERVICE_DISCOVERY_INCOMPLETE", 
//                     "Services not discovered yet, please wait", null)
//                 return
//             }
//         } catch (e: Exception) {
//             result.error("SEND_INVITE_FAILED", "Failed to send invite: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningStart(result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_START) {
//                 return result.error("INVALID_STATE", "Not in start state (current: $currentProvisioningState)", null)
//             }

//             val startPdu = byteArrayOf(
//                 0x02, // Start opcode
//                 0x00, // Algorithm: FIPS P-256
//                 0x00, // Public Key: No OOB
//                 0x00, // Auth Method: No OOB
//                 0x00, // Auth Action: No input
//                 0x00  // Auth Size: 0
//             )
//             writeProvisioningCharacteristic(startPdu)
            
//             // Don't transition state yet - wait for device response
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("START_FAILED", "Failed to send start: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningPublicKey(publicKey: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_PUBLIC_KEY_SENT) {
//                 return result.error("INVALID_STATE", "Not in public key exchange state (current: $currentProvisioningState)", null)
//             }

//             if (publicKey.size != 64) {
//                 return result.error("INVALID_KEY", "Public key must be 64 bytes", null)
//             }

//             val keyPdu = byteArrayOf(0x03) + publicKey
//             writeProvisioningCharacteristic(keyPdu)
//             currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_WAITING
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("KEY_FAILED", "Failed to send public key: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningConfirmation(confirmation: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_CONFIRMATION_SENT) {
//                 return result.error("INVALID_STATE", "Not in confirmation state (current: $currentProvisioningState)", null)
//             }

//             if (confirmation.size != 16) {
//                 return result.error("INVALID_CONFIRMATION", "Confirmation must be 16 bytes", null)
//             }

//             val confirmationPdu = byteArrayOf(0x05) + confirmation
//             writeProvisioningCharacteristic(confirmationPdu)
//             currentProvisioningState = ProvisioningState.PROVISIONING_CONFIRMATION_RECEIVED
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("CONFIRMATION_FAILED", "Failed to send confirmation: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningRandom(random: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_RANDOM_SENT) {
//                 return result.error("INVALID_STATE", "Not in random state (current: $currentProvisioningState)", null)
//             }

//             if (random.size != 16) {
//                 return result.error("INVALID_RANDOM", "Random must be 16 bytes", null)
//             }

//             val randomPdu = byteArrayOf(0x06) + random
//             writeProvisioningCharacteristic(randomPdu)
//             currentProvisioningState = ProvisioningState.PROVISIONING_RANDOM_RECEIVED
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("RANDOM_FAILED", "Failed to send random: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningData(provisioningData: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (currentProvisioningState != ProvisioningState.PROVISIONING_DATA_SENT) {
//                 return result.error("INVALID_STATE", "Not in data state (current: $currentProvisioningState)", null)
//             }

//             if (provisioningData.size != EXPECTED_DATA_SIZE) {
//                 return result.error("INVALID_DATA", "Provisioning data must be $EXPECTED_DATA_SIZE bytes", null)
//             }

//             val dataPdu = byteArrayOf(0x07) + provisioningData
//             writeProvisioningCharacteristic(dataPdu)
//             currentProvisioningState = ProvisioningState.PROVISIONING_COMPLETE
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("DATA_FAILED", "Failed to send provisioning data: ${e.message}", null)
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun writeProvisioningCharacteristic(data: ByteArray) {
//         try {
//             if (isProvisioningTimeout) {
//                 Log.e(TAG, "Provisioning already timed out, ignoring write operation")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Provisioning already timed out")
//                 }
//                 return
//             }

//             val gattLocal = gatt ?: run {
//                 Log.e(TAG, "GATT is null")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "GATT connection is null")
//                 }
//                 return
//             }

//             val characteristic = provisioningDataInCharacteristic ?: run {
//                 Log.e(TAG, "Provisioning characteristic is null")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Provisioning characteristic not found")
//                 }
//                 return
//             }

//             // For PB-GATT, Proxy PDU header should be 0x03
//             val proxyPdu = byteArrayOf(0x03) + data

//             Log.d(TAG, "Writing Proxy PDU (state=$currentProvisioningState): ${proxyPdu.joinToString { "0x%02X".format(it) }}")

//             // Clear any pending timeouts for this characteristic
//             handler.removeCallbacksAndMessages(characteristic)

//             characteristic.value = proxyPdu
//             val writeResult = gattLocal.writeCharacteristic(characteristic)

//             if (!writeResult) {
//                 Log.e(TAG, "Failed to initiate write")
//                 if (retryCount < MAX_RETRIES) {
//                     retryCount++
//                     Log.w(TAG, "Retrying write operation (Attempt $retryCount)")
//                     handler.postDelayed({ writeProvisioningCharacteristic(data) }, 500L * retryCount)
//                 } else {
//                     retryCount = 0
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Failed to write after $MAX_RETRIES attempts")
//                         methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                             "errorCode" to 2,
//                             "message" to "Failed to write characteristic"
//                         ))
//                     }
//                 }
//             } else {
//                 // Set timeout for response
//                 handler.postDelayed({
//                     if (currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE &&
//                         currentProvisioningState != ProvisioningState.PROVISIONING_FAILED) {
//                         Log.e(TAG, "PDU exchange timed out")
//                         handler.post {
//                             methodChannel.invokeMethod("onError", "PDU exchange timed out")
//                             methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                                 "errorCode" to 5,
//                                 "message" to "PDU exchange timed out"
//                             ))
//                         }
//                         disconnect(null)
//                     }
//                 }, PDU_EXCHANGE_TIMEOUT)
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Error writing characteristic: ${e.message}", e)
//             handler.post {
//                 methodChannel.invokeMethod("onError", "Error writing characteristic: ${e.message}")
//                 methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                     "errorCode" to 6,
//                     "message" to "Characteristic write error"
//                 ))
//             }
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun initiateServiceDiscovery() {
//         if (serviceDiscoveryRetries >= MAX_SERVICE_DISCOVERY_RETRIES) {
//             Log.e(TAG, "Service discovery failed after $MAX_SERVICE_DISCOVERY_RETRIES attempts")
//             handler.post {
//                 methodChannel.invokeMethod("onError", "Service discovery failed after multiple attempts")
//                 methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                     "errorCode" to 3,
//                     "message" to "Service discovery failed"
//                 ))
//             }
//             disconnect(null)
//             return
//         }

//         serviceDiscoveryRetries++
//         Log.w(TAG, "Initiating service discovery (Attempt $serviceDiscoveryRetries)")
//         gatt?.discoverServices()

//         handler.postDelayed({
//             if (!isServiceDiscoveryComplete && gatt != null) {
//                 Log.e(TAG, "Service discovery timed out")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Service discovery timed out")
//                     methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                         "errorCode" to 3,
//                         "message" to "Service discovery timed out"
//                     ))
//                 }
//                 disconnect(null)
//             }
//         }, SERVICE_DISCOVERY_TIMEOUT)
//     }

//     private fun logAvailableServices(gatt: BluetoothGatt) {
//         Log.d(TAG, "=== Available Services ===")
//         gatt.services.forEach { service ->
//             Log.d(TAG, "Service UUID: ${service.uuid}")
//             service.characteristics.forEach { characteristic ->
//                 Log.d(TAG, "  └── Characteristic UUID: ${characteristic.uuid}")
//                 Log.d(TAG, "      Properties: ${getCharacteristicProperties(characteristic)}")
//             }
//         }
//         Log.d(TAG, "=====================")
//     }

//     private fun getCharacteristicProperties(characteristic: BluetoothGattCharacteristic): String {
//         val props = mutableListOf<String>()
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) props.add("READ")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) props.add("WRITE")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) props.add("NOTIFY")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) props.add("INDICATE")
//         return props.joinToString(", ")
//     }

//     private fun handleProvisioningError(errorCode: Int, message: String) {
//         Log.e(TAG, "Provisioning error $errorCode: $message")
//         cancelProvisioningTimeout()
//         currentProvisioningState = ProvisioningState.PROVISIONING_FAILED
        
//         handler.post {
//             methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                 "errorCode" to errorCode,
//                 "message" to message
//             ))
//         }
//     }

//     private val gattCallback = object : BluetoothGattCallback() {
//         @SuppressLint("MissingPermission")
//         override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
//             Log.d(TAG, "Connection state change: status=$status, newState=$newState")
//             if (status != BluetoothGatt.GATT_SUCCESS) {
//                 Log.e(TAG, "Connection state change error: $status")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Connection error: $status")
//                     methodChannel.invokeMethod("onConnectionStateChange", "error")
//                     if (currentProvisioningState != ProvisioningState.IDLE && 
//                         currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE) {
//                         handleProvisioningError(4, "Connection error")
//                     }
//                 }
//                 disconnect(null)
//                 return
//             }
            
//             when (newState) {
//                 BluetoothProfile.STATE_CONNECTED -> {
//                     Log.i(TAG, "Connected to GATT server.")
//                     handler.post {
//                         methodChannel.invokeMethod("onConnectionStateChange", "connected")
//                     }
//                     isServiceDiscoveryComplete = false
//                     serviceDiscoveryRetries = 0
                    
//                     // Slight delay before discovering services
//                     handler.postDelayed({
//                         gatt.discoverServices()
//                     }, 300)
//                 }
//                 BluetoothProfile.STATE_DISCONNECTED -> {
//                     Log.i(TAG, "Disconnected from GATT server.")
//                     handler.post {
//                         methodChannel.invokeMethod("onConnectionStateChange", "disconnected")
//                         if (currentProvisioningState != ProvisioningState.IDLE && 
//                             currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE) {
//                             handleProvisioningError(4, "Disconnected")
//                         }
//                     }
//                     disconnect(null)
//                 }
//             }
//         }

//         @SuppressLint("MissingPermission")
//         override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
//             Log.d(TAG, "onServicesDiscovered status: $status")
//             if (status != BluetoothGatt.GATT_SUCCESS) {
//                 Log.e(TAG, "Service discovery failed: $status")
//                 initiateServiceDiscovery()
//                 return
//             }

//             Log.i(TAG, "Services discovered successfully")
//             logAvailableServices(gatt)

//             val provisioningService = gatt.getService(PROVISIONING_SERVICE_UUID)
//             if (provisioningService == null) {
//                 Log.e(TAG, "Provisioning service not found")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Provisioning service not found")
//                 }
//                 initiateServiceDiscovery()
//                 return
//             }

//             provisioningDataInCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_IN_UUID)
//             provisioningDataOutCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_OUT_UUID)

//             if (provisioningDataInCharacteristic == null || provisioningDataOutCharacteristic == null) {
//                 Log.e(TAG, "Required characteristics not found")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Required characteristics not found")
//                 }
//                 initiateServiceDiscovery()
//                 return
//             }

//             // Enable notifications for Data Out
//             val enableNotification = gatt.setCharacteristicNotification(provisioningDataOutCharacteristic!!, true)
//             if (!enableNotification) {
//                 Log.e(TAG, "Failed to enable notifications")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Failed to enable notifications")
//                 }
//                 initiateServiceDiscovery()
//                 return
//             }

//             val descriptor = provisioningDataOutCharacteristic?.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID)
//             if (descriptor == null) {
//                 Log.e(TAG, "Notification descriptor not found")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Notification descriptor not found")
//                 }
//                 initiateServiceDiscovery()
//                 return
//             }

//             descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            
//             // Write descriptor with proper error handling
//             if (!gatt.writeDescriptor(descriptor)) {
//                 Log.e(TAG, "Failed to write descriptor")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Failed to write descriptor")
//                 }
//                 initiateServiceDiscovery()
//                 return
//             }

//             isServiceDiscoveryComplete = true
//             handler.post {
//                 methodChannel.invokeMethod("onProvisioningServiceFound", null)
//             }
//         }

//         override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
//             super.onDescriptorWrite(gatt, descriptor, status)
//             if (descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG_UUID) {
//                 if (status == BluetoothGatt.GATT_SUCCESS) {
//                     Log.d(TAG, "Notifications enabled successfully")
//                 } else {
//                     Log.e(TAG, "Failed to enable notifications")
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Failed to enable notifications")
//                         methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                             "errorCode" to 7,
//                             "message" to "Failed to enable notifications"
//                         ))
//                     }
//                 }
//             }
//         }

//         @SuppressLint("MissingPermission")
//         override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
//             val value = characteristic.value
//             if (value != null && value.isNotEmpty()) {
//                 // Strip Proxy header (0x03) if present
//                 val pduData = if (value[0].toInt() == 0x03) {
//                     value.copyOfRange(1, value.size)
//                 } else {
//                     value
//                 }

//                 Log.d(TAG, "Received PDU (state=$currentProvisioningState): ${pduData.joinToString { "0x%02X".format(it) }}")

//                 when (pduData[0].toInt()) {
//                     0x01 -> { // Capabilities
//                         if (currentProvisioningState == ProvisioningState.PROVISIONING_INVITE) {
//                             Log.d(TAG, "Received valid Capabilities PDU")
//                             handler.post {
//                                 methodChannel.invokeMethod("onProvisioningCapabilities",
//                                     pduData.slice(1 until pduData.size).toByteArray())
//                             }
//                             // Don't change state here - let Flutter decide when to send START
//                         } else {
//                             Log.w(TAG, "Received Capabilities PDU in wrong state: $currentProvisioningState")
//                         }
//                     }
                    
//                     0x04 -> { // Public Key
//                         if (currentProvisioningState == ProvisioningState.PROVISIONING_START || 
//                             currentProvisioningState == ProvisioningState.PROVISIONING_PUBLIC_KEY_SENT) {
                            
//                             Log.d(TAG, "Received valid Public Key PDU")
//                             currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_RECEIVED
//                             handler.post {
//                                 methodChannel.invokeMethod("onProvisioningPublicKey",
//                                     pduData.slice(1 until pduData.size).toByteArray())
//                             }
//                         } else {
//                             Log.w(TAG, "Received Public Key PDU in wrong state: $currentProvisioningState")
//                         }
//                     }
                    
//                     0x05 -> { // Confirmation
//                         if (currentProvisioningState == ProvisioningState.PROVISIONING_CONFIRMATION_SENT) {
//                             Log.d(TAG, "Received valid Confirmation PDU")
//                             currentProvisioningState = ProvisioningState.PROVISIONING_CONFIRMATION_RECEIVED
//                             handler.post {
//                                 methodChannel.invokeMethod("onProvisioningConfirmation",
//                                     pduData.slice(1 until pduData.size).toByteArray())
//                             }
//                         } else {
//                             Log.w(TAG, "Received Confirmation PDU in wrong state: $currentProvisioningState")
//                         }
//                     }
                    
//                     0x06 -> { // Random
//                         if (currentProvisioningState == ProvisioningState.PROVISIONING_RANDOM_SENT) {
//                             Log.d(TAG, "Received valid Random PDU")
//                             currentProvisioningState = ProvisioningState.PROVISIONING_RANDOM_RECEIVED
//                             handler.post {
//                                 methodChannel.invokeMethod("onProvisioningRandom",
//                                     pduData.slice(1 until pduData.size).toByteArray())
//                             }
//                         } else {
//                             Log.w(TAG, "Received Random PDU in wrong state: $currentProvisioningState")
//                         }
//                     }
                    
//                     0x08 -> { // Complete
//                         Log.d(TAG, "Received Complete PDU")
//                         currentProvisioningState = ProvisioningState.PROVISIONING_COMPLETE
//                         cancelProvisioningTimeout()
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningComplete", null)
//                         }
//                     }
                    
//                     0x09 -> { // Failed
//                         Log.e(TAG, "Received Failed PDU with reason: ${pduData[1].toInt()}")
//                         currentProvisioningState = ProvisioningState.PROVISIONING_FAILED
//                         cancelProvisioningTimeout()
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningFailed", mapOf(
//                                 "errorCode" to pduData[1].toInt(),
//                                 "message" to getProvisioningFailureMessage(pduData[1].toInt())
//                             ))
//                         }
//                     }
                    
//                     else -> {
//                         Log.w(TAG, "Unknown PDU type: ${pduData[0].toInt()}")
//                     }
//                 }
//             }
//         }

//         override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
//             if (status == BluetoothGatt.GATT_SUCCESS) {
//                 handler.post {
//                     methodChannel.invokeMethod("onCharacteristicRead", characteristic.value)
//                 }
//             } else {
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Characteristic read failed")
//                 }
//             }
//         }

//         override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
//             if (status == BluetoothGatt.GATT_SUCCESS) {
//                 Log.d(TAG, "Characteristic write successful")
//                 handler.post {
//                     methodChannel.invokeMethod("onCharacteristicWrite", mapOf(
//                         "status" to "success",
//                         "characteristic" to characteristic.uuid.toString()
//                     ))
//                 }
//             } else {
//                 Log.e(TAG, "Characteristic write failed: $status")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Characteristic write failed")
//                 }
//             }
//         }
//     }

//     private fun getProvisioningFailureMessage(errorCode: Int): String {
//         return when (errorCode) {
//             0x00 -> "Prohibited"
//             0x01 -> "Invalid PDU"
//             0x02 -> "Invalid format"
//             0x03 -> "Unexpected PDU"
//             0x04 -> "Confirmation failed"
//             0x05 -> "Out of resources"
//             0x06 -> "Decryption failed"
//             0x07 -> "Unexpected error"
//             0x08 -> "Cannot assign addresses"
//             else -> "Unknown error"
//         }
//     }

//     private enum class ProvisioningState {
//         IDLE,
//                 PROVISIONING_INVITE,
//                 PROVISIONING_CAPABILITIES,
//                 PROVISIONING_START,
//                 PROVISIONING_PUBLIC_KEY_SENT,
//                 PROVISIONING_PUBLIC_KEY_WAITING,
//                 PROVISIONING_PUBLIC_KEY_RECEIVED,
//                 PROVISIONING_AUTHENTICATION_INPUT_OOB_WAITING,
//                 PROVISIONING_AUTHENTICATION_OUTPUT_OOB_WAITING,
//                 PROVISIONING_AUTHENTICATION_STATIC_OOB_WAITING,
//                 PROVISIONING_AUTHENTICATION_INPUT_ENTERED,
//                 PROVISIONING_INPUT_COMPLETE,
//                 PROVISIONING_CONFIRMATION_SENT,
//                 PROVISIONING_CONFIRMATION_RECEIVED,
//                 PROVISIONING_RANDOM_SENT,
//                 PROVISIONING_RANDOM_RECEIVED,
//                 PROVISIONING_DATA_SENT,
//                 PROVISIONING_COMPLETE,
//                 PROVISIONING_FAILED}}





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
    private val EXPECTED_DATA_SIZE = 32

    // Timeouts and retry configurations
    private val PROVISIONING_TIMEOUT = 30000L // 30 seconds overall timeout
    private val PDU_EXCHANGE_TIMEOUT = 10000L // 10 seconds for PDU exchanges
    private val MAX_RETRIES = 3
    private val MAX_SERVICE_DISCOVERY_RETRIES = 5
    private val SERVICE_DISCOVERY_TIMEOUT = 10000L // 10 seconds
    
    // State tracking variables
    private var currentProvisioningState: ProvisioningState = ProvisioningState.IDLE
    private lateinit var provisioningDevice: BluetoothDevice
    private var isServiceDiscoveryComplete = false
    private var retryCount = 0
    private var serviceDiscoveryRetries = 0
    private var provisioningTimeoutRunnable: Runnable? = null
    private var isProvisioningTimeout = false
    
    // BLE Mesh UUIDs
    private val PROVISIONING_SERVICE_UUID = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")
    private val PROVISIONING_DATA_IN_UUID = UUID.fromString("00002adb-0000-1000-8000-00805f9b34fb")
    private val PROVISIONING_DATA_OUT_UUID = UUID.fromString("00002adc-0000-1000-8000-00805f9b34fb")
    private val CLIENT_CHARACTERISTIC_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    
    private var provisioningDataOutCharacteristic: BluetoothGattCharacteristic? = null
    private var provisioningDataInCharacteristic: BluetoothGattCharacteristic? = null

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
            pendingResult?.error("BLE_SCANNER_NULL", "Bluetooth LE Scanner is null", null)
            return
        }

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device
                if (device == null) {
                    Log.d("BLE_SCAN", "Device is null")
                    return
                }

                var isMesh = false
                var provisioningServiceUuid: String? = null
                result.scanRecord?.serviceUuids?.forEach {
                    when (it.uuid.toString().lowercase()) {
                        "00001827-0000-1000-8000-00805f9b34fb" -> {
                            isMesh = true
                            provisioningServiceUuid = "1827"
                        }
                        "00001828-0000-1000-8000-00805f9b34fb" -> {
                            isMesh = true
                            provisioningServiceUuid = "1828"
                        }
                    }
                }

                val deviceInfo = mapOf(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "isMesh" to isMesh,
                    "provisioningServiceUuid" to provisioningServiceUuid
                )

                handler.post {
                    methodChannel.invokeMethod("onDeviceFound", deviceInfo)
                }
            }

            override fun onScanFailed(errorCode: Int) {
                handler.post {
                    methodChannel.invokeMethod("onError", "Scan failed with error code: $errorCode")
                    pendingResult?.error("SCAN_FAILED", "Scan failed with error code: $errorCode", null)
                }
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

        try {
            val device = bluetoothAdapter.getRemoteDevice(address)
            disconnect(null)
            gatt = device.connectGatt(context, false, gattCallback)
            result.success(null)
        } catch (e: IllegalArgumentException) {
            result.error("DEVICE_NOT_FOUND", "Could not find device with address $address", e.message)
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", "Error connecting to device: ${e.message}", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(result: MethodChannel.Result?) {
        cancelProvisioningTimeout()
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        isServiceDiscoveryComplete = false
        provisioningDataOutCharacteristic = null
        provisioningDataInCharacteristic = null
        currentProvisioningState = ProvisioningState.IDLE
        result?.success(null)
    }

    private fun cancelProvisioningTimeout() {
        provisioningTimeoutRunnable?.let { handler.removeCallbacks(it) }
        provisioningTimeoutRunnable = null
        isProvisioningTimeout = false
    }

    @SuppressLint("MissingPermission")
    private fun startProvisioning(address: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
            ) {
                result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
                return
            }

            provisioningDevice = bluetoothAdapter.getRemoteDevice(address)
                ?: return result.error("DEVICE_NOT_FOUND", "Device not found", null)

            disconnect(null)
            // Reset all state variables
            currentProvisioningState = ProvisioningState.PROVISIONING_INVITE
            retryCount = 0
            serviceDiscoveryRetries = 0
            isProvisioningTimeout = false
            isServiceDiscoveryComplete = false

            // Set overall provisioning timeout
            provisioningTimeoutRunnable = Runnable {
                Log.e(TAG, "Provisioning timed out after ${PROVISIONING_TIMEOUT/1000} seconds")
                isProvisioningTimeout = true
                handler.post {
                    methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                        "errorCode" to 1, // Error code 1 for timeout
                        "message" to "Provisioning timed out"
                    ))
                }
                disconnect(null)
            }
            handler.postDelayed(provisioningTimeoutRunnable!!, PROVISIONING_TIMEOUT)

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
            if (currentProvisioningState != ProvisioningState.PROVISIONING_INVITE) {
                return result.error("INVALID_STATE", "Not in invitation state", null)
            }

            if (attentionDuration < 0 || attentionDuration > 255) {
                return result.error("INVALID_PARAMETER", "Attention duration must be 0-255", null)
            }

            // Correctly formatted invitation PDU
            val invitePdu = byteArrayOf(0x00, attentionDuration.toByte())
            writeProvisioningCharacteristic(invitePdu)

            // State transition will happen when we receive capabilities response
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_INVITE_FAILED", "Failed to send invite: ${e.message}", null)
        }
    }
    private fun sendProvisioningStart(result: MethodChannel.Result) {
        try {
            if (currentProvisioningState != ProvisioningState.PROVISIONING_START) {
                return result.error("INVALID_STATE", "Not in start state", null)
            }
    
            // Example: Using No OOB Public Key and Static OOB Authentication
            val startPdu = byteArrayOf(
                0x02,   // Start opcode
                0x00,   // Algorithm: FIPS P-256
                0x00,   // Public Key: No OOB
                0x01,   // Auth Method: Static OOB
                0x00,   // Auth Action: Not applicable for Static OOB
                0x00    // Auth Size: 0 (no OOB data)
            )
            writeProvisioningCharacteristic(startPdu)
            currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_SENT
            result.success(null)
        } catch (e: Exception) {
            result.error("START_FAILED", "Failed to send start: ${e.message}", null)
        }
    }
    // private fun sendProvisioningStart(result: MethodChannel.Result) {
    //     try {
    //         if (currentProvisioningState != ProvisioningState.PROVISIONING_START) {
    //             return result.error("INVALID_STATE", "Not in start state", null)
    //         }

    //         val startPdu = byteArrayOf(
    //             0x02, // Start opcode
    //             0x00, // Algorithm: FIPS P-256
    //             0x00, // Public Key: No OOB
    //             0x00, // Auth Method: No OOB
    //             0x00, // Auth Action: No input
    //             0x00  // Auth Size: 0
    //         )
    //         writeProvisioningCharacteristic(startPdu)
    //         currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_SENT
    //         result.success(null)
    //     } catch (e: Exception) {
    //         result.error("START_FAILED", "Failed to send start: ${e.message}", null)
    //     }
    // }

    private fun sendProvisioningPublicKey(publicKey: ByteArray, result: MethodChannel.Result) {
        try {
            if (currentProvisioningState != ProvisioningState.PROVISIONING_PUBLIC_KEY_SENT) {
                return result.error("INVALID_STATE", "Not in public key exchange state", null)
            }

            if (publicKey.size != 64) {
                return result.error("INVALID_KEY", "Public key must be 64 bytes", null)
            }

            val keyPdu = byteArrayOf(0x03) + publicKey
            writeProvisioningCharacteristic(keyPdu)
            currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_WAITING
            result.success(null)
        } catch (e: Exception) {
            result.error("KEY_FAILED", "Failed to send public key: ${e.message}", null)
        }
    }

    private fun sendProvisioningConfirmation(confirmation: ByteArray, result: MethodChannel.Result) {
        try {
            if (currentProvisioningState != ProvisioningState.PROVISIONING_CONFIRMATION_SENT) {
                return result.error("INVALID_STATE", "Not in confirmation state", null)
            }

            if (confirmation.size != 16) {
                return result.error("INVALID_CONFIRMATION", "Confirmation must be 16 bytes", null)
            }

            val confirmationPdu = byteArrayOf(0x05) + confirmation
            writeProvisioningCharacteristic(confirmationPdu)
            currentProvisioningState = ProvisioningState.PROVISIONING_CONFIRMATION_RECEIVED
            result.success(null)
        } catch (e: Exception) {
            result.error("CONFIRMATION_FAILED", "Failed to send confirmation: ${e.message}", null)
        }
    }

    private fun sendProvisioningRandom(random: ByteArray, result: MethodChannel.Result) {
        try {
            if (currentProvisioningState != ProvisioningState.PROVISIONING_RANDOM_SENT) {
                return result.error("INVALID_STATE", "Not in random state", null)
            }

            if (random.size != 16) {
                return result.error("INVALID_RANDOM", "Random must be 16 bytes", null)
            }

            val randomPdu = byteArrayOf(0x06) + random
            writeProvisioningCharacteristic(randomPdu)
            currentProvisioningState = ProvisioningState.PROVISIONING_RANDOM_RECEIVED
            result.success(null)
        } catch (e: Exception) {
            result.error("RANDOM_FAILED", "Failed to send random: ${e.message}", null)
        }
    }

    private fun sendProvisioningData(provisioningData: ByteArray, result: MethodChannel.Result) {
        try {
            if (currentProvisioningState != ProvisioningState.PROVISIONING_DATA_SENT) {
                return result.error("INVALID_STATE", "Not in data state", null)
            }

            if (provisioningData.size != EXPECTED_DATA_SIZE) {
                return result.error("INVALID_DATA", "Provisioning data must be $EXPECTED_DATA_SIZE bytes", null)
            }

            val dataPdu = byteArrayOf(0x07) + provisioningData
            writeProvisioningCharacteristic(dataPdu)
            currentProvisioningState = ProvisioningState.PROVISIONING_COMPLETE
            result.success(null)
        } catch (e: Exception) {
            result.error("DATA_FAILED", "Failed to send provisioning data: ${e.message}", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeProvisioningCharacteristic(data: ByteArray) {
        try {
            if (isProvisioningTimeout) {
                Log.e(TAG, "Provisioning already timed out, ignoring write operation")
                handler.post {
                    methodChannel.invokeMethod("onError", "Provisioning already timed out")
                }
                return
            }

            if (!isServiceDiscoveryComplete) {
                Log.w(TAG, "Service discovery not complete, initiating discovery...")
                initiateServiceDiscovery()
                // Retry the write after a delay
                handler.postDelayed({ writeProvisioningCharacteristic(data) }, 2000)
                return
            }

            val gattLocal = gatt ?: throw IllegalStateException("GATT is null")
            val characteristic = provisioningDataInCharacteristic
                ?: throw IllegalStateException("Provisioning characteristic is null")
                characteristic.value = data  // Send raw PDU without header
            // For PB-GATT, Proxy PDU header should be 0x03
            val proxyPdu = byteArrayOf(0x03) + data

            Log.d(TAG, "Writing Proxy PDU: ${proxyPdu.joinToString { "0x%02X".format(it) }}")

            characteristic.value = proxyPdu
            val writeResult = gattLocal.writeCharacteristic(characteristic)

            if (writeResult) {
                Log.i(TAG, "Proxy PDU write initiated successfully")
                // Set timeout for response
                handler.postDelayed({
                    if (currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE &&
                        currentProvisioningState != ProvisioningState.PROVISIONING_FAILED) {
                        Log.e(TAG, "PDU exchange timed out")
                        handler.post {
                            methodChannel.invokeMethod("onError", "PDU exchange timed out")
                            methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                                "errorCode" to 5, // Error code 5 for PDU timeout
                                "message" to "PDU exchange timed out"
                            ))
                        }
                        disconnect(null)
                    }
                }, PDU_EXCHANGE_TIMEOUT)
            } else {
                Log.e(TAG, "Proxy PDU write failed to initiate")

                if (retryCount < MAX_RETRIES) {
                    retryCount++
                    Log.w(TAG, "Retrying write operation (Attempt $retryCount)")
                    handler.postDelayed({ writeProvisioningCharacteristic(data) }, 500L * retryCount)
                } else {
                    retryCount = 0
                    handler.post {
                        methodChannel.invokeMethod("onError", "Failed to write Proxy PDU after $MAX_RETRIES attempts")
                        methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                            "errorCode" to 2, // Error code 2 for write failure
                            "message" to "Failed to write Proxy PDU"
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing Proxy PDU: ${e.message}", e)
            handler.post {
                methodChannel.invokeMethod("onError", "Error writing Proxy PDU: ${e.message}")
                methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                    "errorCode" to 6, // Error code 6 for general write error
                    "message" to "Error writing Proxy PDU"
                ))
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun initiateServiceDiscovery() {
        if (serviceDiscoveryRetries < MAX_SERVICE_DISCOVERY_RETRIES) {
            serviceDiscoveryRetries++
            Log.w(TAG, "Initiating service discovery (Attempt $serviceDiscoveryRetries)")
            gatt?.discoverServices()

            handler.postDelayed({
                if (!isServiceDiscoveryComplete && gatt != null) {
                    Log.e(TAG, "Service discovery timed out")
                    handler.post {
                        methodChannel.invokeMethod("onError", "Service discovery timed out")
                        methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                            "errorCode" to 3, // Error code 3 for service discovery failure
                            "message" to "Service discovery timed out"
                        ))
                    }
                    disconnect(null)
                }
            }, SERVICE_DISCOVERY_TIMEOUT)
        } else {
            Log.e(TAG, "Service discovery failed after $MAX_SERVICE_DISCOVERY_RETRIES attempts")
            handler.post {
                methodChannel.invokeMethod("onError", "Service discovery failed after multiple attempts")
                methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                    "errorCode" to 3, // Error code 3 for service discovery failure
                    "message" to "Service discovery failed"
                ))
            }
            disconnect(null)
        }
    }

    private fun logAvailableServices(gatt: BluetoothGatt) {
        Log.d(TAG, "=== Available Services ===")
        gatt.services.forEach { service ->
            Log.d(TAG, "Service UUID: ${service.uuid}")
            service.characteristics.forEach { characteristic ->
                Log.d(TAG, "  └── Characteristic UUID: ${characteristic.uuid}")
                Log.d(TAG, "      Properties: ${getCharacteristicProperties(characteristic)}")
            }
        }
        Log.d(TAG, "=====================")
    }

    private fun getCharacteristicProperties(characteristic: BluetoothGattCharacteristic): String {
        val props = mutableListOf<String>()
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) props.add("READ")
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) props.add("WRITE")
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) props.add("NOTIFY")
        if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) props.add("INDICATE")
        return props.joinToString(", ")
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.e(TAG, "Connection state change error: $status")
                handler.post {
                    methodChannel.invokeMethod("onError", "Connection error: $status")
                    methodChannel.invokeMethod("onConnectionStateChange", "error")
                    if (currentProvisioningState != ProvisioningState.IDLE && 
                        currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE) {
                        methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                            "errorCode" to 4, // Error code 4 for connection failure
                            "message" to "Connection error"
                        ))
                    }
                }
                disconnect(null)
                return
            }
            
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.i(TAG, "Connected to GATT server.")
                    handler.post {
                        methodChannel.invokeMethod("onConnectionStateChange", "connected")
                    }
            gatt.requestMtu(247)
                    isServiceDiscoveryComplete = false
                    serviceDiscoveryRetries = 0
                    
                    // Slight delay before discovering services
                    handler.postDelayed({
                        gatt.discoverServices()
                    }, 300)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.i(TAG, "Disconnected from GATT server.")
                    handler.post {
                        methodChannel.invokeMethod("onConnectionStateChange", "disconnected")
                        if (currentProvisioningState != ProvisioningState.IDLE && 
                            currentProvisioningState != ProvisioningState.PROVISIONING_COMPLETE) {
                            methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                                "errorCode" to 4, // Error code 4 for connection failure
                                "message" to "Disconnected"
                            ))
                        }
                    }
                    disconnect(null)
                }
            }
        }

        // Handle MTU change
override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
    if (status == BluetoothGatt.GATT_SUCCESS) {
        Log.d(TAG, "MTU updated to $mtu")
        // Proceed with service discovery after MTU negotiation
        handler.postDelayed({ gatt.discoverServices() }, 300)
    } else {
        Log.e(TAG, "MTU change failed")
    }
}

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.i(TAG, "Services discovered successfully")
                logAvailableServices(gatt)

                val provisioningService = gatt.getService(PROVISIONING_SERVICE_UUID)
                if (provisioningService != null) {
                    provisioningDataInCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_IN_UUID)
                    provisioningDataOutCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_OUT_UUID)

                    if (provisioningDataInCharacteristic != null && provisioningDataOutCharacteristic != null) {
                        gatt.setCharacteristicNotification(provisioningDataOutCharacteristic!!, true)
                        
                        val descriptor = provisioningDataOutCharacteristic?.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID)
                        descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                        
                        isServiceDiscoveryComplete = true
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningServiceFound", null)
                        }
                    } else {
                        Log.e(TAG, "Required characteristics not found")
                        handler.post {
                            methodChannel.invokeMethod("onError", "Required characteristics not found")
                            methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                                "errorCode" to 3, // Error code 3 for service discovery failure
                                "message" to "Characteristics not found"
                            ))
                        }
                        initiateServiceDiscovery()
                    }
                } else {
                    Log.e(TAG, "Provisioning service not found")
                    handler.post {
                        methodChannel.invokeMethod("onError", "Provisioning service not found")
                        methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                            "errorCode" to 3, // Error code 3 for service discovery failure
                            "message" to "Service not found"
                        ))
                    }
                    initiateServiceDiscovery()
                }
            } else {
                Log.w(TAG, "Service discovery failed with status: $status")
                initiateServiceDiscovery()
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            super.onDescriptorWrite(gatt, descriptor, status)
            if (descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG_UUID) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Notifications enabled successfully")
                } else {
                    Log.e(TAG, "Failed to enable notifications")
                    handler.post {
                        methodChannel.invokeMethod("onError", "Failed to enable notifications")
                        methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                            "errorCode" to 7, // Error code 7 for notification setup failure
                            "message" to "Failed to enable notifications"
                        ))
                    }
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val value = characteristic.value
            if (value != null && value.isNotEmpty()) {
                // Strip Proxy header (0x03) if present
                val pduData = if (value[0].toInt() == 0x03) {
                    value.copyOfRange(1, value.size)
                } else {
                    value
                }

                Log.d(TAG, "Received PDU: ${pduData.joinToString { "0x%02X".format(it) }}")

                when (pduData[0].toInt()) {
                    0x01 -> { // Capabilities
                        Log.d(TAG, "Received Capabilities PDU")
                        Log.d(TAG, "State transition: $currentProvisioningState -> PROVISIONING_START")
                        currentProvisioningState = ProvisioningState.PROVISIONING_START // Change to START state
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningCapabilities",
                                pduData.slice(1 until pduData.size).toByteArray())
                        }
                    }
                    
                    0x04 -> { // Public Key
                        Log.d(TAG, "Received Public Key PDU")
                        currentProvisioningState = ProvisioningState.PROVISIONING_PUBLIC_KEY_RECEIVED
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningPublicKey",
                                pduData.slice(1 until pduData.size).toByteArray())
                        }
                    }
                    0x05 -> { // Confirmation
                        Log.d(TAG, "Received Confirmation PDU")
                        currentProvisioningState = ProvisioningState.PROVISIONING_CONFIRMATION_RECEIVED
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningConfirmation",
                                pduData.slice(1 until pduData.size).toByteArray())
                        }
                    }
                    0x06 -> { // Random
                        Log.d(TAG, "Received Random PDU")
                        currentProvisioningState = ProvisioningState.PROVISIONING_RANDOM_RECEIVED
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningRandom",
                                pduData.slice(1 until pduData.size).toByteArray())
                        }
                    }
                    0x08 -> { // Complete
                        Log.d(TAG, "Received Complete PDU")
                        currentProvisioningState = ProvisioningState.PROVISIONING_COMPLETE
                        cancelProvisioningTimeout()
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningComplete", null)
                        }
                    }
                    0x09 -> { // Failed
                        Log.e(TAG, "Received Failed PDU with reason: ${pduData[1].toInt()}")
                        currentProvisioningState = ProvisioningState.PROVISIONING_FAILED
                        cancelProvisioningTimeout()
                        handler.post {
                            methodChannel.invokeMethod("onProvisioningFailed", mapOf(
                                "errorCode" to pduData[1].toInt(),
                                "message" to getProvisioningFailureMessage(pduData[1].toInt())
                            ))
                        }
                    }
                    else -> {
                        Log.w(TAG, "Unknown PDU type: ${pduData[0].toInt()}")
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
                    methodChannel.invokeMethod("onCharacteristicWrite", mapOf(
                        "status" to "success",
                        "characteristic" to characteristic.uuid.toString()
                    ))
                }
            } else {
                handler.post {
                    methodChannel.invokeMethod("onError", "Characteristic write failed")
                }
            }
        }
    }

    private fun getProvisioningFailureMessage(errorCode: Int): String {
        return when (errorCode) {
            0x00 -> "Prohibited"
            0x01 -> "Invalid PDU"
            0x02 -> "Invalid format"
            0x03 -> "Unexpected PDU"
            0x04 -> "Confirmation failed"
            0x05 -> "Out of resources"
            0x06 -> "Decryption failed"
            0x07 -> "Unexpected error"
            0x08 -> "Cannot assign addresses"
            else -> "Unknown error"
        }
    }

    private enum class ProvisioningState {
        IDLE,
        PROVISIONING_INVITE,
        PROVISIONING_CAPABILITIES,
        PROVISIONING_START,
        PROVISIONING_PUBLIC_KEY_SENT,
        PROVISIONING_PUBLIC_KEY_WAITING,
        PROVISIONING_PUBLIC_KEY_RECEIVED,
        PROVISIONING_AUTHENTICATION_INPUT_OOB_WAITING,
        PROVISIONING_AUTHENTICATION_OUTPUT_OOB_WAITING,
        PROVISIONING_AUTHENTICATION_STATIC_OOB_WAITING,
        PROVISIONING_AUTHENTICATION_INPUT_ENTERED,
        PROVISIONING_INPUT_COMPLETE,
        PROVISIONING_CONFIRMATION_SENT,
        PROVISIONING_CONFIRMATION_RECEIVED,
        PROVISIONING_RANDOM_SENT,
        PROVISIONING_RANDOM_RECEIVED,
        PROVISIONING_DATA_SENT,
        PROVISIONING_COMPLETE,
        PROVISIONING_FAILED
    }
}


// package com.example.ble_testing

// import android.Manifest
// import android.annotation.SuppressLint
// import android.bluetooth.*
// import android.bluetooth.le.ScanCallback
// import android.bluetooth.le.ScanResult
// import android.bluetooth.le.ScanSettings
// import android.content.Context
// import android.content.pm.PackageManager
// import android.os.Build
// import android.os.Handler
// import android.os.Looper
// import androidx.core.app.ActivityCompat
// import androidx.core.content.ContextCompat
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import android.app.Activity
// import android.content.ContentValues.TAG
// import android.util.Log
// import java.util.*

// class BleScanner(private val context: Context, flutterEngine: FlutterEngine) {
//     private val CHANNEL = "com.example.ble_scanner/ble"
//     private val bluetoothAdapter: BluetoothAdapter
//     private val methodChannel: MethodChannel

//     private val PERMISSION_REQUEST_CODE = 1
//     private var pendingResult: MethodChannel.Result? = null
//     private var scanCallback: ScanCallback? = null
//     private var gatt: BluetoothGatt? = null
//     private val handler = Handler(Looper.getMainLooper())
//     private val EXPECTED_DATA_SIZE = 32

//     // Timeouts and retry configurations
//     private val PROVISIONING_TIMEOUT = 30000L // 30 seconds overall timeout
//     private val PDU_EXCHANGE_TIMEOUT = 5000L // 5 seconds for PDU exchanges
//     private val MAX_RETRIES = 3
//     private val MAX_SERVICE_DISCOVERY_RETRIES = 5
//     private val SERVICE_DISCOVERY_TIMEOUT = 10000L // 10 seconds
    
//     // State tracking variables
//     private var provisioningState: ProvisioningState = ProvisioningState.IDLE
//     private lateinit var provisioningDevice: BluetoothDevice
//     private var isServiceDiscoveryComplete = false
//     private var retryCount = 0
//     private var serviceDiscoveryRetries = 0
//     private var provisioningTimeoutRunnable: Runnable? = null
//     private var isProvisioningTimeout = false
    
//     // BLE Mesh UUIDs
//     private val PROVISIONING_SERVICE_UUID = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")
//     private val PROVISIONING_DATA_IN_UUID = UUID.fromString("00002adb-0000-1000-8000-00805f9b34fb")
//     private val PROVISIONING_DATA_OUT_UUID = UUID.fromString("00002adc-0000-1000-8000-00805f9b34fb")
//     private val CLIENT_CHARACTERISTIC_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    
//     private var provisioningDataOutCharacteristic: BluetoothGattCharacteristic? = null
//     private var provisioningDataInCharacteristic: BluetoothGattCharacteristic? = null

//     init {
//         val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
//         bluetoothAdapter = bluetoothManager.adapter
//         methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

//         methodChannel.setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "startScan" -> {
//                     pendingResult = result
//                     checkAndRequestPermissions()
//                 }
//                 "stopScan" -> stopScan(result)
//                 "connect" -> {
//                     val deviceAddress = call.argument<String>("address")
//                     if (deviceAddress != null) {
//                         connectToDevice(deviceAddress, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Device address is required", null)
//                     }
//                 }
//                 "disconnect" -> disconnect(result)
//                 "startProvisioning" -> {
//                     val deviceAddress = call.argument<String>("address")
//                     if (deviceAddress != null) {
//                         startProvisioning(deviceAddress, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Device address is required", null)
//                     }
//                 }
//                 "sendProvisioningInvite" -> {
//                     val attentionDuration = call.argument<Int>("attentionDuration")
//                     if (attentionDuration != null) {
//                         sendProvisioningInvite(attentionDuration, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Attention duration is required", null)
//                     }
//                 }
//                 "sendProvisioningStart" -> sendProvisioningStart(result)
//                 "sendProvisioningPublicKey" -> {
//                     val publicKey = call.argument<ByteArray>("publicKey")
//                     if (publicKey != null) {
//                         sendProvisioningPublicKey(publicKey, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Public key is required", null)
//                     }
//                 }
//                 "sendProvisioningConfirmation" -> {
//                     val confirmation = call.argument<ByteArray>("confirmation")
//                     if (confirmation != null) {
//                         sendProvisioningConfirmation(confirmation, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Confirmation data is required", null)
//                     }
//                 }
//                 "sendProvisioningRandom" -> {
//                     val random = call.argument<ByteArray>("random")
//                     if (random != null) {
//                         sendProvisioningRandom(random, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Random data is required", null)
//                     }
//                 }
//                 "sendProvisioningData" -> {
//                     val provisioningData = call.argument<ByteArray>("provisioningData")
//                     if (provisioningData != null) {
//                         sendProvisioningData(provisioningData, result)
//                     } else {
//                         result.error("INVALID_ARGUMENT", "Provisioning data is required", null)
//                     }
//                 }
//                 else -> result.notImplemented()
//             }
//         }
//     }

//     private fun checkAndRequestPermissions() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
//             val permissions = arrayOf(
//                 Manifest.permission.BLUETOOTH_SCAN,
//                 Manifest.permission.BLUETOOTH_CONNECT,
//                 Manifest.permission.ACCESS_FINE_LOCATION
//             )
//             if (!hasPermissions(context, *permissions)) {
//                 ActivityCompat.requestPermissions(
//                     context as Activity, permissions, PERMISSION_REQUEST_CODE
//                 )
//             } else {
//                 startScan()
//             }
//         } else {
//             val permissions = arrayOf(
//                 Manifest.permission.ACCESS_FINE_LOCATION,
//                 Manifest.permission.BLUETOOTH,
//                 Manifest.permission.BLUETOOTH_ADMIN
//             )
//             if (!hasPermissions(context, *permissions)) {
//                 ActivityCompat.requestPermissions(
//                     context as Activity, permissions, PERMISSION_REQUEST_CODE
//                 )
//             } else {
//                 startScan()
//             }
//         }
//     }

//     private fun hasPermissions(context: Context, vararg permissions: String): Boolean {
//         for (permission in permissions) {
//             if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
//                 return false
//             }
//         }
//         return true
//     }

//     fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
//         if (requestCode == PERMISSION_REQUEST_CODE) {
//             if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
//                 startScan()
//             } else {
//                 pendingResult?.error("PERMISSION_DENIED", "Necessary permissions were denied", null)
//             }
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun startScan() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//             ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED
//         ) {
//             pendingResult?.error("PERMISSION_DENIED", "Bluetooth scan permission not granted", null)
//             return
//         }

//         val scanner = bluetoothAdapter.bluetoothLeScanner
//         if (scanner == null) {
//             methodChannel.invokeMethod("onError", "Bluetooth LE Scanner is null, make sure Bluetooth is enabled")
//             pendingResult?.error("BLE_SCANNER_NULL", "Bluetooth LE Scanner is null", null)
//             return
//         }

//         val scanSettings = ScanSettings.Builder()
//             .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
//             .build()

//         scanCallback = object : ScanCallback() {
//             override fun onScanResult(callbackType: Int, result: ScanResult) {
//                 val device = result.device
//                 if (device == null) {
//                     Log.d("BLE_SCAN", "Device is null")
//                     return
//                 }

//                 var isMesh = false
//                 var provisioningServiceUuid: String? = null
//                 result.scanRecord?.serviceUuids?.forEach {
//                     when (it.uuid.toString().lowercase()) {
//                         "00001827-0000-1000-8000-00805f9b34fb" -> {
//                             isMesh = true
//                             provisioningServiceUuid = "1827"
//                         }
//                         "00001828-0000-1000-8000-00805f9b34fb" -> {
//                             isMesh = true
//                             provisioningServiceUuid = "1828"
//                         }
//                     }
//                 }

//                 val deviceInfo = mapOf(
//                     "name" to (device.name ?: "Unknown"),
//                     "address" to device.address,
//                     "isMesh" to isMesh,
//                     "provisioningServiceUuid" to provisioningServiceUuid
//                 )

//                 handler.post {
//                     methodChannel.invokeMethod("onDeviceFound", deviceInfo)
//                 }
//             }

//             override fun onScanFailed(errorCode: Int) {
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Scan failed with error code: $errorCode")
//                     pendingResult?.error("SCAN_FAILED", "Scan failed with error code: $errorCode", null)
//                 }
//             }
//         }

//         try {
//             scanner.startScan(null, scanSettings, scanCallback)
//             pendingResult?.success(null)
//         } catch (e: Exception) {
//             pendingResult?.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
//         } finally {
//             pendingResult = null
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun stopScan(result: MethodChannel.Result) {
//         val scanner = bluetoothAdapter.bluetoothLeScanner
//         scanCallback?.let { scanner?.stopScan(it) }
//         result.success(null)
//     }

//     @SuppressLint("MissingPermission")
//     private fun connectToDevice(address: String, result: MethodChannel.Result) {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//             ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
//         ) {
//             result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
//             return
//         }

//         try {
//             val device = bluetoothAdapter.getRemoteDevice(address)
//             disconnect(null)
//             gatt = device.connectGatt(context, false, gattCallback)
//             result.success(null)
//         } catch (e: IllegalArgumentException) {
//             result.error("DEVICE_NOT_FOUND", "Could not find device with address $address", e.message)
//         } catch (e: Exception) {
//             result.error("CONNECTION_ERROR", "Error connecting to device: ${e.message}", null)
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun disconnect(result: MethodChannel.Result?) {
//         cancelProvisioningTimeout()
//         gatt?.disconnect()
//         gatt?.close()
//         gatt = null
//         isServiceDiscoveryComplete = false
//         provisioningDataOutCharacteristic = null
//         provisioningDataInCharacteristic = null
//         provisioningState = ProvisioningState.IDLE
//         result?.success(null)
//     }

//     private fun cancelProvisioningTimeout() {
//         provisioningTimeoutRunnable?.let { handler.removeCallbacks(it) }
//         provisioningTimeoutRunnable = null
//         isProvisioningTimeout = false
//     }

//     @SuppressLint("MissingPermission")
//     private fun startProvisioning(address: String, result: MethodChannel.Result) {
//         try {
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//                 ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
//             ) {
//                 result.error("PERMISSION_DENIED", "Bluetooth connect permission not granted", null)
//                 return
//             }

//             provisioningDevice = bluetoothAdapter.getRemoteDevice(address)
//                 ?: return result.error("DEVICE_NOT_FOUND", "Device not found", null)

//             disconnect(null)
//             // Reset all state variables
//             provisioningState = ProvisioningState.INVITE
//             retryCount = 0
//             serviceDiscoveryRetries = 0
//             isProvisioningTimeout = false
//             isServiceDiscoveryComplete = false

//             // Set overall provisioning timeout
//             provisioningTimeoutRunnable = Runnable {
//                 Log.e(TAG, "Provisioning timed out after ${PROVISIONING_TIMEOUT/1000} seconds")
//                 isProvisioningTimeout = true
//                 handler.post {
//                     methodChannel.invokeMethod("onProvisioningFailed", 1) // Error code 1 for timeout
//                 }
//                 disconnect(null)
//             }
//             handler.postDelayed(provisioningTimeoutRunnable!!, PROVISIONING_TIMEOUT)

//             gatt = provisioningDevice.connectGatt(context, false, gattCallback)
//             result.success(null)
//         } catch (e: IllegalArgumentException) {
//             result.error("INVALID_ADDRESS", "Invalid Bluetooth address: $address", e.message)
//         } catch (e: Exception) {
//             result.error("START_PROVISIONING_FAILED", "Failed to start provisioning: ${e.message}", null)
//         }
//     }


//     private fun sendProvisioningInvite(attentionDuration: Int, result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.INVITE) {
//                 return result.error("INVALID_STATE", "Not in invitation state", null)
//             }

//             if (attentionDuration < 0 || attentionDuration > 255) {
//                 return result.error("INVALID_PARAMETER", "Attention duration must be 0-255", null)
//             }

//             // Correctly formatted invitation PDU
//             val invitePdu = byteArrayOf(0x00, attentionDuration.toByte())
//             writeProvisioningCharacteristic(invitePdu)

//             // Do not change state here - wait for capabilities response
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("SEND_INVITE_FAILED", "Failed to send invite: ${e.message}", null)
//         }
//     }


//     private fun sendProvisioningStart(result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.START) {
//                 return result.error("INVALID_STATE", "Not in start state", null)
//             }

//             val startPdu = byteArrayOf(
//                 0x02, // Start opcode
//                 0x00, // Algorithm: FIPS P-256
//                 0x00, // Public Key: No OOB
//                 0x00, // Auth Method: No OOB
//                 0x00, // Auth Action: No input
//                 0x00  // Auth Size: 0
//             )
//             writeProvisioningCharacteristic(startPdu)
//             provisioningState = ProvisioningState.PUBLIC_KEY_EXCHANGE
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("START_FAILED", "Failed to send start: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningPublicKey(publicKey: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.PUBLIC_KEY_EXCHANGE) {
//                 return result.error("INVALID_STATE", "Not in public key exchange state", null)
//             }

//             if (publicKey.size != 64) {
//                 return result.error("INVALID_KEY", "Public key must be 64 bytes", null)
//             }

//             val keyPdu = byteArrayOf(0x03) + publicKey
//             writeProvisioningCharacteristic(keyPdu)
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("KEY_FAILED", "Failed to send public key: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningConfirmation(confirmation: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.CONFIRMATION) {
//                 return result.error("INVALID_STATE", "Not in confirmation state", null)
//             }

//             if (confirmation.size != 16) {
//                 return result.error("INVALID_CONFIRMATION", "Confirmation must be 16 bytes", null)
//             }

//             val confirmationPdu = byteArrayOf(0x05) + confirmation
//             writeProvisioningCharacteristic(confirmationPdu)
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("CONFIRMATION_FAILED", "Failed to send confirmation: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningRandom(random: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.RANDOM) {
//                 return result.error("INVALID_STATE", "Not in random state", null)
//             }

//             if (random.size != 16) {
//                 return result.error("INVALID_RANDOM", "Random must be 16 bytes", null)
//             }

//             val randomPdu = byteArrayOf(0x06) + random
//             writeProvisioningCharacteristic(randomPdu)
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("RANDOM_FAILED", "Failed to send random: ${e.message}", null)
//         }
//     }

//     private fun sendProvisioningData(provisioningData: ByteArray, result: MethodChannel.Result) {
//         try {
//             if (provisioningState != ProvisioningState.DATA) {
//                 return result.error("INVALID_STATE", "Not in data state", null)
//             }

//             if (provisioningData.size != EXPECTED_DATA_SIZE) {
//                 return result.error("INVALID_DATA", "Provisioning data must be $EXPECTED_DATA_SIZE bytes", null)
//             }

//             val dataPdu = byteArrayOf(0x07) + provisioningData
//             writeProvisioningCharacteristic(dataPdu)
//             result.success(null)
//         } catch (e: Exception) {
//             result.error("DATA_FAILED", "Failed to send provisioning data: ${e.message}", null)
//         }
//     }

//     @SuppressLint("MissingPermission")
//     private fun writeProvisioningCharacteristic(data: ByteArray) {
//         try {
//             if (isProvisioningTimeout) {
//                 Log.e(TAG, "Provisioning already timed out, ignoring write operation")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Provisioning already timed out")
//                 }
//                 return
//             }

//             if (!isServiceDiscoveryComplete) {
//                 Log.w(TAG, "Service discovery not complete, initiating discovery...")
//                 initiateServiceDiscovery()
//                 // Retry the write after a delay
//                 handler.postDelayed({ writeProvisioningCharacteristic(data) }, 2000)
//                 return
//             }

//             val gattLocal = gatt ?: throw IllegalStateException("GATT is null")
//             val characteristic = provisioningDataInCharacteristic
//                 ?: throw IllegalStateException("Provisioning characteristic is null")

//             // IMPORTANT: Modified PDU format
//             // For PB-GATT, Proxy PDU header should be 0x03 only for data messages
//             // Check opcode in the first byte of data to determine correct PDU type
//             val proxyPdu = when (data[0].toInt()) {
//                 // For different provisioning operations, we might need different headers
//                 0x00 -> byteArrayOf(0x03) + data  // Invite
//                 0x02 -> byteArrayOf(0x03) + data  // Start
//                 0x03 -> byteArrayOf(0x03) + data  // Public Key
//                 0x05 -> byteArrayOf(0x03) + data  // Confirmation
//                 0x06 -> byteArrayOf(0x03) + data  // Random
//                 0x07 -> byteArrayOf(0x03) + data  // Data
//                 else -> data // For other operations, no header
//             }

//             Log.d(TAG, "Writing Proxy PDU: ${proxyPdu.joinToString { "0x%02X".format(it) }}")

//             characteristic.value = proxyPdu
//             val writeResult = gattLocal.writeCharacteristic(characteristic)

//             if (writeResult) {
//                 Log.i(TAG, "Proxy PDU write initiated successfully")
//                 // Set timeout for response
//                 handler.postDelayed({
//                     if (provisioningState != ProvisioningState.COMPLETE && provisioningState != ProvisioningState.FAILED) {
//                         Log.e(TAG, "PDU exchange timed out")
//                         handler.post {
//                             methodChannel.invokeMethod("onError", "PDU exchange timed out")
//                             methodChannel.invokeMethod("onProvisioningFailed", 5) // Error code 5 for PDU timeout
//                         }
//                         disconnect(null)
//                     }
//                 }, PDU_EXCHANGE_TIMEOUT)
//             } else {
//                 Log.e(TAG, "Proxy PDU write failed to initiate")

//                 if (retryCount < MAX_RETRIES) {
//                     retryCount++
//                     Log.w(TAG, "Retrying write operation (Attempt $retryCount)")
//                     handler.postDelayed({ writeProvisioningCharacteristic(data) }, 500L * retryCount)
//                 } else {
//                     retryCount = 0
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Failed to write Proxy PDU after $MAX_RETRIES attempts")
//                         methodChannel.invokeMethod("onProvisioningFailed", 2) // Error code 2 for write failure
//                     }
//                 }
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Error writing Proxy PDU: ${e.message}", e)
//             handler.post {
//                 methodChannel.invokeMethod("onError", "Error writing Proxy PDU: ${e.message}")
//                 methodChannel.invokeMethod("onProvisioningFailed", 6) // Error code 6 for general write error
//             }
//         }
//     }


//     @SuppressLint("MissingPermission")
//     private fun initiateServiceDiscovery() {
//         if (serviceDiscoveryRetries < MAX_SERVICE_DISCOVERY_RETRIES) {
//             serviceDiscoveryRetries++
//             Log.w(TAG, "Initiating service discovery (Attempt $serviceDiscoveryRetries)")
//             gatt?.discoverServices()

//             handler.postDelayed({
//                 if (!isServiceDiscoveryComplete && gatt != null) {
//                     Log.e(TAG, "Service discovery timed out")
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Service discovery timed out")
//                         methodChannel.invokeMethod("onProvisioningFailed", 3) // Error code 3 for service discovery failure
//                     }
//                     disconnect(null)
//                 }
//             }, SERVICE_DISCOVERY_TIMEOUT)
//         } else {
//             Log.e(TAG, "Service discovery failed after $MAX_SERVICE_DISCOVERY_RETRIES attempts")
//             handler.post {
//                 methodChannel.invokeMethod("onError", "Service discovery failed after multiple attempts")
//                 methodChannel.invokeMethod("onProvisioningFailed", 3) // Error code 3 for service discovery failure
//             }
//             disconnect(null)
//         }
//     }

//     private fun logAvailableServices(gatt: BluetoothGatt) {
//         Log.d(TAG, "=== Available Services ===")
//         gatt.services.forEach { service ->
//             Log.d(TAG, "Service UUID: ${service.uuid}")
//             service.characteristics.forEach { characteristic ->
//                 Log.d(TAG, "  └── Characteristic UUID: ${characteristic.uuid}")
//                 Log.d(TAG, "      Properties: ${getCharacteristicProperties(characteristic)}")
//             }
//         }
//         Log.d(TAG, "=====================")
//     }

//     private fun getCharacteristicProperties(characteristic: BluetoothGattCharacteristic): String {
//         val props = mutableListOf<String>()
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) props.add("READ")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) props.add("WRITE")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) props.add("NOTIFY")
//         if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) props.add("INDICATE")
//         return props.joinToString(", ")
//     }

//     private val gattCallback = object : BluetoothGattCallback() {
//         @SuppressLint("MissingPermission")
//         override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
//             if (status != BluetoothGatt.GATT_SUCCESS) {
//                 Log.e(TAG, "Connection state change error: $status")
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Connection error: $status")
//                     methodChannel.invokeMethod("onConnectionStateChange", "error")
//                     if (provisioningState != ProvisioningState.IDLE && provisioningState != ProvisioningState.COMPLETE) {
//                         methodChannel.invokeMethod("onProvisioningFailed", 4) // Error code 4 for connection failure
//                     }
//                 }
//                 disconnect(null)
//                 return
//             }
            
//             when (newState) {
//                 BluetoothProfile.STATE_CONNECTED -> {
//                     Log.i(TAG, "Connected to GATT server.")
//                     handler.post {
//                         methodChannel.invokeMethod("onConnectionStateChange", "connected")
//                     }
//                     isServiceDiscoveryComplete = false
//                     serviceDiscoveryRetries = 0
                    
//                     // Slight delay before discovering services
//                     handler.postDelayed({
//                         gatt?.discoverServices()
//                     }, 300)
//                 }
//                 BluetoothProfile.STATE_DISCONNECTED -> {
//                     Log.i(TAG, "Disconnected from GATT server.")
//                     handler.post {
//                         methodChannel.invokeMethod("onConnectionStateChange", "disconnected")
//                         if (provisioningState != ProvisioningState.IDLE && provisioningState != ProvisioningState.COMPLETE) {
//                             methodChannel.invokeMethod("onProvisioningFailed", 4) // Error code 4 for connection failure
//                         }
//                     }
//                     disconnect(null)
//                 }
//             }
//         }

//         @SuppressLint("MissingPermission")
//         override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
//             if (status == BluetoothGatt.GATT_SUCCESS) {
//                 Log.i(TAG, "Services discovered successfully")
//                 logAvailableServices(gatt)

//                 val provisioningService = gatt.getService(PROVISIONING_SERVICE_UUID)
//                 if (provisioningService != null) {
//                     provisioningDataInCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_IN_UUID)
//                     provisioningDataOutCharacteristic = provisioningService.getCharacteristic(PROVISIONING_DATA_OUT_UUID)

//                     if (provisioningDataInCharacteristic != null && provisioningDataOutCharacteristic != null) {
//                         gatt.setCharacteristicNotification(provisioningDataOutCharacteristic!!, true)
                        
//                         val descriptor = provisioningDataOutCharacteristic?.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID)
//                         descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
//                         gatt.writeDescriptor(descriptor)
                        
//                         isServiceDiscoveryComplete = true
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningServiceFound", null)
//                         }
//                     } else {
//                         Log.e(TAG, "Required characteristics not found")
//                         handler.post {
//                             methodChannel.invokeMethod("onError", "Required characteristics not found")
//                             methodChannel.invokeMethod("onProvisioningFailed", 3) // Error code 3 for service discovery failure
//                         }
//                         initiateServiceDiscovery()
//                     }
//                 } else {
//                     Log.e(TAG, "Provisioning service not found")
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Provisioning service not found")
//                         methodChannel.invokeMethod("onProvisioningFailed", 3) // Error code 3 for service discovery failure
//                     }
//                     initiateServiceDiscovery()
//                 }
//             } else {
//                 Log.w(TAG, "Service discovery failed with status: $status")
//                 initiateServiceDiscovery()
//             }
//         }

//         override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
//             super.onDescriptorWrite(gatt, descriptor, status)
//             if (descriptor.uuid == CLIENT_CHARACTERISTIC_CONFIG_UUID) {
//                 if (status == BluetoothGatt.GATT_SUCCESS) {
//                     Log.d(TAG, "Notifications enabled successfully")
//                 } else {
//                     Log.e(TAG, "Failed to enable notifications")
//                     handler.post {
//                         methodChannel.invokeMethod("onError", "Failed to enable notifications")
//                         methodChannel.invokeMethod("onProvisioningFailed", 7) // Error code 7 for notification setup failure
//                     }
//                 }
//             }
//         }

//         @SuppressLint("MissingPermission")
//         override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
//             val value = characteristic.value
//             if (value != null && value.isNotEmpty()) {
//                 // Strip Proxy header (0x03) if present
//                 val pduData = if (value[0].toInt() == 0x03) {
//                     value.copyOfRange(1, value.size)
//                 } else {
//                     value
//                 }

//                 Log.d(TAG, "Received PDU: ${pduData.joinToString { "0x%02X".format(it) }}")

//                 when (pduData[0].toInt()) {
//                     0x01 -> { // Capabilities
//                         Log.d(TAG, "Received Capabilities PDU")
//                         provisioningState = ProvisioningState.START
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningCapabilities",
//                                 pduData.slice(1 until pduData.size).toByteArray())
//                         }
//                     }
//                     0x04 -> { // Public Key
//                         Log.d(TAG, "Received Public Key PDU")
//                         provisioningState = ProvisioningState.CONFIRMATION
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningPublicKey",
//                                 pduData.slice(1 until pduData.size).toByteArray())
//                         }
//                     }
//                     0x05 -> { // Confirmation
//                         Log.d(TAG, "Received Confirmation PDU")
//                         provisioningState = ProvisioningState.RANDOM
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningConfirmation",
//                                 pduData.slice(1 until pduData.size).toByteArray())
//                         }
//                     }
//                     0x06 -> { // Random
//                         Log.d(TAG, "Received Random PDU")
//                         provisioningState = ProvisioningState.DATA
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningRandom",
//                                 pduData.slice(1 until pduData.size).toByteArray())
//                         }
//                     }
//                     0x08 -> { // Complete
//                         Log.d(TAG, "Received Complete PDU")
//                         provisioningState = ProvisioningState.COMPLETE
//                         cancelProvisioningTimeout()
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningComplete", null)
//                         }
//                     }
//                     0x09 -> { // Failed
//                         Log.e(TAG, "Received Failed PDU with reason: ${pduData[1].toInt()}")
//                         provisioningState = ProvisioningState.FAILED
//                         cancelProvisioningTimeout()
//                         handler.post {
//                             methodChannel.invokeMethod("onProvisioningFailed", pduData[1].toInt())
//                         }
//                     }
//                     else -> {
//                         Log.w(TAG, "Unknown PDU type: ${pduData[0].toInt()}")
//                     }
//                 }
//             }
//         }

//         override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
//             if (status == BluetoothGatt.GATT_SUCCESS) {
//                 handler.post {
//                     methodChannel.invokeMethod("onCharacteristicRead", characteristic.value)
//                 }
//             } else {
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Characteristic read failed")
//                 }
//             }
//         }

//         override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
//             if (status == BluetoothGatt.GATT_SUCCESS) {
//                 handler.post {
//                     methodChannel.invokeMethod("onCharacteristicWrite", mapOf(
//                         "status" to "success",
//                         "characteristic" to characteristic.uuid.toString()
//                     ))
//                 }
//             } else {
//                 handler.post {
//                     methodChannel.invokeMethod("onError", "Characteristic write failed")
//                 }
//             }
//         }
//     }

//     private enum class ProvisioningState {
//         IDLE, INVITE, START, PUBLIC_KEY_EXCHANGE, CONFIRMATION, RANDOM, DATA, COMPLETE, FAILED
//     }
// }