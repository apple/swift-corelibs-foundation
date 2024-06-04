// Foundation/URLSession/TaskRegistry.swift - URLSession & libcurl
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// -----------------------------------------------------------------------------
///
/// These are libcurl helpers for the URLSession API code.
/// - SeeAlso: https://curl.haxx.se/libcurl/c/
/// - SeeAlso: URLSession.swift
///
// -----------------------------------------------------------------------------

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif

@_implementationOnly import CoreFoundation
import Dispatch

extension URLSession {
    /// This helper class keeps track of all tasks, and their behaviours.
    ///
    /// Each `URLSession` has a `TaskRegistry` for its running tasks. The
    /// *behaviour* defines what action is to be taken e.g. upon completion.
    /// The behaviour stores the completion handler for tasks that are
    /// completion handler based.
    ///
    /// - Note: This must **only** be accessed on the owning session's work queue.
    class _TaskRegistry {
        /// Completion handler for `URLSessionDataTask`, and `URLSessionUploadTask`.
        typealias DataTaskCompletion = (Data?, URLResponse?, Error?) -> Void
        /// Completion handler for `URLSessionDownloadTask`.
        typealias DownloadTaskCompletion = (URL?, URLResponse?, Error?) -> Void
        /// What to do upon events (such as completion) of a specific task.
        enum _Behaviour {
            /// Call the `URLSession`s delegate
            case callDelegate
            /// Default action for all events, except for completion.
            case dataCompletionHandler(DataTaskCompletion)
            /// Default action for all asynchronous events.
            case dataCompletionHandlerWithTaskDelegate(DataTaskCompletion, URLSessionTaskDelegate?)
            /// Default action for all events, except for completion.
            case downloadCompletionHandler(DownloadTaskCompletion)
        }
        
        fileprivate var tasks: [Int: URLSessionTask] = [:]
        fileprivate var behaviours: [Int: _Behaviour] = [:]
        fileprivate var tasksFinishedCallback: (() -> Void)?
    }
}

extension URLSession._TaskRegistry {
    /// Add a task
    ///
    /// - Note: This must **only** be accessed on the owning session's work queue.
    func add(_ task: URLSessionTask, behaviour: _Behaviour) {
        let identifier = task.taskIdentifier
        guard identifier != 0 else { fatalError("Invalid task identifier") }
        guard tasks.index(forKey: identifier) == nil else {
            if tasks[identifier] === task {
                fatalError("Trying to re-insert a task that's already in the registry.")
            } else {
                fatalError("Trying to insert a task, but a different task with the same identifier is already in the registry.")
            }
        }
        tasks[identifier] = task
        behaviours[identifier] = behaviour
    }
    /// Remove a task
    ///
    /// - Note: This must **only** be accessed on the owning session's work queue.
    func remove(_ task: URLSessionTask) {
        let identifier = task.taskIdentifier
        guard identifier != 0 else { fatalError("Invalid task identifier") }
        guard let tasksIdx = tasks.index(forKey: identifier) else {
            fatalError("Trying to remove task, but it's not in the registry.")
        }
        tasks.remove(at: tasksIdx)
        guard let behaviourIdx = behaviours.index(forKey: identifier) else {
            fatalError("Trying to remove task's behaviour, but it's not in the registry.")
        }
        behaviours.remove(at: behaviourIdx)

        guard let allTasksFinished = tasksFinishedCallback else { return }
        if self.isEmpty {
            allTasksFinished()
        }
    }

    func notify(on tasksCompletion: @escaping () -> Void) {
        tasksFinishedCallback = tasksCompletion
    }

    var isEmpty: Bool {
        return tasks.isEmpty
    }
    
    var allTasks: [URLSessionTask] {
        return tasks.map { $0.value }
    }
}
extension URLSession._TaskRegistry {
    /// The behaviour that's registered for the given task.
    ///
    /// - Note: It is a programming error to pass a task that isn't registered.
    /// - Note: This must **only** be accessed on the owning session's work queue.
    func behaviour(for task: URLSessionTask) -> _Behaviour {
        guard let b = behaviours[task.taskIdentifier] else {
            fatalError("Trying to access a behaviour for a task that in not in the registry.")
        }
        return b
    }
}
