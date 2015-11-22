//
//  Promise.swift
//  iPromise
//
//  Created by jzaczek on 24.10.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import UIKit

/// A Promise represents a proxy for a value not necessarily known when the promise
/// is created. It allows to associate handlers to an asynchronous action's eventual
/// success value or failure reason. This lets asynchronous methods return values like 
/// synchronous methods: instead of the final value, the asynchronous method returns 
/// a promise of having a value at some point in the future.
public class Promise {
    
    /**
    Closure with one argument, which is either promise's result or
    promise's rejection reason. This closure returns a value which is then
    passed to a promise returned by ```then()``` call as its result.
    */
    public typealias HandlerFunction = ((Any) throws -> Any)
    
    /**
    Closure with two arguments fulfill and reject. The first argument
    fulfills the promise, the second argument rejects it. We can call
    these functions once our operation is completed.
    */
    public typealias ExecutorFunction = ((Any)->Void, (Any)->Void) throws -> Void
    
    /** 
    Describes promise's state. Promise is resolved when it is either fulfilled or
    rejected.
    - **Pending**: not resolved - the promise's task has just started
    - **Fulfilled**: resolved with success - a *result* is available: ```Promise.result```
    - **Rejected**: resolved with failure - a *reason of rejection* is available: ```Promise.reason```
    */
    public enum State {
        case Pending
        case Fulfilled
        case Rejected
    }
    
    //
    // MARK: - properties
    //
    
    /// Promise's internal state, described by ```Promise.State``` enum.
    private var _state: State {
        didSet {
            self.stateChanged(_state)
        }
    }
    
    public var state: State {
        get {
            return _state
        }
    }
    
    /// Promise's result, if the promise is fulfilled
    private var _result: Any?
    
    /// Promise's rejection reason, if the promise is rejected
    private var _reason: Any?
    
    /// Queue of HandlerFunctions to be executed on fulfillment
    private var onSuccessQueue: Queue<HandlerFunction>
    
    /// Queue of HandlerFunctions to be executed on rejection
    private var onFailureQueue: Queue<HandlerFunction>
    
    /// Executor function of this promise
    private var executor: ExecutorFunction?
    
    /** 
    Returns promise's result when ```Promise.state == .Fulfilled```
    
    **Note:** this value might be a ```NSNull```
    */
    public var result: Any {
        get {
            return unwrap(_result)
        }
    }
    
    /**
    Returns promise's rejection reason when ```Promise.state == .Rejected```
    
    **Note:** this value might be a ```NSNull```
    */
    public var reason: Any {
        get {
            return unwrap(_reason)
        }
    }

    //
    // MARK: - initializers
    //
    
    /**
    Initializes empty promise with no executor function
    - Parameter state: A state the promise is in (see: ```Promise.state```)
    */
    private init(state: State) {
        self._state = state
        self.onSuccessQueue = Queue<HandlerFunction>()
        self.onFailureQueue = Queue<HandlerFunction>()
    }
    
    /**
    Initializes a Promise and starts execution of the executor function
    - Parameter executor: a function with two arguments which is capable of resolving this promise
        (see: ```Promise.ExecutorFunction```)
    */
    public convenience init(executor: ExecutorFunction) {
        self.init(state: .Pending)
        self.executor = executor
        
        self.startExecution()
    }
    
    //
    // MARK: - public
    //
    
    /**
    Appends fulfillment and rejection handlers to the promise, and returns a new promise which
    is to be resolved after execution of either handler, depending of promise's resolution state.
    - Parameter onSuccess: Function to be executed when this promise is fulfilled. Is optional.
    - Parameter onFailure: Function to be executed when this promise is rejected. Is optional.
    
    - Returns: A new promise.
    */
    public func then(onSuccess: HandlerFunction? = nil, onFailure: HandlerFunction? = nil) -> Promise {
        let newPromise = Promise(state: .Pending)
        
        switch _state {
        
        case .Pending:
            
            if let onSuccess = onSuccess {
                self.enqueueHandler(onSuccess, withPromise: newPromise, toQueue: onSuccessQueue)
            }
            else {
                self.enqueueHandler({ newPromise.fulfill($0) }, withPromise: newPromise, toQueue: onSuccessQueue)
            }
            
            if let onFailure = onFailure {
                self.enqueueHandler(onFailure, withPromise: newPromise, toQueue: onFailureQueue)
            }
            else {
                self.enqueueHandler({ newPromise.reject($0) }, withPromise: newPromise, toQueue: onFailureQueue)
            }
            
        case .Fulfilled:
            
            if let onSuccess = onSuccess {
                self.handleResult(self.result, withHandler: onSuccess, andPromise: newPromise)
            }
            else {
                newPromise.fulfill(unwrap(_result))
            }
            
        case .Rejected:
            
            if let onFailure = onFailure {
                self.handleResult(self.reason, withHandler: onFailure, andPromise: newPromise)
            }
            else {
                newPromise.reject(unwrap(_reason))
            }
            
        }
        
        return newPromise
    }
    
