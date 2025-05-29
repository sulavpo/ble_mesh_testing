package com.example.ble_testing

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*

class BleMeshGattServer(private val context: Context, private val channel: MethodChannel) {
    private val provisioningServiceUuid = UUID.fromString("00001827-0000-1000-8000-00805f9b34fb")
    private val provisioningDataInUuid = UUID.fromString("00002adb-0000-1000-8000-00805f9b34fb")
    private val provisioningDataOutUuid = UUID.fromString("00002adc-0000-1000-8000-00805f9b34fb")

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var isAdvertising = false
    private var dataOutCharacteristic: BluetoothGattCharacteristic? = null
    private var connectedDevice: BluetoothDevice? = null

    fun startAdvertising() {
        if (isAdvertising) {
            Log.d("BleMeshGattServer", "Already advertising, not starting again.")
            return
        }
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            channel.invokeMethod("onAdvertisingError", "BLE advertising not supported")
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
            .addServiceUuid(ParcelUuid(provisioningServiceUuid))
            .build()
        advertiser?.startAdvertising(settings, advertiseData, advertiseCallback)
        Log.d("BleMeshGattServer", "startAdvertising() called.")
        startGattServer(bluetoothManager)
    }

    fun stopAdvertising() {
        if (!isAdvertising) {
            Log.d("BleMeshGattServer", "Not advertising, nothing to stop.")
            return
        }
        advertiser?.stopAdvertising(advertiseCallback)
        isAdvertising = false
        gattServer?.close()
        Log.d("BleMeshGattServer", "stopAdvertising() called.")
    }

    fun getMeshInfo(): Map<String, Any> {
        // Example mesh info
        return mapOf(
            "uuid" to provisioningServiceUuid.toString(),
            "name" to "BLE Mesh Node",
            "capabilities" to mapOf(
                "numElements" to 1,
                "algorithms" to listOf("FIPS P-256 Elliptic Curve"),
                "publicKeyType" to "No OOB",
                "staticOobType" to "Not supported",
                "outputOobSize" to 0,
                "inputOobSize" to 0
            ),
            "elements" to listOf(
                mapOf(
                    "location" to "0x0000",
                    "models" to listOf("Generic OnOff Server", "Generic Level Server")
                )
            )
        )
    }

    private fun startGattServer(bluetoothManager: BluetoothManager) {
        gattServer = bluetoothManager.openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
                Log.d("BleMeshGattServer", "Connection state changed: $newState")
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedDevice = device
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    connectedDevice = null
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice?,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic?,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (characteristic?.uuid == provisioningDataInUuid && value != null && value.isNotEmpty()) {
                    Log.d("BleMeshGattServer", "Received PDU: ${value.joinToString { String.format("%02X", it) }}")
                    // Check for Invite PDU (0x00)
                    if (value[0].toInt() == 0x00) {
                        // Respond with Capabilities PDU (0x03)
                        val capabilities = byteArrayOf(
                            0x03, // Capabilities opcode
                            0x01, // Number of elements
                            0x00, 0x00, // Algorithms (FIPS P-256 Elliptic Curve)
                            0x00, // Public Key Type (No OOB)
                            0x00, // Static OOB Type (Not supported)
                            0x00, // Output OOB Size
                            0x00, // Output OOB Action
                            0x00, // Input OOB Size
                            0x00  // Input OOB Action
                        )
                        sendCapabilitiesPdu(capabilities)
                    }
                }
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            }
        })
        val provisioningService = BluetoothGattService(provisioningServiceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val dataIn = BluetoothGattCharacteristic(
            provisioningDataInUuid,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val dataOut = BluetoothGattCharacteristic(
            provisioningDataOutUuid,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            0
        )
        provisioningService.addCharacteristic(dataIn)
        provisioningService.addCharacteristic(dataOut)
        gattServer?.addService(provisioningService)
        dataOutCharacteristic = dataOut
    }

    private fun sendCapabilitiesPdu(pdu: ByteArray) {
        connectedDevice?.let { device ->
            dataOutCharacteristic?.let { charac ->
                charac.value = pdu
                gattServer?.notifyCharacteristicChanged(device, charac, false)
                Log.d("BleMeshGattServer", "Sent Capabilities PDU: ${pdu.joinToString { String.format("%02X", it) }}")
            }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
            Log.d("BleMeshGattServer", "Advertising started successfully")
            channel.invokeMethod("onAdvertisingStarted", null)
        }
        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            Log.e("BleMeshGattServer", "Advertising failed: $errorCode")
            channel.invokeMethod("onAdvertisingError", errorCode)
        }
    }
} 