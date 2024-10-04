package com.fantom.hypnotik

import androidx.lifecycle.Observer
import com.cosmicnode.cnmesh.domain.MeshDevice
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NativeMethodChannel {
    private const val CHANNEL_NAME = "hypnotic.fantom.com/cnmesh_flutter"
    private lateinit var methodChannel: MethodChannel

    fun configureChannel(flutterEngine: FlutterEngine, meshViewModel: MeshViewModel, activity: FlutterFragmentActivity) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        listenEventMesh(meshViewModel, activity)
        methodChannel.setMethodCallHandler {
                call, result ->
            if (call.method == "startSearch") {
                meshViewModel.startAutoProvisioning()
                result.success(meshViewModel.isProvisioning.value!!)
            } else if (call.method == "stopSearch") {
                meshViewModel.stopProvisioning()
                result.success(meshViewModel.isProvisioning.value!!)
            } else if (call.method == "getFactoryDevices") {
                meshViewModel.getFactoryMeshDevices()
                result.success(meshViewModel.isProvisioning.value!!)
            } else if (call.method == "getProvisionedDevices") {
                meshViewModel.getProvisionedDevices()
                result.success(meshViewModel.isProvisioning.value!!)
            } else if (call.method == "getGateways") {
                meshViewModel.getGateways()
                result.success(true)
            } else if (call.method == "getDimmers") {
                meshViewModel.getDimmers()
                result.success(true)
            } else if (call.method == "provisionDevice") {
                val arguments = call.arguments as HashMap<*, *>
                val macAddress:String = arguments["macAddress"] as String
                val groupAddress:Int = arguments["groupAddress"] as Int
                val meshAddress = meshViewModel.provisionDevice(macAddress, groupAddress)
                result.success(meshAddress)
            } else if (call.method == "provisionRemote") {
                val arguments = call.arguments as HashMap<*, *>
                val macAddress:String = arguments["macAddress"] as String
                val groupAddress:Int = arguments["groupAddress"] as Int
                val meshAddress = meshViewModel.provisionRemote(groupAddress)
                result.success(meshAddress)
            } else if (call.method == "provisionGateway") {
                val arguments = call.arguments as HashMap<*, *>
                val idGateway:String = arguments["id"] as String
                var gateway: MeshDevice? = null;
                for (device in meshViewModel.getaways.value!!) {
                    if (device.id == idGateway) {
                        gateway = device;
                        break;
                    }
                }
                val meshAddress = meshViewModel.provisionGateway(gateway!!)
                result.success(meshAddress)
            } else if (call.method == "addToGroup") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val groupAddress:Int = arguments["groupAddress"] as Int
                meshViewModel.addToGroup(meshAddress, groupAddress)
                result.success(true)
            } else if (call.method == "addToScene") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val sceneAddress:Int = arguments["sceneAddress"] as Int
                val brightness: Int = arguments["brightness"] as Int
                val red: Int = arguments["red"] as Int
                val green: Int = arguments["green"] as Int
                val blue: Int = arguments["blue"] as Int
                val cct: Int = arguments["cct"] as Int
                meshViewModel.addToScene(meshAddress, sceneAddress, brightness, red, green, blue, cct)
                result.success(true)
            } else if (call.method == "loadScene") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val sceneAddress:Int = arguments["sceneAddress"] as Int
                meshViewModel.loadScene(meshAddress, sceneAddress)
                result.success(true)
            } else if (call.method == "unProvisionRemote") {
                val macAddress:String = call.arguments as String
                meshViewModel.unProvisionRemote(macAddress)
                result.success(true)
            } else if (call.method == "unProvisionDevice") {
                val meshAddress:Int = call.arguments as Int
                meshViewModel.unProvisionDevice(meshAddress)
                result.success(true)
            } else if (call.method == "lightOn") {
                val meshAddress:Int = call.arguments as Int
                meshViewModel.on(meshAddress)
                result.success(true)
            } else if (call.method == "lightOff") {
                val meshAddress:Int = call.arguments as Int
                meshViewModel.off(meshAddress)
                result.success(true)
            } else if (call.method == "brightness") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val value: Int = arguments["value"] as Int
                meshViewModel.brightness(meshAddress, value)
                result.success(true)
            } else if (call.method == "cct") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val value: Int = arguments["value"] as Int
                meshViewModel.cct(meshAddress, value)
                result.success(true)
            } else if (call.method == "color") {
                val arguments = call.arguments as HashMap<*, *>
                val meshAddress:Int = arguments["meshAddress"] as Int
                val red: Int = arguments["red"] as Int
                val green: Int = arguments["green"] as Int
                val blue: Int = arguments["blue"] as Int
                meshViewModel.color(meshAddress, red, green, blue)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    fun finishProvision() {
        methodChannel.invokeMethod("finishProvision", true)
    }

    fun finishProvisionRemote(meshAddress: Int) {
        methodChannel.invokeMethod("finishProvisionRemote", meshAddress)
    }

    fun finishProvisionGateway() {
        methodChannel.invokeMethod("finishProvisionGateway", true)
    }

    fun finishAddGroup() {
        methodChannel.invokeMethod("finishAddGroup", true)
    }

    fun finishAddScene() {
        methodChannel.invokeMethod("finishAddScene", true)
    }

    fun finishLoadScene() {
        methodChannel.invokeMethod("finishLoadScene", true)
    }

    fun finishUnprovision() {
        methodChannel.invokeMethod("finishUnprovision", true)
    }

    fun finishUnprovisionGateway() {
        methodChannel.invokeMethod("finishUnprovisionGateway", true)
    }

    private fun listenEventMesh(meshViewModel: MeshViewModel, activity: FlutterFragmentActivity) {
        meshViewModel.isProvisioning.observe(activity, Observer {
            methodChannel.invokeMethod("isProvisioning", it)
        })
        meshViewModel.isConnecting.observe(activity, Observer {
            methodChannel.invokeMethod("isConnecting", it)
        })
        meshViewModel.isResetting.observe(activity, Observer {
            methodChannel.invokeMethod("isResetting", it)
        })
        meshViewModel.isManualProvisioning.observe(activity, Observer {
            methodChannel.invokeMethod("isManualProvisioning", it)
        })
        meshViewModel.isLoading.observe(activity, Observer {
            methodChannel.invokeMethod("isLoading", it)
        })
        meshViewModel.meshManualProvisioningDevices.observe(activity, Observer {
            val listDevices = mutableListOf<HashMap<String,Any?>>()
            for (device in it) {
                listDevices.add(convertMeshDeviceToMap(device))
            }
            methodChannel.invokeMethod("meshManualProvisioningDevices", listDevices)
        })
        meshViewModel.provisionCount.observe(activity, Observer {
            methodChannel.invokeMethod("provisionCount", it)
        })
        meshViewModel.meshDevices.observe(activity, Observer {
            val listDevices = mutableListOf<HashMap<String,Any?>>()
            for (device in it) {
                listDevices.add(convertMeshDeviceToMap(device))
            }
            methodChannel.invokeMethod("meshDevices", listDevices)
        })
        meshViewModel.dimmers.observe(activity, Observer {
            val listDevices = mutableListOf<HashMap<String,Any?>>()
            for (device in it) {
                listDevices.add(convertMeshDeviceToMap(device))
            }
            methodChannel.invokeMethod("dimmers", listDevices)
        })
        meshViewModel.getaways.observe(activity, Observer {
            val listDevices = mutableListOf<HashMap<String,Any?>>()
            for (device in it) {
                listDevices.add(convertMeshDeviceToMap(device))
            }
            methodChannel.invokeMethod("gateways", listDevices)
        })
        meshViewModel.meshProvisionedDevices.observe(activity, Observer {
            val listDevices = mutableListOf<HashMap<String,Any?>>()
            for (device in it) {
                listDevices.add(convertMeshDeviceToMap(device))
            }
            methodChannel.invokeMethod("meshProvisionedDevices", listDevices)
        })
        meshViewModel.meshState.observe(activity, Observer {
            methodChannel.invokeMethod("meshState", it.toString())
        })
        meshViewModel.meshConnectedDevice.observe(activity, Observer {
            methodChannel.invokeMethod("meshConnectedDevice", if (it != null) convertMeshDeviceToMap(it) else null)
        })
        meshViewModel.otaInProgress.observe(activity, Observer {
            methodChannel.invokeMethod("otaInProgress", it)
        })
        meshViewModel.otaStatusString.observe(activity, Observer {
            methodChannel.invokeMethod("otaStatusString", it)
        })
        meshViewModel.otaFileSentProgress.observe(activity, Observer {
            methodChannel.invokeMethod("otaFileSentProgress", it)
        })
        meshViewModel.otaMeshProgress.observe(activity, Observer {
            methodChannel.invokeMethod("otaMeshProgress", it)
        })
    }

    private fun convertMeshDeviceToMap(meshDevice: MeshDevice) : HashMap<String,Any?> {
        val hashMap = HashMap<String,Any?>(15)
        hashMap["id"] = meshDevice.id
        hashMap["name"] = meshDevice.name
        hashMap["brightness"] = meshDevice.brightness
        hashMap["chipType"] = meshDevice.chipType
        hashMap["companyIdentifier"] = meshDevice.companyIdentifier
        hashMap["firmwareVersion"] = meshDevice.firmwareVersion
        hashMap["macAddress"] = meshDevice.macAddress
        hashMap["meshAddress"] = meshDevice.meshAddress
        hashMap["productId"] = meshDevice.productId
        hashMap["relayCounter"] = meshDevice.relayCounter
        hashMap["reserve"] = meshDevice.reserve
        hashMap["rssi"] = meshDevice.rssi
        hashMap["status"] = meshDevice.status
        hashMap["vendorData"] = meshDevice.vendorData
        hashMap["vendorId"] = meshDevice.vendorId
        return hashMap
    }
}