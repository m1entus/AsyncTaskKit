//
//  Task+Extensions.swift
//  AsyncTaskKit
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    /// Suspends the current task for at least the given duration in seconds.
    /// - Parameter seconds: The sleep duration in seconds.
    public static func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
