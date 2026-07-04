//
//  TimeInterval+Format.swift
//  Distributed-Social
//

import Foundation

extension TimeInterval {
    /// Human-readable clock string, e.g. "3:07" or "1:02:09".
    var formattedTime: String {
        guard !isNaN && !isInfinite else { return "0:00" }
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