    /**
    Appends a fulfillment handler callback to the promise, and returns a new promise. 
    
    Basically calls ```Promise.then(onSuccess, onFailure: nil)```
    
    - Parameter onSuccess: Function to be executed when this promise is fulfilled.
    
    - Returns: A new promise in the same fashion as a ```then()``` call.
    */
    public func success(onSuccess: HandlerFunction) -> Promise {
        return self.then(onSuccess)
    }
    
    /**
    Appends a rejection handler callback to the promise, and returns a new promise
    
    Basically calls ```Promise.then(nil, onFailure: onFailure)```
    
    - Parameter onFailure: Function to be executed when this promise is rejected.
    
    - Returns: A new promise in the same fashion as a ```then()``` call.
    */
    public func failure(onFailure: HandlerFunction) -> Promise {
        return self.then(nil, onFailure: onFailure)
    }
    
    //
    // MARK: - class methods
    //
    
    /**
    Returns a Promise object that is rejected with the given reason.
    - Parameter reason: A value which will be set as rejection reason.
    
    - Returns: A rejected promise.
    */
    public class func reject(reason: Any?) -> Promise {
        let promise = Promise(state: .Rejected)
        promise._reason = reason
        
        return promise
    }
    
    /** 
    Returns either a new promise resolved with the passed argument,
    or the argument itself if the argument is a promise.
    - Parameter result: A value which will be set as promise's fulfillment result. 
        If ```result``` is a promise, this is the value that will be returned.
    - Returns: A fulfilled promise.
    */
    public class func fulfill(result: Any?) -> Promise {
        if let promise = result as? Promise {
            return promise
        }
        else {
            let promise = Promise(state: .Fulfilled)
            promise._result = result
            
            return promise
        }
    }
    
    /**
    Returns a promise that is fulfilled or rejected as soon as one of the promises in the array
    is fulfilled or rejected, with the value or reason from that promise.
    - Parameter promises: An array of ```Promise``` objects
    - Returns: A promise, which will be resolved as soon as any of ```promises``` is resolved.
    */
    public class func race(promises: [Promise]) -> Promise {
        return Promise {
            fulfill, reject in
            
            var done: Bool = false
            
            for promise in promises {
                promise.success {
                    result in
                    if (!done) {
                        synchronized(self, closure: {
                            done = true
                            fulfill(result)
                        })
                    }
                    return result
                }
                
                promise.failure {
                    reason in
                    if (!done) {
                        synchronized(self, closure: {
                            done = true
                            reject(reason)
                        })
                    }
                    return reason
                }
                
            }
        }
    }
    
