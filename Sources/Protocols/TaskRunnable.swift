//
//  TaskRunnable.swift
//  AsyncTaskKit
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import Foundation

public protocol TaskRunnable {
    associatedtype Output

    func cancel() async

    @discardableResult
    func run() async throws -> Output
}
