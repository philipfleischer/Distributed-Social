//
//  PlaybackQueueTests.swift
//  Distributed-SocialTests
//
//  Exercises the Spotify-style two-part queue logic in PlaybackService.
//  Each test creates real (empty) files in Documents/Media so the service's
//  missing-file guard does not skip the items.
//

import Foundation
import Testing
@testable import Distributed_Social

@Suite("Playback queue")
struct PlaybackQueueTests {

    /// Creates a MediaItem backed by a real empty file so isFileMissing is false.
    private func makeItem(_ name: String) -> MediaItem {
        let filename = "test-\(UUID().uuidString)-\(name).mp3"
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: dir.appendingPathComponent(filename).path, contents: Data())
        return MediaItem(displayName: name, filename: filename, mediaType: .audio, duration: 60)
    }

    private func makeQueue(_ names: [String]) -> [MediaItem] {
        names.map(makeItem)
    }

    @Test("Playing an item sets it current and fills upNext with the rest")
    func playFillsContext() {
        let service = PlaybackService()
        let songs = makeQueue(["A", "B", "C"])
        service.play(item: songs[0], in: songs, startAt: 0)

        #expect(service.currentItem?.id == songs[0].id)
        #expect(service.upNext.map(\.id) == [songs[1].id, songs[2].id])
        #expect(service.queuedItems.isEmpty)
    }

    @Test("Add to Queue is FIFO; Play Next jumps the line")
    func manualQueueOrdering() {
        let service = PlaybackService()
        let songs = makeQueue(["A", "B"])
        let extra1 = makeItem("Q1")
        let extra2 = makeItem("Q2")
        let front = makeItem("Front")
        service.play(item: songs[0], in: songs, startAt: 0)

        service.addToQueue(extra1)
        service.addToQueue(extra2)
        service.playNext(front)

        #expect(service.queuedItems.map(\.displayName) == ["Front", "Q1", "Q2"])
        // The context section is untouched by manual queueing.
        #expect(service.upNext.map(\.id) == [songs[1].id])
    }

    @Test("Next drains the manual queue before the context resumes")
    func manualQueuePlaysFirst() {
        let service = PlaybackService()
        let songs = makeQueue(["A", "B"])
        let queued = makeItem("Queued")
        service.play(item: songs[0], in: songs, startAt: 0)
        service.addToQueue(queued)

        service.nextTrack()
        #expect(service.currentItem?.id == queued.id)
        #expect(service.queuedItems.isEmpty)

        // After the detour, the context continues where it left off.
        service.nextTrack()
        #expect(service.currentItem?.id == songs[1].id)
    }

    @Test("peekNext prefers the manual queue")
    func peekNextPriority() {
        let service = PlaybackService()
        let songs = makeQueue(["A", "B"])
        let queued = makeItem("Queued")
        service.play(item: songs[0], in: songs, startAt: 0)
        #expect(service.peekNext?.id == songs[1].id)

        service.addToQueue(queued)
        #expect(service.peekNext?.id == queued.id)
    }

    @Test("Jumping to a queued song drops the entries before it")
    func jumpDropsEarlierQueued() {
        let service = PlaybackService()
        let songs = makeQueue(["A"])
        let q = makeQueue(["Q1", "Q2", "Q3"])
        service.play(item: songs[0], in: songs, startAt: 0)
        q.forEach { service.addToQueue($0) }

        service.jump(to: q[2])
        #expect(service.currentItem?.id == q[2].id)
        #expect(service.queuedItems.isEmpty)
    }

    @Test("Reordering and removing within Up Next")
    func upNextEditing() {
        let service = PlaybackService()
        let songs = makeQueue(["A", "B", "C", "D"])
        service.play(item: songs[0], in: songs, startAt: 0)

        // Move "B" (offset 0) below "C" → B ends up after C.
        service.moveUpNext(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(service.upNext.map(\.displayName) == ["C", "B", "D"])

        service.removeFromUpNext(at: IndexSet(integer: 1))
        #expect(service.upNext.map(\.displayName) == ["C", "D"])
    }

    @Test("Playback of an item increments its play count")
    func playCountIncrements() {
        let service = PlaybackService()
        let songs = makeQueue(["A"])
        #expect(songs[0].playCount == 0)
        service.play(item: songs[0], in: songs, startAt: 0)
        #expect(songs[0].playCount == 1)
    }

    @Test("Missing files are not loaded")
    func missingFileSkipped() {
        let service = PlaybackService()
        let ghost = MediaItem(displayName: "Ghost", filename: "does-not-exist.mp3",
                              mediaType: .audio, duration: 60)
        service.play(item: ghost, in: [ghost], startAt: 0)
        #expect(service.currentItem == nil)
    }
}
