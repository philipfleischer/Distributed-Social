//
//  RepeatModeTests.swift
//  Distributed-SocialTests
//

import Testing
@testable import Distributed_Social

@Suite("Repeat mode state machine")
struct RepeatModeTests {

    @Test("Cycles off → all → one → off")
    func cycleOrder() {
        #expect(RepeatMode.off.next() == .all)
        #expect(RepeatMode.all.next() == .one)
        #expect(RepeatMode.one.next() == .off)
    }

    @Test("Only off is inactive")
    func activeStates() {
        #expect(!RepeatMode.off.isActive)
        #expect(RepeatMode.all.isActive)
        #expect(RepeatMode.one.isActive)
    }

    @Test("Repeat-one uses the numbered icon")
    func icons() {
        #expect(RepeatMode.off.systemImage == "repeat")
        #expect(RepeatMode.all.systemImage == "repeat")
        #expect(RepeatMode.one.systemImage == "repeat.1")
    }
}
