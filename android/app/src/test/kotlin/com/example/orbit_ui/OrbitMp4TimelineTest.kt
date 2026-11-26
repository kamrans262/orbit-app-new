package com.example.orbit_ui

import org.junit.Assert.*
import org.junit.Test

class OrbitMp4TimelineTest {
    @Test fun negativeAudioPrimingAndReorderedVideoPreserveRelativeTime(){
        val timeline=OrbitMp4Timeline()
        timeline.record(1,-21_333,100)
        timeline.record(0,33_333,1000)
        timeline.record(0,0,900)
        timeline.record(1,0,100)
        timeline.record(0,66_666,1100)
        timeline.verify(listOf(0,1))
        assertEquals(0L,timeline.normalizedTime(-21_333))
        assertEquals(21_333L,timeline.normalizedTime(0))
        assertEquals(54_666L,timeline.normalizedTime(33_333))
        assertEquals(3,timeline.samples(0))
        assertEquals(24_000.0,timeline.bitrate(0,1_000_000),0.0)
    }
    @Test fun emptyPaddingDoesNotCountAsAnEncodedFrame(){
        val timeline=OrbitMp4Timeline()
        timeline.record(0,0,0)
        assertThrows(IllegalArgumentException::class.java){timeline.verify(listOf(0))}
        timeline.record(0,0,123)
        timeline.verify(listOf(0))
        assertEquals(1,timeline.samples(0))
    }
    @Test fun missingAudioAndUnboundedTimelineAreRejected(){
        val timeline=OrbitMp4Timeline()
        timeline.record(0,0,123)
        assertThrows(IllegalArgumentException::class.java){timeline.verify(listOf(0,1))}
        timeline.record(0,62_000_000,123)
        assertThrows(IllegalArgumentException::class.java){timeline.verify(listOf(0))}
        assertThrows(IllegalArgumentException::class.java){timeline.record(0,0,16_777_217)}
    }
}
