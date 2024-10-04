import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.cosmicnode.cnmesh.MeshSdkManager2
import com.cosmicnode.cnmesh.datastore.mesh.manager.MeshState
import com.cosmicnode.cnmesh.domain.Commands
import com.cosmicnode.cnmesh.domain.DeviceFilter
import com.cosmicnode.cnmesh.domain.MeshDevice
import com.cosmicnode.cnmesh.initializeMeshSDK
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MeshSdkManager(private val context: Context) : MethodCallHandler {
    private var meshSdkManager2: MeshSdkManager2
    private val handler = Handler(Looper.getMainLooper())

    init {
        try {
            initializeMeshSDK()
            meshSdkManager2 = MeshSdkManager2()
        } catch (e: Exception) {
            showToast("Failed to initialize MeshSDK: ${e.message}")
            throw RuntimeException("MeshSDK initialization failed", e)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "updateMeshUserNameAndPassword" -> handleUpdateMeshUserNameAndPassword(call, result)
                "registerConnectionEvent" -> handleRegisterConnectionEvent(result)
                "startProvisionMode" -> handleStartProvisionMode(result)
                "stopProvisionMode" -> handleStopProvisionMode(result)
                "getFactoryMeshDevices" -> handleGetFactoryMeshDevices(result)
                "getProvisionedMeshDevices" -> handleGetProvisionedMeshDevices(result)
                "getMeshDevices" -> handleGetMeshDevices(result)
                "getFactoryMeshDevicesWithFilter" -> handleGetFactoryMeshDevicesWithFilter(call, result)
                "provisionDevice" -> handleProvisionDevice(call, result)
                "unProvisionDevice" -> handleUnProvisionDevice(call, result)
                "sendCommand" -> handleSendCommand(call, result)
                "connectAndSendCommand" -> handleConnectAndSendCommand(call, result)
                "getGateways" -> handleGetGateways(result)
                "getGatewaysWithFilter" -> handleGetGatewaysWithFilter(call, result)
                "provisionGateway" -> handleProvisionGateway(call, result)
                "unProvisionGateway" -> handleUnProvisionGateway(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("UNEXPECTED_ERROR", "An unexpected error occurred: ${e.message}", e.stackTraceToString())
        }
    }

    private fun handleUpdateMeshUserNameAndPassword(call: MethodCall, result: Result) {
        val username = call.argument<String>("username")
        val password = call.argument<String>("password")
        if (username != null && password != null) {
            try {
                meshSdkManager2.updateMeshUserNameAndPassword(username, password)
                result.success(null)
            } catch (e: Exception) {
                result.error("UPDATE_CREDENTIALS_FAILED", "Failed to update mesh credentials: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Username and password are required", null)
        }
    }

    private fun handleRegisterConnectionEvent(result: Result) {
        try {
            meshSdkManager2.registerConnectionEvent { meshState ->
                handler.post {
                    when (meshState) {
                        MeshState.Connected -> showToast("Mesh Connected")
                        MeshState.Connecting -> showToast("Mesh Connecting")
                        MeshState.Disconnected -> showToast("Mesh Disconnected")
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("REGISTER_EVENT_FAILED", "Failed to register connection event: ${e.message}", null)
        }
    }

    private fun handleStartProvisionMode(result: Result) {
        try {
            meshSdkManager2.startProvisionMode()
            result.success(null)
        } catch (e: Exception) {
            result.error("START_PROVISION_FAILED", "Failed to start provision mode: ${e.message}", null)
        }
    }

    private fun handleStopProvisionMode(result: Result) {
        try {
            meshSdkManager2.stopProvisionMode()
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_PROVISION_FAILED", "Failed to stop provision mode: ${e.message}", null)
        }
    }

    private fun handleGetFactoryMeshDevices(result: Result) {
        try {
            meshSdkManager2.getFactoryMeshDevices { devices ->
                result.success(devices.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_FACTORY_DEVICES_FAILED", "Failed to get factory mesh devices: ${e.message}", null)
        }
    }

    private fun handleGetProvisionedMeshDevices(result: Result) {
        try {
            meshSdkManager2.getProvisionedMeshDevices { devices ->
                result.success(devices.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_PROVISIONED_DEVICES_FAILED", "Failed to get provisioned mesh devices: ${e.message}", null)
        }
    }

    private fun handleGetMeshDevices(result: Result) {
        try {
            meshSdkManager2.getMeshDevices { devices ->
                result.success(devices.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_MESH_DEVICES_FAILED", "Failed to get mesh devices: ${e.message}", null)
        }
    }

    private fun handleGetFactoryMeshDevicesWithFilter(call: MethodCall, result: Result) {
        try {
            val filter = call.argument<Map<String, Any>>("filter")
            val deviceFilter = createDeviceFilter(filter)
            meshSdkManager2.getFactoryMeshDevices(deviceFilter) { devices ->
                result.success(devices.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_FACTORY_DEVICES_FILTERED_FAILED", "Failed to get factory mesh devices with filter: ${e.message}", null)
        }
    }

    private fun handleProvisionDevice(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")
        val meshAddress = call.argument<Int>("meshAddress")
        val groupAddress = call.argument<Int>("groupAddress")
        if (macAddress != null && meshAddress != null && groupAddress != null) {
            try {
                meshSdkManager2.provisionDevice(
                    MeshDevice(macAddress),
                    meshAddress,
                    listOf(Commands.AddToGroup(groupAddress))
                ) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("PROVISION_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("PROVISION_DEVICE_ERROR", "An error occurred while provisioning the device: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Invalid arguments for provisionDevice", null)
        }
    }

    private fun handleUnProvisionDevice(call: MethodCall, result: Result) {
        val meshAddress = call.argument<Int>("meshAddress")
        if (meshAddress != null) {
            try {
                meshSdkManager2.unProvisionDevice(meshAddress) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("UNPROVISIONED_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("UNPROVISION_DEVICE_ERROR", "An error occurred while unprovisioning the device: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Mesh address is required", null)
        }
    }

    private fun handleSendCommand(call: MethodCall, result: Result) {
        val meshAddress = call.argument<Int>("meshAddress")
        val commandType = call.argument<String>("commandType")
        val commandParams = call.argument<Map<String, Any>>("commandParams")
        if (meshAddress != null && commandType != null) {
            try {
                val command = createCommand(commandType, commandParams)
                meshSdkManager2.sendCommand(meshAddress, listOf(command)) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("COMMAND_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("SEND_COMMAND_ERROR", "An error occurred while sending the command: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Invalid arguments for sendCommand", null)
        }
    }

    private fun handleConnectAndSendCommand(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")
        val commands = call.argument<List<Map<String, Any>>>("commands")
        if (macAddress != null && commands != null) {
            try {
                val commandsList = commands.map { createCommand(it["type"] as String, it["params"] as Map<String, Any>) }
                meshSdkManager2.connectAndSendCommand(macAddress, commandsList) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("COMMAND_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("CONNECT_AND_SEND_COMMAND_ERROR", "An error occurred while connecting and sending commands: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Invalid arguments for connectAndSendCommand", null)
        }
    }

    private fun handleGetGateways(result: Result) {
        try {
            meshSdkManager2.getGateways { gateways ->
                result.success(gateways.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_GATEWAYS_FAILED", "Failed to get gateways: ${e.message}", null)
        }
    }

    private fun handleGetGatewaysWithFilter(call: MethodCall, result: Result) {
        try {
            val filter = call.argument<Map<String, Any>>("filter")
            val deviceFilter = createDeviceFilter(filter)
            meshSdkManager2.getGateways(deviceFilter) { gateways ->
                result.success(gateways.map { it.toMap() })
            }
        } catch (e: Exception) {
            result.error("GET_GATEWAYS_FILTERED_FAILED", "Failed to get gateways with filter: ${e.message}", null)
        }
    }

    private fun handleProvisionGateway(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")
        if (macAddress != null) {
            try {
                meshSdkManager2.provisionGateway(MeshDevice(macAddress)) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("PROVISION_GATEWAY_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("PROVISION_GATEWAY_ERROR", "An error occurred while provisioning the gateway: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Mac address is required", null)
        }
    }

    private fun handleUnProvisionGateway(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")
        if (macAddress != null) {
            try {
                meshSdkManager2.unProvisionGateway(macAddress) { response ->
                    if (response.data != null) {
                        result.success(true)
                    } else {
                        result.error("UNPROVISIONED_GATEWAY_FAILED", response.message?.toString(), null)
                    }
                }
            } catch (e: Exception) {
                result.error("UNPROVISION_GATEWAY_ERROR", "An error occurred while unprovisioning the gateway: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Mac address is required", null)
        }
    }

    private fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    private fun MeshDevice.toMap(): Map<String, String?> {
        return mapOf(
            "macAddress" to macAddress,
            // Add other properties as needed
        )
    }

    private fun createDeviceFilter(filter: Map<String, Any>?): DeviceFilter {
        return DeviceFilter(
            productId = (filter?.get("productId") as? List<*>)?.mapNotNull { it as? Int },
            macAddress = filter?.get("macAddress") as? String,
            rssi = filter?.get("rssi") as? Int
        )
    }

    private fun createCommand(type: String, params: Map<String, Any>?): Commands {
        return when (type) {
            "Blink" -> Commands.Blink(params?.get("delay") as? Long ?: 0L)
            "On" -> Commands.On(params?.get("delay") as? Long ?: 0L)
            "Off" -> Commands.Off(params?.get("delay") as? Long ?: 0L)
            "Brightness" -> Commands.Brightness(params?.get("brightness") as? Int ?: 0, params?.get("delay") as? Long ?: 0L)
            // Add other command types as needed
            else -> throw IllegalArgumentException("Unknown command type: $type")
        }
    }
}