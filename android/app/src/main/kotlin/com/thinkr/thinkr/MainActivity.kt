package com.thinkr.thinkr

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsStatusCodes
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets

/**
 * Hosts the thinkr/nearby_connections MethodChannel backed by the Android
 * Nearby Connections API (P2P_CLUSTER strategy: Bluetooth + BLE + Wi-Fi,
 * chosen automatically by Google Play services).
 *
 * Wire payloads are JSON maps matching lib/core/multiplayer/nearby_protocol.dart.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "thinkr/nearby_connections"
        val REQUIRED_PERMISSIONS: Array<String> = buildRequiredPermissions()
        const val PERMISSION_REQUEST_CODE = 4242

        fun buildRequiredPermissions(): Array<String> {
            val base = mutableListOf(
                Manifest.permission.ACCESS_WIFI_STATE,
                Manifest.permission.ACCESS_NETWORK_STATE,
            )
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                base += Manifest.permission.ACCESS_FINE_LOCATION
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                base += Manifest.permission.NEARBY_WIFI_DEVICES
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                base += Manifest.permission.BLUETOOTH_SCAN
                base += Manifest.permission.BLUETOOTH_ADVERTISE
                base += Manifest.permission.BLUETOOTH_CONNECT
            }
            return base.toTypedArray()
        }
    }

    private var channel: MethodChannel? = null

    private val connectionsClient by lazy { Nearby.getConnectionsClient(this) }

    private val discovered = mutableMapOf<String, String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(true)
                    "requestPermissions" -> {
                        requestNearbyPermissions { granted -> result.success(granted) }
                    }
                    "start" -> {
                        val serviceId = call.argument<String>("serviceId") ?: ""
                        val localName = call.argument<String>("localName") ?: "Thinkr player"
                        startNearby(serviceId, localName)
                        result.success(null)
                    }
                    "stop" -> {
                        stopAll()
                        result.success(null)
                    }
                    "requestConnection" -> {
                        val endpointId = call.argument<String>("endpointId") ?: ""
                        val token = call.argument<String>("token") ?: endpointId
                        connectionsClient.requestConnection(localUserName, endpointId, connectionLifecycleCallback)
                        result.success(null)
                    }
                    "acceptConnection" -> {
                        val endpointId = call.argument<String>("endpointId") ?: ""
                        connectionsClient.acceptConnection(endpointId, payloadCallback)
                        result.success(null)
                    }
                    "send" -> {
                        val endpointId = call.argument<String>("endpointId") ?: ""
                        val payloadArg: Map<String, Any?> =
                            call.argument("payload") ?: emptyMap()
                        val json = JSONObject(payloadArg)
                        connectionsClient.sendPayload(
                            endpointId,
                            Payload.fromBytes(json.toString().toByteArray(StandardCharsets.UTF_8))
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private val localUserName: String
        get() = android.provider.Settings.Global.getString(
            contentResolver,
            "device_name"
        ) ?: "Thinkr player"

    private fun requestNearbyPermissions(onDone: (Boolean) -> Unit) {
        val missing = REQUIRED_PERMISSIONS.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            onDone(true)
            return
        }
        ActivityCompat.requestPermissions(
            this,
            missing.toTypedArray(),
            PERMISSION_REQUEST_CODE
        )
        pendingPermissionResult = onDone
    }

    private var pendingPermissionResult: ((Boolean) -> Unit)? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.invoke(allGranted)
            pendingPermissionResult = null
        }
    }

    private fun startNearby(serviceId: String, localName: String) {
        stopAll()
        // Host: advertise. Guest: discover. Both sides run the same callback
        // set, so role handling stays in Dart.
        connectionsClient.startAdvertising(
            localName,
            serviceId,
            connectionLifecycleCallback,
            com.google.android.gms.nearby.connection.AdvertisingOptions.Builder()
                .setStrategy(Strategy.P2P_CLUSTER)
                .build()
        )
        connectionsClient.startDiscovery(
            serviceId,
            endpointDiscoveryCallback,
            com.google.android.gms.nearby.connection.DiscoveryOptions.Builder()
                .setStrategy(Strategy.P2P_CLUSTER)
                .build()
        )
    }

    private fun stopAll() {
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            discovered[endpointId] = info.endpointName
            invoke("onPeerDiscovered", mapOf("endpointId" to endpointId, "name" to info.endpointName))
        }

        override fun onEndpointLost(endpointId: String) {
            discovered.remove(endpointId)
            invoke("onPeerLost", mapOf("endpointId" to endpointId))
        }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            invoke(
                "onConnectionInitiated",
                mapOf("endpointId" to endpointId, "name" to info.endpointName, "token" to info.authenticationToken)
            )
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            when (result.status.statusCode) {
                ConnectionsStatusCodes.STATUS_OK -> invoke("onConnected", mapOf("endpointId" to endpointId))
                ConnectionsStatusCodes.STATUS_CONNECTION_REJECTED -> invoke(
                    "onDisconnected",
                    mapOf("endpointId" to endpointId)
                )
                else -> invoke("onDisconnected", mapOf("endpointId" to endpointId))
            }
        }

        override fun onDisconnected(endpointId: String) {
            invoke("onDisconnected", mapOf("endpointId" to endpointId))
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type != Payload.Type.BYTES) return
            val bytes = payload.asBytes() ?: return
            try {
                val json = JSONObject(String(bytes, StandardCharsets.UTF_8))
                val map = HashMap<String, Any?>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    map[key] = json.get(key)
                }
                invoke("onPayloadReceived", mapOf("endpointId" to endpointId, "payload" to map))
            } catch (_: Exception) {
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Bytes payloads arrive atomically; nothing to track.
        }
    }

    private fun invoke(method: String, args: Map<String, Any?>) {
        runOnUiThread { channel?.invokeMethod(method, args) }
    }
}
