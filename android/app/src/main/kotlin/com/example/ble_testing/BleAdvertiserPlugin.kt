package com.example.ble_testing

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

class BleAdvertiserPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var bluetoothAdapter: BluetoothAdapter
    private var advertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.ble_testing/ble_advertiser")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startAdvertising" -> startAdvertising(result)
            "stopAdvertising" -> stopAdvertising(result)
            else -> result.notImplemented()
        }
    }

    private fun startAdvertising(result: Result) {
        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }

        advertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            result.error("ADVERTISING_NOT_SUPPORTED", "BLE advertising is not supported", null)
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
        result.success(null)
    }

    private fun stopAdvertising(result: Result) {
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
            channel.invokeMethod("onAdvertisingStarted", null)
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
            channel.invokeMethod("onAdvertisingError", errorMessage)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 