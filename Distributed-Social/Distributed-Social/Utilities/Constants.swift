//
//  Constants.swift
//  Distributed-Social
//

import Foundation

enum Constants {
    enum Directories {
        static let media = "Media"
    }
    enum Playback {
        static let skipInterval: TimeInterval = 15
        static let minPositionToSave: TimeInterval = 5
        static let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    }
    enum Links {
        static let repository = "https://github.com/philipfleischer/Distributed-Social"
    }
}
