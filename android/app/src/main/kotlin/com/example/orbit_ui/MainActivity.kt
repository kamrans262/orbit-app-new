package com.example.orbit_ui

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import java.io.File
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Foreground-only local DNS-SD. Names are random per session, never user IDs.
class MainActivity : FlutterActivity() {
    private var relay: RelayDiscovery? = null
    private var billing: OrbitStoreBilling? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        relay = RelayDiscovery(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/relay_discovery"))
        billing = OrbitStoreBilling(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"orbit/billing"))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"orbit/capture_inspection").setMethodCallHandler { call,result ->
            if(call.method!="inspect"){result.notImplemented();return@setMethodCallHandler}
            val path=call.argument<String>("path")
            if(path==null){result.error("invalid","Capture file unavailable",null);return@setMethodCallHandler}
            Thread {
                try {
                    val file=File(path).canonicalFile
                    val roots=listOf(cacheDir.canonicalFile,filesDir.canonicalFile)
                    require(roots.any { file.path.startsWith(it.path+File.separator) } && file.isFile && file.length() in 1L..524288000L)
                    val metadata=inspectCapture(file.path)
                    runOnUiThread { result.success(metadata) }
                } catch (_:Exception) {
                    runOnUiThread { result.error("invalid","Capture metadata unavailable",null) }
                }
            }.start()
        }
    }
    override fun onStop() {
        relay?.stop()
        super.onStop()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        relay?.stop()
        relay = null
        billing?.close()
        billing = null
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

private fun inspectCapture(path:String):Map<String,Any> {
    val retriever=MediaMetadataRetriever()
    val extractor=MediaExtractor()
    try {
        retriever.setDataSource(path)
        extractor.setDataSource(path)
        val duration=retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: error("duration")
        require(duration in 1L..60000L)
        val location=!retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION).isNullOrBlank()
        val result=mutableMapOf<String,Any>("duration_ms" to duration.toInt(),"location_metadata" to location)
        var audio=0;var video=0
        for(i in 0 until extractor.trackCount){
            val format=extractor.getTrackFormat(i)
            val mime=format.getString(MediaFormat.KEY_MIME) ?: continue
            if(mime.startsWith("audio/")){
                audio++
                val csd=format.getByteBuffer("csd-0")
                val profile=if(format.containsKey(MediaFormat.KEY_AAC_PROFILE))format.getInteger(MediaFormat.KEY_AAC_PROFILE)
                  else if(csd!=null&&csd.remaining()>0)((csd.get(csd.position()).toInt() and 0xff) shr 3) else -1
                result["audio_aac_lc"]=mime=="audio/mp4a-latm"&&profile==2
                result["audio_channels"]=if(format.containsKey(MediaFormat.KEY_CHANNEL_COUNT))format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 0
                result["audio_bps"]=if(format.containsKey(MediaFormat.KEY_BIT_RATE))format.getInteger(MediaFormat.KEY_BIT_RATE) else
                    (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0)
            }else if(mime.startsWith("video/")){
                video++
                result["video_h264"]=mime=="video/avc"
                result["width"]=format.getInteger(MediaFormat.KEY_WIDTH)
                result["height"]=format.getInteger(MediaFormat.KEY_HEIGHT)
                result["fps"]=try {format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()}catch(_:Exception){
                    extractor.selectTrack(i)
                    var count=0
                    while(extractor.sampleTime>=0 && count<=4000){count++;if(!extractor.advance())break}
                    extractor.unselectTrack(i)
                    if(count>4000)0.0 else count*1000.0/duration
                }
                result["video_bps"]=if(format.containsKey(MediaFormat.KEY_BIT_RATE))format.getInteger(MediaFormat.KEY_BIT_RATE) else
                    (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0)
            }
        }
        result["audio_tracks"]=audio;result["video_tracks"]=video
        return result
    } finally {extractor.release();retriever.release()}
}
