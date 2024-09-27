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
                "readCharacteristic" -> {
                    val serviceUuid = call.argument<String>("serviceUuid")
                    val characteristicUuid = call.argument<String>("characteristicUuid")
                    if (serviceUuid != null && characteristicUuid != null) {
                        readCharacteristic(serviceUuid, characteristicUuid, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Service UUID and Characteristic UUID are required", null)
                    }
                }
                "writeCharacteristic" -> {
                    val serviceUuid = call.argument<String>("serviceUuid")
                    val characteristicUuid = call.argument<String>("characteristicUuid")
                    val value = call.argument<ByteArray>("value")
                    if (serviceUuid != null && characteristicUuid != null && value != null) {
                        writeCharacteristic(serviceUuid, characteristicUuid, value, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Service UUID, Characteristic UUID, and value are required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // For Android 12+ (API level 31 and above)
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
            // For Android versions below 12 (API level 31)
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
            // Log error in case the scanner is null
            methodChannel.invokeMethod("onError", "Bluetooth LE Scanner is null, make sure Bluetooth is enabled")
            return
        }

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        // Initialize scanCallback here
        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val device = scanResult.device

                // Add a debug log to verify that the callback is working
                android.util.Log.d("BLE_SCAN", "Device found: ${device.address}")

                // Check if any device is found
                if (device == null) {
                    android.util.Log.d("BLE_SCAN", "Device is null")
                    return
                }

                // Initialize ProvisioningServiceUUID variable
                var provisioningServiceUuid: String? = null

                // Check for specific mesh service UUIDs (1827 and 1828)
                val isMesh = scanResult.scanRecord?.serviceUuids?.any {
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

                // Create a map of device info to be sent to Flutter
                val deviceInfo = mapOf(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "isMesh" to isMesh,  // Identifies if it's a mesh device based on the UUID check
                    "provisioningServiceUuid" to (provisioningServiceUuid ?: "None")  // Add the provisioning service UUID to the map
                )

                // Send device information to Flutter through method channel
                methodChannel.invokeMethod("onDeviceFound", deviceInfo)
                android.util.Log.d("BLE_SCAN", "Device info sent to Flutter: $deviceInfo")
            }


            override fun onScanFailed(errorCode: Int) {
                android.util.Log.d("BLE_SCAN", "Scan failed with error code: $errorCode")
                methodChannel.invokeMethod("onError", "Scan failed with error code: $errorCode")
            }
        }

        try {
            // Log to verify that scan is starting
            android.util.Log.d("BLE_SCAN", "Starting scan")
            scanner.startScan(null, scanSettings, scanCallback)
            pendingResult?.success(null)
        } catch (e: Exception) {
            android.util.Log.d("BLE_SCAN", "Failed to start scan: ${e.message}")
            pendingResult?.error("SCAN_ERROR", "Failed to start scan: '${e.message}'", null)
        } finally {
            pendingResult = null
        }
    }


    @SuppressLint("MissingPermission")
    private fun stopScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter.bluetoothLeScanner
        // Use the same scanCallback that was created in startScan
        scanCallback?.let { scanner.stopScan(it) }
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

        disconnect(null) // Disconnect from any existing connection

        gatt = device.connectGatt(context, false, gattCallback)
        result.success(null) // Indicate that connection process has started
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
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    android.util.Log.i("BleScanner", "Disconnected from GATT server.")
                    handler.post {
                        methodChannel.invokeMethod("onConnectionStateChange", "disconnected")
                    }
                    gatt.close()
                    this@BleScanner.gatt = null
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                android.util.Log.i("BleScanner", "Services discovered.")
                val services = gatt.services.map { service ->
                    mapOf(
                        "uuid" to service.uuid.toString(),
                        "characteristics" to service.characteristics.map { characteristic ->
                            mapOf(
                                "uuid" to characteristic.uuid.toString(),
                                "properties" to characteristic.properties
                            )
                        }
                    )
                }
                handler.post {
                    methodChannel.invokeMethod("onServicesDiscovered", services)
                }
            } else {
                android.util.Log.w("BleScanner", "onServicesDiscovered received: $status")
                handler.post {
                    methodChannel.invokeMethod("onError", "Failed to discover services")
                }
            }
        }
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val value = characteristic.value
                handler.post {
                    methodChannel.invokeMethod("onCharacteristicRead", mapOf(
                        "serviceUuid" to characteristic.service.uuid.toString(),
                        "characteristicUuid" to characteristic.uuid.toString(),
                        "value" to value
                    ))
                }
            } else {
                handler.post {
                    methodChannel.invokeMethod("onError", "Failed to read characteristic")
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handler.post {
                    methodChannel.invokeMethod("onCharacteristicWrite", mapOf(
                        "serviceUuid" to characteristic.service.uuid.toString(),
                        "characteristicUuid" to characteristic.uuid.toString()
                    ))
                }
            } else {
                handler.post {
                    methodChannel.invokeMethod("onError", "Failed to write characteristic")
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun readCharacteristic(serviceUuid: String, characteristicUuid: String, result: MethodChannel.Result) {
        val gatt = this.gatt
        if (gatt == null) {
            result.error("NOT_CONNECTED", "Not connected to a device", null)
            return
        }

        val service = gatt.getService(UUID.fromString(serviceUuid))
        if (service == null) {
            result.error("SERVICE_NOT_FOUND", "Service not found", null)
            return
        }

        val characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid))
        if (characteristic == null) {
            result.error("CHARACTERISTIC_NOT_FOUND", "Characteristic not found", null)
            return
        }

        if (!gatt.readCharacteristic(characteristic)) {
            result.error("READ_FAILED", "Failed to initiate read characteristic", null)
        } else {
            result.success(null) // Indicate that read process has started
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeCharacteristic(serviceUuid: String, characteristicUuid: String, value: ByteArray, result: MethodChannel.Result) {
        val gatt = this.gatt
        if (gatt == null) {
            result.error("NOT_CONNECTED", "Not connected to a device", null)
            return
        }

        val service = gatt.getService(UUID.fromString(serviceUuid))
        if (service == null) {
            result.error("SERVICE_NOT_FOUND", "Service not found", null)
            return
        }

        val characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid))
        if (characteristic == null) {
            result.error("CHARACTERISTIC_NOT_FOUND", "Characteristic not found", null)
            return
        }

        characteristic.value = value
        if (!gatt.writeCharacteristic(characteristic)) {
            result.error("WRITE_FAILED", "Failed to initiate write characteristic", null)
        } else {
            result.success(null) // Indicate that write process has started
        }
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(result: MethodChannel.Result?) {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        result?.success(null)
    }



}
