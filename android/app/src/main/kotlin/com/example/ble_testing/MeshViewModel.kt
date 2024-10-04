package com.fantom.hypnotik

import android.util.Log
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.cosmicnode.cnmesh.MeshSdkManager2
import com.cosmicnode.cnmesh.datastore.mesh.manager.MeshState
import com.cosmicnode.cnmesh.domain.Commands
import com.cosmicnode.cnmesh.domain.MeshDevice
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.random.Random

class MeshViewModel : ViewModel() {
    var isProvisioning = MutableLiveData(false)
    var isConnecting = MutableLiveData("")
    var isResetting = MutableLiveData(false)
    var isManualProvisioning = MutableLiveData(false)
    var isLoading = MutableLiveData(false)
    var meshManualProvisioningDevices = MutableLiveData<List<MeshDevice>>(emptyList())
    var provisionCount = MutableLiveData(0)
    var meshDevices = MutableLiveData<List<MeshDevice>>(emptyList())
    var getaways = MutableLiveData<List<MeshDevice>>(emptyList())
    var dimmers = MutableLiveData<List<MeshDevice>>(emptyList())
    var meshProvisionedDevices = MutableLiveData<List<MeshDevice>>(emptyList())
    var meshState = MutableLiveData<MeshState>(MeshState.Disconnected)
    var meshConnectedDevice = MutableLiveData<MeshDevice?>(null)
    var otaInProgress = MutableLiveData(false)
    var otaStatusString = MutableLiveData("")
    var otaFileSentProgress = MutableLiveData(0)
    var otaMeshProgress = MutableLiveData(0)
    private var nextAddress = MutableLiveData(0)

    private fun getNextDeviceAddress(): Int {
        return Random.nextInt(1, 30001)
    }

    val meshSdkManager: MeshSdkManager2 = MeshSdkManager2()

    init {
        meshSdkManager.registerConnectionEvent {
            when (it) {
                is MeshState.Connecting -> {
                    isConnecting.postValue("Connecting")
                }
                is MeshState.Connected -> {
                    isConnecting.postValue("Connected")
                }
                is MeshState.Disconnected -> {
                    isConnecting.postValue("Disconnected")
                }
            }
        }
        meshSdkManager.registerLoggerEvent { log ->
            Log.i("CNMESHSDK", log)
        }

        meshSdkManager.updateMeshUserNameAndPassword("Test", "1234")
    }

    fun startAutoProvisioning() {
        meshSdkManager.startProvisionMode()
        isProvisioning.postValue(true)
    }

    fun stopProvisioning() {
        meshSdkManager.stopProvisionMode()
        isProvisioning.postValue(false)
    }

    fun getFactoryMeshDevices() {
        meshSdkManager.getFactoryMeshDevices {
            meshDevices.postValue(it)
        }
    }

    fun getDimmers() {
        meshSdkManager.getFactoryMeshDevices { devices ->
            val filterDimmers = devices.filter { it.productId == 32 }
            dimmers.postValue(filterDimmers)
        }
    }

    fun getProvisionedDevices() {
        meshSdkManager.getProvisionedMeshDevices {
            meshProvisionedDevices.postValue(it)
        }
    }

    fun getGateways() {
        meshSdkManager.getGateways {
            println(it.toString())
            getaways.postValue(it)
        }
    }

    // groupAddress 32769
    fun provisionRemote(groupAddress: Int): Int {
        val meshDevice = dimmers.value!!.first()
        val meshAddress = getNextDeviceAddress() // 18303
        val param0 = groupAddress and 0xFF // 1
        val param1 = groupAddress shr 8 and 0xFF // 128
        meshSdkManager.provisionDevice(meshDevice, meshAddress, listOf(
            Commands.Custom(opcode = 236, params = listOf(
                param0,
                param1)))) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishProvisionRemote(meshAddress)   // your code goes here
            }
        }
        return meshAddress
    }

    fun provisionDevice(macAddress: String, groupAddress: Int): Int {
        val meshAddress = getNextDeviceAddress()
        meshSdkManager.provisionDevice(macAddress, meshAddress, listOf(Commands.AddToGroup(groupAddress))) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishProvision()   // your code goes here
            }
        }
        return meshAddress
    }

    fun provisionGateway(meshDevice: MeshDevice) {
        meshSdkManager.provisionGateway(meshDevice) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishProvisionGateway()   // your code goes here
            }
        }
    }

    fun unProvisionDevice(meshAddress: Int) {
        meshSdkManager.unProvisionDevice(meshAddress = meshAddress) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishUnprovision()   // your code goes here
            }
        }
    }

    fun unProvisionRemote(macAddress: String) {
        meshSdkManager.unProvisionDevice(macAddress = macAddress) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishUnprovision()   // your code goes here
            }
        }
    }

    fun unProvisionGateway(macAddress: String) {
        meshSdkManager.unProvisionGateway(macAddress) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishUnprovisionGateway()   // your code goes here
            }
        }
    }

    fun on(meshAddress: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.On(0L))) {
        }
    }

    fun off(meshAddress: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.Off(0L))) {
        }
    }

    fun blink(meshAddress: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.Blink(0L))) {
        }
    }

    fun color(meshAddress: Int, red: Int, green: Int, blue: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.RGB(red, green, blue, 0L))) {
        }
    }

    fun brightness(meshAddress: Int, brightness: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.Brightness(brightness))) {
        }
    }

    fun cct(meshAddress: Int, cct: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(
            Commands.CCT(cct))) {
        }
    }

    fun addToGroup(meshAddress: Int, groupAddress: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(Commands.AddToGroup(groupAddress))) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishAddGroup()   // your code goes here
            }
        }
    }

    fun addToScene(meshAddress: Int, sceneAddress: Int, brightness: Int, red: Int, green: Int, blue: Int, cct: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(Commands.AddScene(sceneAddress, brightness, red, green, blue, cct, 0))) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishAddScene()   // your code goes here
            }
        }
    }

    fun loadScene(meshAddress: Int, sceneAddress: Int) {
        meshSdkManager.sendCommand(meshAddress, listOf(Commands.LoadScene(sceneAddress, 0))) {
            CoroutineScope(Dispatchers.Main).launch {
                NativeMethodChannel.finishLoadScene()   // your code goes here
            }
        }
    }

    private fun resetOtaUI() {
        otaStatusString.value = ""
        otaMeshProgress.value = 0
        otaFileSentProgress.value = 0
    }
}