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
        // Only expose the presence of a bundled Maps SDK key. Never return
        // the credential itself to Flutter, logs or the Orbit backend.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"orbit/map_provider")
            .setMethodCallHandler { call,result ->
                if(call.method!="configured"){result.notImplemented();return@setMethodCallHandler}
                val key=try {
                    @Suppress("DEPRECATION")
                    packageManager.getApplicationInfo(packageName,
                        android.content.pm.PackageManager.GET_META_DATA)
                        .metaData?.getString("com.google.android.geo.API_KEY")?.trim()
                }catch(_:Exception){null}
                result.success(!key.isNullOrEmpty() && key!="NO_GOOGLE_MAPS_ANDROID_KEY_CONFIGURED" &&
                    !key.contains("\${"))
            }
        relay = RelayDiscovery(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/relay_discovery"))
        billing = OrbitStoreBilling(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"orbit/billing"))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"orbit/capture_inspection").setMethodCallHandler { call,result ->
            if(call.method!="inspect" && call.method!="sanitizeMp4"){result.notImplemented();return@setMethodCallHandler}
            val path=call.argument<String>("path")
            if(path==null){result.error("invalid","Capture file unavailable",null);return@setMethodCallHandler}
            Thread {
                try {
                    val file=File(path).canonicalFile
                    val roots=listOf(cacheDir.canonicalFile,filesDir.canonicalFile)
                    require(roots.any { file.path.startsWith(it.path+File.separator) } && file.isFile && file.length() in 1L..524288000L)
                    if(call.method=="sanitizeMp4"){
                        val output=File(call.argument<String>("output") ?: error("output")).canonicalFile
                        val root=File(cacheDir,"orbit-m23-capture-scratch").canonicalFile
                        require(output.parentFile==root && output.extension=="mp4" && !output.exists() && output!=file)
                        sanitizeOrbitMp4(file.path,output.path,call.argument<Boolean>("muted")==true)
                        runOnUiThread { result.success(null) }
                    }else{
                        val metadata=inspectCapture(file.path)
                        runOnUiThread { result.success(metadata) }
                    }
                } catch (error:Exception) {
                    // Never log paths, sample data or source metadata.
                    val code=if(error is OrbitMp4Failure)error.code else
                        if(call.method=="sanitizeMp4")"remux_failed" else "inspection_failed"
                    android.util.Log.w("OrbitCapture","operation=${call.method} code=$code type=${error.javaClass.simpleName}")
                    runOnUiThread { result.error(code,"Capture processing unavailable",null) }
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

private class OrbitMp4Failure(val code:String):Exception(code)
private fun mp4Require(condition:Boolean,code:String){
    if(!condition)throw OrbitMp4Failure(code)
}

// Read actual samples before muxing. The index, not a negative presentation
// timestamp, is the end-of-stream sentinel. Older Android versions use a
// bounded reusable buffer because getSampleSize is only available on API 28.
private fun scanOrbitSamples(path:String,tracks:Collection<Int>):OrbitMp4Timeline{
    val reader=MediaExtractor()
    val timeline=OrbitMp4Timeline()
    try{
        reader.setDataSource(path)
        tracks.forEach { reader.selectTrack(it) }
        val legacyBuffer=if(android.os.Build.VERSION.SDK_INT<28)
            java.nio.ByteBuffer.allocateDirect(16*1024*1024) else null
        while(reader.sampleTrackIndex>=0){
            val index=reader.sampleTrackIndex
            val flags=reader.sampleFlags
            mp4Require(index in tracks,"unexpected_track")
            mp4Require((flags and MediaExtractor.SAMPLE_FLAG_ENCRYPTED)==0 &&
                (flags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME)==0,"unsupported_sample_flags")
            val size=if(android.os.Build.VERSION.SDK_INT>=28)reader.sampleSize else {
                val buffer=legacyBuffer!!
                buffer.clear()
                reader.readSampleData(buffer,0).toLong()
            }
            try{timeline.record(index,reader.sampleTime,size)}
            catch(_:IllegalArgumentException){throw OrbitMp4Failure("invalid_sample_timeline")}
            if(!reader.advance())break
        }
        try{timeline.verify(tracks)}
        catch(_:IllegalArgumentException){throw OrbitMp4Failure("empty_or_invalid_track")}
        return timeline
    }finally{reader.release()}
}

// Rebuild the container from only the selected H.264/AAC tracks. Never
// transfer location or other container metadata. Orientation is explicit.
private fun sanitizeOrbitMp4(input:String,output:String,muted:Boolean){
    val extractor=MediaExtractor()
    val metadata=MediaMetadataRetriever()
    var muxer:android.media.MediaMuxer?=null
    var started=false
    var completed=false
    try{
        extractor.setDataSource(input);metadata.setDataSource(input)
        val formats=linkedMapOf<Int,MediaFormat>()
        var videos=0;var audios=0
        for(i in 0 until extractor.trackCount){
            val format=extractor.getTrackFormat(i)
            val mime=format.getString(MediaFormat.KEY_MIME)?:continue
            if(mime.startsWith("video/")){
                mp4Require(mime=="video/avc" && ++videos==1,"unsupported_video_track")
            }else if(mime.startsWith("audio/")){
                if(muted)continue
                mp4Require(mime=="audio/mp4a-latm" && ++audios==1,"unsupported_audio_track")
            }else continue
            formats[i]=format
        }
        mp4Require(videos==1,"missing_video_track")
        val timeline=scanOrbitSamples(input,formats.keys)
        val target=android.media.MediaMuxer(output,android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxer=target
        val rotation=metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()?:0
        if(rotation in listOf(0,90,180,270))target.setOrientationHint(rotation)
        val tracks=mutableMapOf<Int,Int>()
        for((index,format) in formats){
            tracks[index]=target.addTrack(format)
            extractor.selectTrack(index)
        }
        target.start();started=true
        val buffer=java.nio.ByteBuffer.allocateDirect(16*1024*1024)
        val info=android.media.MediaCodec.BufferInfo()
        val written=mutableMapOf<Int,Int>()
        while(extractor.sampleTrackIndex>=0){
            val index=extractor.sampleTrackIndex
            val out=tracks[index]?:throw OrbitMp4Failure("unexpected_track")
            val flags=extractor.sampleFlags
            mp4Require((flags and MediaExtractor.SAMPLE_FLAG_ENCRYPTED)==0 &&
                (flags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME)==0,"unsupported_sample_flags")
            val time=extractor.sampleTime
            buffer.clear()
            val size=extractor.readSampleData(buffer,0)
            mp4Require(size in 0..buffer.capacity(),"invalid_sample_size")
            if(size>0){
                buffer.position(0);buffer.limit(size)
                val normalized=try{timeline.normalizedTime(time)}
                    catch(_:IllegalArgumentException){throw OrbitMp4Failure("invalid_sample_timeline")}
                info.set(0,size,normalized,if((flags and MediaExtractor.SAMPLE_FLAG_SYNC)!=0)
                    android.media.MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                try{target.writeSampleData(out,buffer,info)}
                catch(_:Exception){throw OrbitMp4Failure("muxer_write_failed")}
                written[index]=(written[index]?:0)+1
            }
            if(!extractor.advance())break
        }
        mp4Require(tracks.keys.all { written[it]==timeline.samples(it) },"incomplete_remux")
        target.stop();started=false;completed=true
    }finally{
        if(started)try{muxer?.stop()}catch(_:Exception){}
        try{muxer?.release()}catch(_:Exception){}
        extractor.release();metadata.release()
        if(!completed)File(output).delete()
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
        val rotation=retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()?:0
        val result=mutableMapOf<String,Any>("duration_ms" to duration.toInt(),"location_metadata" to location,
            "rotation_degrees" to rotation)
        val avTracks=(0 until extractor.trackCount).filter {
            val mime=extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?:""
            mime.startsWith("audio/")||mime.startsWith("video/")
        }
        val timeline=scanOrbitSamples(path,avTracks)
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
                val trackDuration=try{format.getLong(MediaFormat.KEY_DURATION)}catch(_:Exception){0L}
                val measuredDuration=if(trackDuration>0)minOf(trackDuration,duration*1000L) else duration*1000L
                result["audio_bps"]=timeline.bitrate(i,measuredDuration)
            }else if(mime.startsWith("video/")){
                video++
                result["video_h264"]=mime=="video/avc"
                result["width"]=format.getInteger(MediaFormat.KEY_WIDTH)
                result["height"]=format.getInteger(MediaFormat.KEY_HEIGHT)
                val trackDuration=try{format.getLong(MediaFormat.KEY_DURATION)}catch(_:Exception){0L}
                val measuredDuration=if(trackDuration>0)minOf(trackDuration,duration*1000L) else duration*1000L
                val declaredFps=try {format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()}
                    catch(_:Exception){try{format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()}catch(_:Exception){0.0}}
                val measuredFps=timeline.samples(i)*1_000_000.0/measuredDuration
                // A missing/zero reported frame rate is not a failed clip.
                // The measured sample rate remains an independent upper check.
                result["fps"]=maxOf(if(declaredFps.isFinite())declaredFps else 0.0,measuredFps)
                result["video_bps"]=timeline.bitrate(i,measuredDuration)
            }
        }
        result["audio_tracks"]=audio;result["video_tracks"]=video
        return result
    } finally {extractor.release();retriever.release()}
}
