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
            when {
                ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED -> {
                    startScan()
                }
                ActivityCompat.shouldShowRequestPermissionRationale(context as Activity, Manifest.permission.BLUETOOTH_SCAN) -> {
                    // Show an explanation to the user
                    pendingResult?.error("PERMISSION_DENIED", "Bluetooth scan permission is required for this feature", null)
                }
                else -> {
                    ActivityCompat.requestPermissions(
                        context as Activity,
                        arrayOf(Manifest.permission.BLUETOOTH_SCAN),
                        PERMISSION_REQUEST_CODE
                    )
                }
            }
        } else {
            startScan()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startScan()
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Bluetooth scan permission denied", null)
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
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val device = scanResult.device
                val isMesh = scanResult.scanRecord?.serviceUuids?.any { 
                    it.uuid.toString().startsWith("0000fe")
                } ?: false
                
                val deviceInfo = mapOf(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "isMesh" to isMesh
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
            pendingResult?.error("SCAN_ERROR", "Failed to start scan: '${e.message}'", null)
        } finally {
            pendingResult = null
        }
    }

    private fun stopScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter.bluetoothLeScanner
        scanner.stopScan(object : ScanCallback() {})
        result.success(null)
    }
}