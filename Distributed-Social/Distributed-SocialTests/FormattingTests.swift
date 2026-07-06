//
//  FormattingTests.swift
//  Distributed-SocialTests
//

import Foundation
import Testing
@testable import Distributed_Social

@Suite("Time formatting")
struct TimeFormattingTests {

    @Test("Zero and sub-minute durations")
    func shortDurations() {
        #expect(TimeInterval(0).formattedTime == "0:00")
        #expect(TimeInterval(7).formattedTime == "0:07")
        #expect(TimeInterval(59).formattedTime == "0:59")
    }

    @Test("Minutes and hours")
    func longDurations() {
        #expect(TimeInterval(60).formattedTime == "1:00")
        #expect(TimeInterval(187).formattedTime == "3:07")
        #expect(TimeInterval(3600).formattedTime == "1:00:00")
        #expect(TimeInterval(3729).formattedTime == "1:02:09")
    }

    @Test("Invalid values fall back to 0:00")
    func invalidValues() {
        #expect(TimeInterval.nan.formattedTime == "0:00")
        #expect(TimeInterval.infinity.formattedTime == "0:00")
    }
}

@Suite("Media file type detection")
struct URLMediaHelpersTests {

    @Test("Video extensions", arguments: ["mp4", "mov", "m4v", "MP4"])
    func videoFiles(ext: String) {
        #expect(URL(fileURLWithPath: "/tmp/clip.\(ext)").isVideoFile)
    }

    @Test("Audio extensions", arguments: ["mp3", "m4a", "wav", "aac", "flac", "MP3"])
    func audioFiles(ext: String) {
        #expect(URL(fileURLWithPath: "/tmp/song.\(ext)").isAudioFile)
    }

    @Test("Unknown extensions are neither")
    func unknownFiles() {
        let url = URL(fileURLWithPath: "/tmp/document.pdf")
        #expect(!url.isAudioFile)
        #expect(!url.isVideoFile)
    }
}
