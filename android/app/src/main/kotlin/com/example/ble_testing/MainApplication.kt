package com.fantom.hypnotik

import com.cosmicnode.cnmesh.initializeMeshSDK
import io.flutter.app.FlutterApplication

class MainApplication: FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        initializeMeshSDK()
    }
}