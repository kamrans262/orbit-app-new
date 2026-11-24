package com.example.orbit_ui

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Foreground-only local DNS-SD. Names are random per session, never user IDs.
class MainActivity : FlutterActivity() {
    private var relay: RelayDiscovery? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        relay = RelayDiscovery(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/relay_discovery"))
    }
    override fun onStop() {
        relay?.stop()
        super.onStop()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        relay?.stop()
        relay = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

@Suppress("DEPRECATION")
private class RelayDiscovery(private val activity: FlutterActivity, channel: MethodChannel) {
    private val nsd = activity.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val type = "_orbitrelay._tcp."
    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null
    private val pending = ArrayDeque<NsdServiceInfo>()
    private val peers = linkedMapOf<String, Map<String, Any>>()
    private var resolving = false
    private var generation = 0
    private var ownName = ""
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val name = call.argument<String>("name")
                    val port = call.argument<Int>("port")
                    if (name == null || !name.matches(Regex("o-[a-f0-9]{24}")) || port == null || port !in 1024..65535) {
                        result.error("invalid", "Invalid Relay service", null)
                    } else {
                        try { start(name, port); result.success(null) }
                        catch (_: Exception) { stop(); result.error("unavailable", "Local discovery unavailable", null) }
                    }
                }
                "peers" -> result.success(peers.values.take(24).toList())
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun start(name: String, port: Int) {
        stop()
        val current = generation
        ownName = name
        val reg = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) { activity.runOnUiThread { if (current == generation) ownName = info.serviceName } }
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) { activity.runOnUiThread { if (current == generation) stop() } }
            override fun onServiceUnregistered(info: NsdServiceInfo) {}
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) {}
        }
        registration = reg
        nsd.registerService(NsdServiceInfo().apply { serviceName = name; serviceType = type; setPort(port) }, NsdManager.PROTOCOL_DNS_SD, reg)
        val scan = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {}
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, code: Int) { activity.runOnUiThread { if (current == generation) stop() } }
            override fun onStopDiscoveryFailed(serviceType: String, code: Int) {}
            override fun onServiceFound(info: NsdServiceInfo) { activity.runOnUiThread {
                if (current == generation && info.serviceName != ownName &&
                    info.serviceName.startsWith("o-") && pending.size < 24 && !peers.containsKey(info.serviceName)) {
                    pending.add(info); resolve(current)
                }
            } }
            override fun onServiceLost(info: NsdServiceInfo) { activity.runOnUiThread {
                if (current == generation) peers.remove(info.serviceName)
            } }
        }
        discovery = scan
        nsd.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, scan)
    }
    private fun resolve(current: Int) {
        if (resolving || pending.isEmpty() || current != generation) return
        resolving = true
        val item = pending.removeFirst()
        try {
            nsd.resolveService(item, object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) { activity.runOnUiThread {
                    if (current == generation) { resolving = false; resolve(current) }
                } }
                override fun onServiceResolved(info: NsdServiceInfo) { activity.runOnUiThread {
                    if (current == generation) {
                        val host = info.host?.hostAddress
                        if (host != null && info.serviceName != ownName && peers.size < 24) {
                            peers[info.serviceName] = mapOf("host" to host, "port" to info.port)
                        }
                        resolving = false; resolve(current)
                    }
                } }
            })
        } catch (_: Exception) { resolving = false }
    }
    fun stop() {
        generation++
        registration?.let { try { nsd.unregisterService(it) } catch (_: Exception) {} }
        discovery?.let { try { nsd.stopServiceDiscovery(it) } catch (_: Exception) {} }
        registration = null; discovery = null; resolving = false
        pending.clear(); peers.clear(); ownName = ""
    }
}