    /**
    Returns a promise that resolves when all of the promises in the array argument have resolved.
    This is useful for aggregating results of multiple promises together.
    - Parameter promises: An array of ```Promise``` objects
    - Returns: A promise which will be resolved as soon as all of ```promises``` are resolved. 
        This promise's result will be an array of results and rejection reasons.
    */
    public class func all(promises: [Promise]) -> Promise {
        return Promise {
            fulfill, reject in
            
            var finishLineCount = 0
            var finishLine = Array<Any>(count: promises.count, repeatedValue: "")
            
            for (i, promise) in promises.enumerate() {
                promise.success {
                    p in
                    synchronized(finishLineCount) {
                        finishLine[i] = p
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            fulfill(finishLine)
                        }
                    }
                }
                
                promise.failure {
                    p in
                    synchronized(finishLineCount) {
                        finishLine[i] = p
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            fulfill(finishLine)
                        }
                    }
                }
            }
        }
    }
    
    //
    // MARK: - internal
    //
    
    /**
    This function is passed as the first argument to the executor function. It should be
    called as soon as this promise is fulfilled. 
    - Parameter result: A result passed by the executor function. If this is a promise, wait for it to
        resolve before resolving this promise.
    */
    private func fulfill(result: Any) {
        
        // If result is also a *promise*, append handlers which will resolve ```self```
        // as soon as result resolves.
        if let promise = result as? Promise {
            promise.then({
                result in
                self.fulfill(result)
            }, onFailure: {
                reason in
                self.reject(reason)
            })
        }
        else {
            self._result = result
            self._state = .Fulfilled
        }
    }
    
    /**
    This function is passed as the second argument to the executor function. It should be
    called as soon as this promise is rejected.
    - Parameter reason: A rejection reason passed by the executor function.
    */
    private func reject(reason: Any) {
        // If result is also a *promise*, append handlers which will resolve ```self```
        // as soon as result resolves.
        if let promise = result as? Promise {
            promise.then({
                result in
                self.fulfill(result)
            }, onFailure: {
                reason in
                self.reject(reason)
            })
        }
        else {
            self._reason = reason
            self._state = .Rejected
        }
    }
    
    //
    // MARK: - private methods
    //
    
    /**
    Start execution of promise's executor. If executor throws, reject this promise with
    thrown error.
    */
    private func startExecution() {
        let queuePriority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        
        //todo: refactor using nsoperationqueue to allow cancelling of the operations
        dispatch_async(dispatch_get_global_queue(queuePriority, 0)) {
            do {
                try self.executor?(self.fulfill, self.reject)
            }
            catch let error {
                self.reject(error)
            }
        }
    }
    
    /**
    React on promise's state changes - call respective handlers
    
    This is called when ```Promise.state``` is changed (from ```Promise.state.didSet```)
    
    - Parameter state: promise's new state.
    */
    private func stateChanged(state: State) {
        switch state {
        case .Fulfilled:
            self.executeAll(self.onSuccessQueue, withResolution: self.result)
        case .Rejected:
            self.executeAll(self.onFailureQueue, withResolution: self.reason)
        case .Pending:
            fatalError("Promise has changed its state to .Pending. This is unexpected behaviour - breaking execution.")
        }
    }
    
    /**
    Called from ```then()```
    
    Attach promise's resolution handler to it's queue. This handler will be wrapped 
    with the logic which allows for resolving a promise that is a return value of ```then()```.
    
    - Parameter handler: A handler function to be attached.
    - Parameter withPromise: A promise that will be returned by ```then()``` and will be
        resolved after this promise resolves.
    - Parameter toQueue: A queue to attach the handler to. Either ```Promise.onSuccessQueue``` or
        ```Promise.onFailureQueue```
    */
    private func enqueueHandler(handler: HandlerFunction, withPromise promise: Promise, toQueue queue: Queue<HandlerFunction>) {
        queue.push({
            (value) in
            do {
                // wrap the handler so that it fulfills the promise returned from ```then()```
                let result = try handler(value)
                promise.fulfill(result)
                return result
            }
            catch let error {
                // wrap the handler so that it rejects the promise returned from ```then()```
                promise.reject(error)
                throw error
            }
        })
    }
    
    /**
    Called from ```then()```
    
    This method is called only after this promise is resolved. It enqueues a resolution handler to be executed. 
    The handler will also be wrapped in logic which ensures that promise returned by ```then()``` will be resolved
    - Parameter result: Resolution result, either a ```Promise.result``` or ```Promise.reason```
    - Parameter handler: A handler to be enqueued
    - Parameter promise: The promise to be returned from ```then()``` call that will be resolved after the 
        scheduled handler finishes.
    */
    private func handleResult(result: Any, withHandler handler: HandlerFunction, andPromise promise: Promise) {
        do {
            promise.fulfill(try handler(result))
        }
        catch let error {
            promise.reject(error)
        }
    }
    
    /**
    Execute all closures in a queue. Called after a promise is resolved. 
    
    - Parameter queue: A queue which contains the actions to be executed
    - Parameter withResolution: A resolution value to be passed to each action, either
        a ```Promise.result``` or ```Promise.reason```
    */
    private func executeAll(queue: Queue<HandlerFunction>, withResolution resolution: Any) {
        while !queue.isEmpty() {
            let action : HandlerFunction = queue.pop()!
            
            dispatch_async(dispatch_get_main_queue()) {
                do {
                    // ignore the value
                    try action(resolution)
                }
                catch _ {
                    // inore the error
                }
            }
        }
    }
}

/**
Schedules asynchronous work to be done and returns a promise of the result.
- Parameter work: a closure than returns a value and may throw an exception

- Returns: a promise of the return value of the ```work``` parameter
*/
public func async(work: () throws -> Any) -> Promise {
    return Promise {
        fulfill, reject in
        let result = try work()
        fulfill(result)
    }
}

/// Synchronizes closure
///
/// [see this](http://stackoverflow.com/questions/24045895/what-is-the-swift-equivalent-to-objective-cs-synchronized/24103086#24103086)
internal func synchronized(lock: AnyObject, closure: () throws -> Void) {
    objc_sync_enter(lock)
    try! closure()
    objc_sync_exit(lock)
}

/// Unwraps optional Any-values using reflection
///
/// [see this](http://stackoverflow.com/questions/27989094/how-to-unwrap-an-optional-value-from-any-type/32516815#32516815)
internal func unwrap(any: Any) -> Any {
    let mi = Mirror(reflecting: any)
    
    if mi.displayStyle != .Optional {
        return any
    }
    
    if mi.children.count == 0 { return NSNull() }
    let (_, some) = mi.children.first!
    return some
}
