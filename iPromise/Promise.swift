//
//  Promise.swift
//  iPromise
//
//  Created by jzaczek on 24.10.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import UIKit

///TODO:
/// - this is not a complete implementation
/// - chaining does not work as specified in Promise/A+ spec
/// - 'throws' closure types should be allowed
/// - handlers should be executed one by one - right now they are scheduled all at once
/// - this means then() should return a new object after each call
/// - implement background tasks using nsoperationqueue

/// A Promise represents a proxy for a value not necessarily known when the promise
/// is created. It allows you to associate handlers to an asynchronous action's eventual 
/// success value or failure reason. This lets asynchronous methods return values like 
/// synchronous methods: instead of the final value, the asynchronous method returns 
/// a promise of having a value at some point in the future.
public class Promise {
    
    ///Describes promise's state
    private enum State {
        case Pending
        case Fulfilled
        case Rejected
    }
    
    private var state: State {
        didSet {
            self.stateChanged(state)
        }
    }
    private var _result: Any?
    private var _reason: Any?
    private var onSuccessQueue: Queue<(Promise)->Void>
    private var onFailureQueue: Queue<(Promise)->Void>
    private var executor: (((Any)->Void, (Any)->Void)->Void)?
    
    /// Returns promise's result
    public var result: Any {
        get {
            return unwrap(_result)
        }
    }
    
    /// Returns promise's rejection reason
    public var reason: Any {
        get {
            return unwrap(_reason)
        }
    }
    
    private init(state: State) {
        self.state = state
        self.onSuccessQueue = Queue<(Promise)->Void>()
        self.onFailureQueue = Queue<(Promise)->Void>()
    }
    
    /// executor
    /// Function object with two arguments resolve and reject. The first argument fulfills 
    /// the promise, the second argument rejects it. We can call these functions once our
    /// operation is completed.
    convenience init(executor: ((Any)->Void, (Any)->Void)->Void) {
        self.init(state: .Pending)
        self.executor = executor
        
        self.startExecution()
    }
    
    /// Appends fulfillment and rejection handlers to the promise, and returns a promise
    public func then(onSuccess: ((Promise) -> Void)? = nil, onFailure: ((Promise) -> Void)? = nil) -> Promise {
        switch state {
        
        case .Pending:
            if let onSuccess = onSuccess {
                self.onSuccessQueue.push(onSuccess)
            }
            
            if let onFailure = onFailure {
                self.onFailureQueue.push(onFailure)
            }
        case .Fulfilled:
            if let action = onSuccess {
                dispatch_async(dispatch_get_main_queue()) {
                    action(self)
                }
            }
        case .Rejected:
            if let action = onFailure {
                dispatch_async(dispatch_get_main_queue()) {
                    action(self)
                }
            }
        }
        
        return self
    }
    
    /// Appends a fulfillment handler callback to the promise, and returns a promise
    public func success(onSuccess: (Promise) -> Void) -> Promise {
        return self.then(onSuccess)
    }
    
    /// Appends a rejection handler callback to the promise, and returns a promise
    public func failure(onFailure: (Promise) -> Void) -> Promise {
        return self.then(nil, onFailure: onFailure)
    }
    
    /// Returns a Promise object that is rejected with the given reason.
    public class func reject(reason: Any) -> Promise {
        let promise = Promise(state: .Rejected)
        promise._reason = reason
        
        return promise
    }
    
    /// Returns either a new promise resolved with the passed argument, 
    /// or the argument itself if the argument is a promise
    public class func fulfill(result: Any) -> Promise {
        if let promise = result as? Promise {
            return promise
        }
        else {
            let promise = Promise(state: .Fulfilled)
            promise._result = result
            
            return promise
        }
    }
    
    /// Returns a promise that resolves or rejects as soon as one of the promises in the array 
    /// resolves or rejects, with the value or reason from that promise.
    public class func race(promises: [Promise]) -> Promise {
        return Promise {
            fulfill, reject in
            
            var done: Bool = false
            
            for promise in promises {
                promise.success {
                    p in
                    if (!done) {
                        synchronized(done, closure: {
                            done = true
                            fulfill(p.result)
                        })
                    }
                }
                
                promise.failure {
                    p in
                    if (!done) {
                        synchronized(done, closure: {
                            done = true
                            reject(p.reason)
                        })
                    }
                }
                
            }
        }
    }
    
    /// Returns a promise that resolves when all of the promises in the array argument have resolved. 
    /// This is useful for aggregating results of multiple promises together.
    public class func all(promises: [Promise]) -> Promise {
        return Promise {
            fulfill, reject in
            
            var finishLineCount = 0
            var finishLine = Array<Any>(count: promises.count, repeatedValue: "")
            
            for (i, promise) in promises.enumerate() {
                promise.success {
                    p in
                    synchronized(finishLineCount) {
                        finishLine[i] = p.result
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            fulfill(finishLine)
                        }
                    }
                }
                
                promise.failure {
                    p in
                    synchronized(finishLineCount) {
                        finishLine[i] = p.reason
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            fulfill(finishLine)
                        }
                    }
                }
            }
        }
    }
    
    /// Fulfill this promise with a value
    internal func fulfill(result: Any) {
        if let promise = result as? Promise {
            promise.then({
                p in
                self.fulfill(p.result)
            }, onFailure: {
                p in
                self.reject(p.reason)
            })
        }
        else {
            self._result = result
            self.state = .Fulfilled
        }
    }
    
    /// Reject this promise with a reason
    internal func reject(reason: Any) {
        self._reason = reason
        self.state = .Rejected
    }
    
    /// Start execution of promise's executor
    private func startExecution() {
        let queuePriority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        
        //todo: refactor using nsoperationqueue to allow cancelling of the operations
        dispatch_async(dispatch_get_global_queue(queuePriority, 0)) {
            self.executor?(self.fulfill, self.reject)
        }
    }
    
    /// React on promise's state changes - call respective handlers
    private func stateChanged(state: State) {
        switch state {
        case .Fulfilled:
            self.executeAll(self.onSuccessQueue)
        case .Rejected:
            self.executeAll(self.onFailureQueue)
        default:
            break
        }
    }
    
    /// Execute all closures in a queue
    private func executeAll(queue: Queue<(Promise)->Void>) {
        while !queue.isEmpty() {
            let action : (Promise) -> Void = queue.pop()!
            
            dispatch_async(dispatch_get_main_queue()) {
                action(self)
            }
        }
    }
}

/// Schedules asynchronous work to be done in a background thread and returns a 
/// promise of the result
public func async(work: () throws -> Any) -> Promise {
    return Promise {
        fulfill, reject in
    
        do {
            let result = try work()
            fulfill(result)
        }
        catch let error {
            reject(error)
        }
    }
}

/// Synchronizes closure
/// http://stackoverflow.com/questions/24045895/what-is-the-swift-equivalent-to-objective-cs-synchronized/24103086#24103086
internal func synchronized(lock: AnyObject, closure: () -> Void) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

/// Unwraps optional Any-values using reflection
/// http://stackoverflow.com/questions/27989094/how-to-unwrap-an-optional-value-from-any-type/32516815#32516815
internal func unwrap(any: Any) -> Any {
    let mi = Mirror(reflecting: any)
    
    if mi.displayStyle != .Optional {
        return any
    }
    
    if mi.children.count == 0 { return NSNull() }
    let (_, some) = mi.children.first!
    return some
}