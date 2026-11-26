package com.example.orbit_ui

// MP4 extractors may expose negative presentation timestamps (e.g. AAC
// priming or reordered H.264 samples). Shift all tracks by the SAME origin;
// never clamp each sample independently or silently drop audio/video frames.
internal class OrbitMp4Timeline {
    private val stats = mutableMapOf<Int, TrackStats>()
    private var first = Long.MAX_VALUE
    private var last = Long.MIN_VALUE
    private var totalBytes = 0L
    private var totalSamples = 0
    data class TrackStats(var samples: Int = 0, var bytes: Long = 0)
    fun record(track: Int, timeUs: Long, size: Long) {
        require(track >= 0 && timeUs in -1_000_000L..86_400_000_000L)
        require(size in 0L..16_777_216L)
        require(++totalSamples <= 200_000)
        if (size == 0L) return // Empty padding is not a media frame.
        totalBytes += size
        require(totalBytes <= 524_288_000L)
        first = minOf(first, timeUs)
        last = maxOf(last, timeUs)
        val entry = stats.getOrPut(track) { TrackStats() }
        entry.samples++
        entry.bytes += size
    }
    fun verify(tracks: Collection<Int>) {
        require(tracks.isNotEmpty() && tracks.all { (stats[it]?.samples ?: 0) > 0 })
        require(last - first in 0L..61_000_000L)
    }
    fun normalizedTime(timeUs: Long): Long {
        require(first != Long.MAX_VALUE && timeUs in first..last)
        return timeUs - first
    }
    fun samples(track: Int): Int = stats[track]?.samples ?: 0
    fun bitrate(track: Int, durationUs: Long): Double {
        require(durationUs > 0)
        return (stats[track]?.bytes ?: 0L) * 8_000_000.0 / durationUs
    }
}
