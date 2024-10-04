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
        initializeMeshSDK()
        meshSdkManager2 = MeshSdkManager2()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "updateMeshUserNameAndPassword" -> {
                val username = call.argument<String>("username")
                val password = call.argument<String>("password")
                if (username != null && password != null) {
                    meshSdkManager2.updateMeshUserNameAndPassword(username, password)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Username and password are required", null)
                }
            }
            "registerConnectionEvent" -> {
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
            }
            "startProvisionMode" -> {
                meshSdkManager2.startProvisionMode()
                result.success(null)
            }
            "stopProvisionMode" -> {
                meshSdkManager2.stopProvisionMode()
                result.success(null)
            }
            "getFactoryMeshDevices" -> {
                meshSdkManager2.getFactoryMeshDevices { devices ->
                    result.success(devices.map { it.toMap() })
                }
            }
            "getProvisionedMeshDevices" -> {
                meshSdkManager2.getProvisionedMeshDevices { devices ->
                    result.success(devices.map { it.toMap() })
                }
            }
            "getMeshDevices" -> {
                meshSdkManager2.getMeshDevices { devices ->
                    result.success(devices.map { it.toMap() })
                }
            }
            "getFactoryMeshDevicesWithFilter" -> {
                val filter = call.argument<Map<String, Any>>("filter")
                val deviceFilter = createDeviceFilter(filter)
                meshSdkManager2.getFactoryMeshDevices(deviceFilter) { devices ->
                    result.success(devices.map { it.toMap() })
                }
            }
            "provisionDevice" -> {
                val macAddress = call.argument<String>("macAddress")
                val meshAddress = call.argument<Int>("meshAddress")
                val groupAddress = call.argument<Int>("groupAddress")
                if (macAddress != null && meshAddress != null && groupAddress != null) {
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
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments for provisionDevice", null)
                }
            }
            "unProvisionDevice" -> {
                val meshAddress = call.argument<Int>("meshAddress")
                if (meshAddress != null) {
                    meshSdkManager2.unProvisionDevice(meshAddress) { response ->
                        if (response.data != null) {
                            result.success(true)
                        } else {
                            result.error("UNPROVISIONED_FAILED", response.message?.toString(), null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Mesh address is required", null)
                }
            }
            "sendCommand" -> {
                val meshAddress = call.argument<Int>("meshAddress")
                val commandType = call.argument<String>("commandType")
                val commandParams = call.argument<Map<String, Any>>("commandParams")
                if (meshAddress != null && commandType != null) {
                    val command = createCommand(commandType, commandParams)
                    meshSdkManager2.sendCommand(meshAddress, listOf(command)) { response ->
                        if (response.data != null) {
                            result.success(true)
                        } else {
                            result.error("COMMAND_FAILED", response.message?.toString(), null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments for sendCommand", null)
                }
            }
            "connectAndSendCommand" -> {
                val macAddress = call.argument<String>("macAddress")
                val commands = call.argument<List<Map<String, Any>>>("commands")
                if (macAddress != null && commands != null) {
                    val commandsList = commands.map { createCommand(it["type"] as String, it["params"] as Map<String, Any>) }
                    meshSdkManager2.connectAndSendCommand(macAddress, commandsList) { response ->
                        if (response.data != null) {
                            result.success(true)
                        } else {
                            result.error("COMMAND_FAILED", response.message?.toString(), null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments for connectAndSendCommand", null)
                }
            }
            "getGateways" -> {
                meshSdkManager2.getGateways { gateways ->
                    result.success(gateways.map { it.toMap() })
                }
            }
            "getGatewaysWithFilter" -> {
                val filter = call.argument<Map<String, Any>>("filter")
                val deviceFilter = createDeviceFilter(filter)
                meshSdkManager2.getGateways(deviceFilter) { gateways ->
                    result.success(gateways.map { it.toMap() })
                }
            }
            "provisionGateway" -> {
                val macAddress = call.argument<String>("macAddress")
                if (macAddress != null) {
                    meshSdkManager2.provisionGateway(MeshDevice(macAddress)) { response ->
                        if (response.data != null) {
                            result.success(true)
                        } else {
                            result.error("PROVISION_GATEWAY_FAILED",
                                response.message?.toString(), null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Mac address is required", null)
                }
            }
            "unProvisionGateway" -> {
                val macAddress = call.argument<String>("macAddress")
                if (macAddress != null) {
                    meshSdkManager2.unProvisionGateway(macAddress) { response ->
                        if (response.data != null) {
                            result.success(true)
                        } else {
                            result.error("UNPROVISIONED_GATEWAY_FAILED",
                                response.message?.toString(), null)
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Mac address is required", null)
                }
            }
            else -> result.notImplemented()
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