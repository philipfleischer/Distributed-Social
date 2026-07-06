//
//  LibraryFilteringTests.swift
//  Distributed-SocialTests
//

import Foundation
import Testing
@testable import Distributed_Social

@Suite("Library filtering")
struct LibraryFilteringTests {

    private func makeItems() -> [MediaItem] {
        let old = MediaItem(displayName: "Sakura Dreams", filename: "a.mp3",
                            mediaType: .audio, duration: 100,
                            dateImported: Date(timeIntervalSince1970: 1000))
        let new = MediaItem(displayName: "Summer Waves", filename: "b.mp3",
                            mediaType: .audio, duration: 200,
                            dateImported: Date(timeIntervalSince1970: 2000))
        let video = MediaItem(displayName: "Beach Clip", filename: "c.mp4",
                              mediaType: .video, duration: 300,
                              dateImported: Date(timeIntervalSince1970: 3000))
        return [old, new, video]
    }

    @Test("Audio filter excludes videos and sorts newest first")
    func audioFilter() {
        let vm = AudioLibraryViewModel()
        let result = vm.filteredItems(makeItems())
        #expect(result.map(\.displayName) == ["Summer Waves", "Sakura Dreams"])
    }

    @Test("Video filter excludes audio")
    func videoFilter() {
        let vm = VideoLibraryViewModel()
        let result = vm.filteredItems(makeItems())
        #expect(result.map(\.displayName) == ["Beach Clip"])
    }

    @Test("Search is case-insensitive on the title")
    func search() {
        let vm = AudioLibraryViewModel()
        vm.searchText = "sakura"
        let result = vm.filteredItems(makeItems())
        #expect(result.map(\.displayName) == ["Sakura Dreams"])
    }

    @Test("Empty search returns all items of the type")
    func emptySearch() {
        let vm = AudioLibraryViewModel()
        vm.searchText = ""
        #expect(vm.filteredItems(makeItems()).count == 2)
    }
}
