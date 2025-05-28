package com.example.ble_testing

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity: FlutterActivity() {
    private lateinit var bleScanner: BleScanner
    private val PERMISSION_REQUEST_CODE = 2
    private val ENABLE_BLUETOOTH_REQUEST_CODE = 3

    // BLE advertising
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false
    private val CHANNEL = "com.example.ble_testing/ble_advertiser"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkAndRequestPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bleScanner = BleScanner(this, flutterEngine)

        // BLE advertiser setup
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    startBleAdvertising(result)
                }
                "stopAdvertising" -> {
                    stopBleAdvertising(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startBleAdvertising(result: MethodChannel.Result) {
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }
        if (advertiser == null) {
            result.error("ADVERTISING_NOT_SUPPORTED", "BLE advertising is not supported", null)
            return
        }
        if (isAdvertising) {
            result.success(null)
            return
        }
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()
        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ParcelUuid(UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")))
            .build()
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()
        advertiser?.startAdvertising(settings, advertiseData, scanResponse, advertiseCallback)
        isAdvertising = true
        result.success(null)
    }

    private fun stopBleAdvertising(result: MethodChannel.Result) {
        if (isAdvertising) {
            advertiser?.stopAdvertising(advertiseCallback)
            isAdvertising = false
        }
        result.success(null)
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
            Log.d("BLE_ADVERTISER", "Advertising started successfully")
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
                .invokeMethod("onAdvertisingStarted", null)
        }
        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            val errorMessage = when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> "Advertising already started"
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "Advertising data too large"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                else -> "Unknown error: $errorCode"
            }
            Log.e("BLE_ADVERTISER", "Failed to start advertising: $errorMessage")
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
                .invokeMethod("onAdvertisingError", errorMessage)
        }
    }

    private fun checkAndRequestPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        val notGrantedPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (notGrantedPermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, notGrantedPermissions.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else {
            checkBluetoothEnabled()
        }
    }

    private fun checkBluetoothEnabled() {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.BLUETOOTH_CONNECT
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            startActivityForResult(enableBtIntent, ENABLE_BLUETOOTH_REQUEST_CODE)
        } else {
            Log.d("MainActivity", "Bluetooth is enabled")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    checkBluetoothEnabled()
                } else {
                    Log.e("MainActivity", "Some permissions were denied")
                }
            }
            else -> bleScanner.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            ENABLE_BLUETOOTH_REQUEST_CODE -> {
                if (resultCode == RESULT_OK) {
                    Log.d("MainActivity", "Bluetooth has been enabled")
                } else {
                    Log.e("MainActivity", "Bluetooth enable request was denied")
                }
            }
        }
    }
}