package com.example.ble_testing

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity

class BleScanner(private val context: Context, flutterEngine: FlutterEngine) {
    private val CHANNEL = "com.example.ble_scanner/ble"
    private val bluetoothAdapter: BluetoothAdapter
    private val methodChannel: MethodChannel

    private val PERMISSION_REQUEST_CODE = 1
    private var pendingResult: MethodChannel.Result? = null
    private var scanCallback: ScanCallback? = null


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


    private fun stopScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter.bluetoothLeScanner
        // Use the same scanCallback that was created in startScan
        scanCallback?.let { scanner.stopScan(it) }
        result.success(null)
    }

    

}
