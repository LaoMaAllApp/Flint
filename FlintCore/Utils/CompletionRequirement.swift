//
//  CompletionRequirement.swift
//  FlintCore-iOS
//
//  Created by Marc Palmer on 17/07/2018.
//  Copyright © 2018 Montana Floss Co. Ltd. All rights reserved.
//

import Foundation

/// A type that handles completion callbacks with safety checks and semantics
/// that reduce the risks of callers forgetting to call the completion handler.
///
/// The type is not concurrency safe (see notes in Threading) and it will always call the `completion` handler
/// synchronously, using the supplied `completionQueue` if available, or on whatever the current queue thread is if
/// `currentQueue` is nil.
///
/// To use, define a typealias for this type, with T the type of the completion function's argument (use a tuple if
/// your completion requires multiple arguments).
///
/// Then make your function that requires a completion handler take an instance of this type instead of the closure type, and make
/// the function expect a return value of the nested `Status` type:
///
/// ```
/// protocol MyCoordinator {
///   typealias DoSomethingCompletion = CompletionRequirement<Bool>
///
///   func doSomething(input: Any, completionRequirement: DoSomethingCompletion) -> DoSomethingCompletion.Status
/// }
/// ```
///
/// Now, when calling this function on the protocol, you construct the requirement instance, pass it and verify the result:
///
/// ```
/// let coordinator: MyCoordinator = ...
/// let completion = MyCoordinator.DoSomethingCompletion( { (shouldCancel: Bool, completedAsync: Bool) in
///    print("Cancel? \(shouldCancel)")
/// })
///
/// The block takes one argument of type `T`, in this case a boolean, and a second `Bool` argument that indicates
/// if the completion block has been called asynchronously.
///
/// // Call the function that requires completion
/// let status = coordinator.doSomething(input: x, completionRequirement: completion)
///
/// // Make sure one of the valid statuses was returned.
/// // This safety test ensures that the completion from the correct completion requirement instance was returned.
/// precondition(completion.verify(status))
///
/// // If the result does not return true for `isCompletingAsync`, the completion callback will have already been called by now.
/// if !status.isCompletingAsync {
///     print("Completed synchronously: \(status.value)")
/// } else {
///     print("Completing asynchronously... see you later")
/// }
/// ```
///
/// When implementing such a function requiring a completion handler, you return one of two statuses returned by either
/// the `CompletionRequirement.completed(_ arg: T)` or `CompletionRequirement.willCompleteAsync()`.
/// The `CompletionRequirement` will take care of calling the completion block as appropriate.
///
/// ```
/// func doSomething(input: Any, completionRequirement: DoSomethingCompletion) -> DoSomethingCompletion.Status {
///     return completionRequirement.completedSync(false)
/// }
///
/// // or for async completion, you retain the result and later call `completed(value)`
///
/// func doSomething(input: Any, completionRequirement: DoSomethingCompletion) -> DoSomethingCompletion.Status {
///     // Capture the async status
///     let result = completionRequirement.willCompleteAsync()
///     DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
///         // Use the retained status to indicate completion later
///         result.completed(false)
///     }
///     return result
/// }
///
/// ## Threading
///
/// A `CompletionRequirement` is not concurrency safe. You must not change any properties or call any methods
/// after calling `completedSync` or `willCompleteAsync`. State of the object will not change asynchronously once
/// you have called either of these.
/// ```
public class CompletionRequirement<T> {

    /// An "abstract" base for the status result type.
    /// By design it must not be possible to instantiate this type in apps, so we can trust
    /// the instance handed back to the app matches our semantics.
    public class Status {
        /// This initialiser *must not* be publicly accessible because it prevents maverick devs
        /// misunderstanding the API and instantiating a status themselves, defeating the completion mechanism.
        fileprivate init() {
        }

        public var isCompletingAsync: Bool {
            flintBug("This base must not be instantiated")
        }
    }

    /// The status that indicates completion occurred synchronously.
    public class SyncCompletionStatus: Status {
        override public var isCompletingAsync: Bool {
            return false
        }
    }

