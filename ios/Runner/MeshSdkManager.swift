import Flutter
import UIKit
import cnmesh

public class MeshSdkManager: NSObject, FlutterPlugin {
    private var meshSdkManager2: MeshSdkManager2!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.example.ble_scanner/ble", binaryMessenger: registrar.messenger())
        let instance = MeshSdkManager()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    override init() {
        super.init()
        CNMeshSDKKt.initializeMeshSDK()
        meshSdkManager2 = MeshSdkManager2()
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateMeshUserNameAndPassword":
            if let args = call.arguments as? [String: Any],
               let username = args["username"] as? String,
               let password = args["password"] as? String {
                meshSdkManager2.updateMeshUserNameAndPassword(username: username, password: password)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Username and password are required", details: nil))
            }
        case "registerConnectionEvent":
            meshSdkManager2.registerConnectionEvent { meshState in
                DispatchQueue.main.async {
                    switch meshState {
                    case MeshState.Connected():
                        self.showToast(message: "Mesh Connected")
                    case MeshState.Connecting():
                        self.showToast(message: "Mesh Connecting")
                    case MeshState.Disconnected():
                        self.showToast(message: "Mesh Disconnected")
                    default:
                        break
                    }
                }
            }
            result(nil)
        case "startProvisionMode":
            meshSdkManager2.startProvisionMode()
            result(nil)
        case "stopProvisionMode":
            meshSdkManager2.stopProvisionMode()
            result(nil)
        case "getFactoryMeshDevices":
            meshSdkManager2.getFactoryMeshDevices { devices in
                result(devices.map { $0.toDict() })
            }
        case "getProvisionedMeshDevices":
            meshSdkManager2.getProvisionedMeshDevices { devices in
                result(devices.map { $0.toDict() })
            }
        case "getMeshDevices":
            meshSdkManager2.getMeshDevices { devices in
                result(devices.map { $0.toDict() })
            }
        case "getFactoryMeshDevicesWithFilter":
            if let args = call.arguments as? [String: Any],
               let filter = args["filter"] as? [String: Any] {
                let deviceFilter = self.createDeviceFilter(filter)
                meshSdkManager2.getFactoryMeshDevices(deviceFilter: deviceFilter) { devices in
                    result(devices.map { $0.toDict() })
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid filter", details: nil))
            }
        case "provisionDevice":
            if let args = call.arguments as? [String: Any],
               let macAddress = args["macAddress"] as? String,
               let meshAddress = args["meshAddress"] as? Int32,
               let groupAddress = args["groupAddress"] as? Int32 {
                meshSdkManager2.provisionDevice(
                    macAddress: macAddress,
                    meshAddress: meshAddress,
                    provisionCommands: [
                        Commands.AddToGroup(groupAddress: groupAddress, commandDelay: 0)
                    ]
                ) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "PROVISION_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for provisionDevice", details: nil))
            }
        case "unProvisionDevice":
            if let args = call.arguments as? [String: Any],
               let meshAddress = args["meshAddress"] as? Int32 {
                meshSdkManager2.unProvisionDevice(meshAddress: meshAddress) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "UNPROVISION_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Mesh address is required", details: nil))
            }
        case "sendCommand":
            if let args = call.arguments as? [String: Any],
               let meshAddress = args["meshAddress"] as? Int32,
               let commandType = args["commandType"] as? String,
               let commandParams = args["commandParams"] as? [String: Any] {
                let command = self.createCommand(type: commandType, params: commandParams)
                meshSdkManager2.sendCommand(
                    meshAddress: meshAddress,
                    commands: [command]
                ) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "COMMAND_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for sendCommand", details: nil))
            }
        case "connectAndSendCommand":
            if let args = call.arguments as? [String: Any],
               let macAddress = args["macAddress"] as? String,
               let commands = args["commands"] as? [[String: Any]] {
                let commandsList = commands.map { self.createCommand(type: $0["type"] as! String, params: $0["params"] as! [String: Any]) }
                meshSdkManager2.connectAndSendCommand(
                    macAddress: macAddress,
                    commands: commandsList
                ) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "COMMAND_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for connectAndSendCommand", details: nil))
            }
        case "getGateways":
            meshSdkManager2.getGateways { gateways in
                result(gateways.map { $0.toDict() })
            }
        case "getGatewaysWithFilter":
            if let args = call.arguments as? [String: Any],
               let filter = args["filter"] as? [String: Any] {
                let deviceFilter = self.createDeviceFilter(filter)
                meshSdkManager2.getGateways(deviceFilter: deviceFilter) { gateways in
                    result(gateways.map { $0.toDict() })
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid filter", details: nil))
            }
        case "provisionGateway":
            if let args = call.arguments as? [String: Any],
               let macAddress = args["macAddress"] as? String {
                meshSdkManager2.provisionGateway(meshDevice: MeshDevice(macAddress: macAddress)) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "PROVISION_GATEWAY_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Mac address is required", details: nil))
            }
        case "unProvisionGateway":
            if let args = call.arguments as? [String: Any],
               let macAddress = args["macAddress"] as? String {
                meshSdkManager2.unProvisionGateway(macAddress: macAddress) { response in
                    if response.data != nil {
                        result(true)
                    } else {
                        result(FlutterError(code: "UNPROVISION_GATEWAY_FAILED", message: response.message, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Mac address is required", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func showToast(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.view.backgroundColor = .black
            alert.view.alpha = 0.5
            alert.view.layer.cornerRadius = 15
            
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.rootViewController?.present(alert, animated: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    private func createDeviceFilter(_ filter: [String: Any]) -> DeviceFilter {
        return DeviceFilter(
            productId: filter["productId"] as? String,
            macAddress: filter["macAddress"] as? String,
            rssi: filter["rssi"] as? Int32
        )
    }
    
    private func createCommand(type: String, params: [String: Any]) -> Commands {
        switch type {
        case "Blink":
            return Commands.Blink(commandDelay: Int64(params["delay"] as? Int ?? 0))
        case "On":
            return Commands.On(commandDelay: Int64(params["delay"] as? Int ?? 0))
        case "Off":
            return Commands.Off(commandDelay: Int64(params["delay"] as? Int ?? 0))
        case "Brightness":
            return Commands.Brightness(brightness: Int32(params["brightness"] as? Int ?? 0), commandDelay: Int64(params["delay"] as? Int ?? 0))
        // Add other command types as needed
        default:
            fatalError("Unknown command type: \(type)")
        }
    }
}

extension MeshDevice {
    func toDict() -> [String: Any] {
        return [
            "macAddress": macAddress,
            // Add other properties as needed
        ]
    }
}