    /// The type for a status indicating completion will occur later.
    /// The caller must retain this and call `completed` at a later point.
    public class DeferredStatus: Status {
        var owner: CompletionRequirement<T>?
        
        /// This initialiser *must not* be publicly accessible because it prevents maverick devs
        /// misunderstanding the API and instantiating a status themselves, defeating the completion mechanism.
        fileprivate init(owner: CompletionRequirement<T>) {
            self.owner = owner
            super.init()
        }

        override public var isCompletingAsync: Bool {
            return true
        }
        
        public func completed(_ result: T) {
            guard let owner = owner else {
                return
            }
            owner.callCompletion(result, callingAsync: true)
        }
    }

    /// The status of this completion. This can be set only once.
    var completionStatus: Status? {
        willSet {
            flintBugPrecondition(completionStatus == nil, "Completion status is being set more than once")
        }
    }
    
    public typealias Handler = (T, _ completedAsync: Bool) -> Void
    public typealias ProxyHandler = (T, _ completedAsync: Bool) -> T

    /// The completion handler to call
    var completionHandler: Handler?
    public let completionQueue: SmartDispatchQueue?
    
    /// Instantiate a new completion requirement that calls the supplied completion handler, either
    /// synchronously or asynchronously.
    public init(smartQueue: SmartDispatchQueue?, completionHandler: @escaping Handler) {
        self.completionHandler = completionHandler
        self.completionQueue = smartQueue
    }

    /// Instantiate a new completion requirement that calls the supplied completion handler, either
    /// synchronously or asynchronously.
    public convenience init(queue: DispatchQueue?, completionHandler: @escaping Handler) {
        self.init(smartQueue: queue.flatMap(SmartDispatchQueue.init), completionHandler: completionHandler)
    }

    /// Internal initialiser for proxy subclass, which will set the completion after
    init() {
        completionQueue = nil
    }

    /// Call to verify that the result belongs to this completion instance and there hasn't been a mistake
    public func verify(_ status: Status) -> Bool {
        return status === completionStatus
    }
    
    /// Call to indicate that completion will be called later, asynchronously by code that has a reference
    /// to the deferred status.
    public func willCompleteAsync() -> DeferredStatus {
        guard completionStatus == nil else {
            flintUsageError("Only one of completedSync() or willCompleteLater() can be called")
        }
        
        // Set "async" execution
        let status = DeferredStatus(owner: self)
        completionStatus = status
        
        // Return a status to inform the caller
        return status
    }

    /// Call to indicate that completion is to be called immediately, synchronously
    public func completedSync(_ result: T) -> SyncCompletionStatus {
        guard self.completionStatus == nil else {
            flintUsageError("Only one of completedSync() or willCompleteLater() can be called")
        }
        
        let completionStatus = SyncCompletionStatus()
        callCompletion(result, callingAsync: false)
        self.completionStatus = completionStatus
        return completionStatus
    }

    public func addProxyCompletionHandler(_ proxyCompletion: @escaping ProxyHandler) {
        // This should go away - make completion non-optional if ProxyCR not needed
        guard let currentCompletionHandler = completionHandler else {
            flintBug("Cannot add a proxy completion handler when there is no completion handler set")
        }
        
        /// Create a new completion closure that calls the proxy, and then calls the old one with the new result.
        /// Very much turtles all the way down. Each new proxy means 2 extra closures called but who's counting?
        /// This is cleaner solution than having a ProxyCompletion subclass
        self.completionHandler = { (result: T, callingAsync: Bool) in
            let proxyResult = proxyCompletion(result, callingAsync)
            return currentCompletionHandler(proxyResult, callingAsync)
        }
    }
    
    private func callCompletion(_ result: T, callingAsync: Bool) {
        guard let completion = completionHandler else {
            flintBug("There is no completion handler closure set")
        }

        let actuallyCallCompletion = {
            completion(result, callingAsync)
        }
        
        if let completionQueue = completionQueue {
            completionQueue.sync(execute: actuallyCallCompletion)
        } else {
            actuallyCallCompletion()
        }
    }
}
