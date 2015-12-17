//
//  Promise.swift
//  iPromise
//
//  Created by jzaczek on 24.10.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import UIKit

/**
 Describes promise's state. Promise is resolved when it is either fulfilled or
 rejected.
 - **Pending**: not resolved - the promise's task has just started
 - **Fulfilled**: resolved with success - a *result* is available: ```Promise.result```
 - **Rejected**: resolved with failure - a *reason of rejection* is available: ```Promise.reason```
*/
public enum State {
    
    /// Promise's resolution is not known yet
    case Pending
    
    /// Promise is fulfilled, ```result``` is available
    case Fulfilled
    
    /// Promise is rejected, ```reason``` is available
    case Rejected
}

/**
 Contains Promise exceptions. 
 - **NilResult**: thrown when result is nil on fulfill
 - **NilReason**: thrown when reason is nil on reject
*/
public enum PromiseError: ErrorType {
    
    /// When promise is fulfilled, and a resolution handler gets a nil result, this
    /// error is thrown.
    case NilResult
    
    /// When promise is rejected, and a resolution handler gets a nil reason, this
    /// error is thrown.
    case NilReason
}

/**
 A Promise represents a proxy for a value not necessarily known when the promise
 is created. It allows to associate handlers to an asynchronous action's eventual
 success value or failure reason. This lets asynchronous methods return values like
 synchronous methods: instead of the final value, the asynchronous method returns
 a promise of having a value at some point in the future.
 
 iPromise ```Promise```s are implemented using generics. This means that type safety
 is ensured.


**TODO**:
 - verify subclassing capabilities - perhaps it would be okay to create UrlPromise
    to use with Services
 - review comments
*/
public class Promise<T> {
    
    /**
     Closure with two arguments fulfill and reject. The first argument
     fulfills the promise, the second argument rejects it.
     
     If manually creating a promise, calling this arguments will fulfill
     or reject a promise.
    */
    public typealias ExecutorFunction = ((T)->Void, (ErrorType)->Void) throws -> Void
    
    //
    // MARK: - properties
    //
    
    /// Promise's internal state, described by ```Promise.State``` enum.
    private var _state: State {
        didSet {
            self.stateChanged(_state)
        }
    }
    
    /// Promise's state. Described by ```State``` enum.
    public var state: State {
        get {
            return _state
        }
    }
    
    /// Promise's result, if the promise is fulfilled
    private var _result: T?
    
    /// Promise's rejection reason, if the promise is rejected
    private var _reason: ErrorType?
    
    /// Queue of handler functions to be executed on fulfillment
    private var onSuccessQueue: Queue<(T) throws -> Any>
    
    /// Queue of handler functions to be executed on rejection
    private var onFailureQueue: Queue<(ErrorType) throws -> Any>
    
    /// Executor function of this promise
    private var executor: ExecutorFunction?
    
    /** 
    Returns promise's result when ```Promise.state == .Fulfilled```
    */
    public var result: T? {
        get {
            return _result
        }
    }
    
    /**
    Returns promise's rejection reason when ```Promise.state == .Rejected```
    */
    public var reason: ErrorType? {
        get {
            return _reason
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
        self.onSuccessQueue = Queue<(T) throws -> Any>()
        self.onFailureQueue = Queue<(ErrorType) throws -> Any>()
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
     Appends fulfillment and rejection handlers to the promise, and returns a new promise will be
     resolved after execution of either handler, depending of promise's resolution state.
    
     - Parameter onSuccess: Function to be executed when this promise is fulfilled. Is optional.
     - Parameter onFailure: Function to be executed when this promise is rejected. Is optional.
    
    - Returns: A new promise.
    */
    public func then<S>(onSuccess: ((T) throws -> S)? = nil, onFailure: ((ErrorType) throws -> S)? = nil) -> Promise<S> {
        let newPromise = Promise<S>(state: .Pending)
        
        switch _state {
        
        case .Pending:
            self.enqueueSuccess(onSuccess, withPromise: newPromise)
            self.enqueueFailure(onFailure, withPromise: newPromise)
            
        case .Fulfilled:
            self.handleSuccess(onSuccess, withPromise: newPromise)
            
        case .Rejected:
            self.handleFailure(onFailure, withPromise: newPromise)
            
        }
        return newPromise
    }
    
    /**
    Appends a fulfillment handler callback to the promise, and returns a new promise.
    Basically calls ```Promise.then(onSuccess, onFailure: nil)```
    
    - Parameter onSuccess: Function to be executed when this promise is fulfilled.
    
    - Returns: A new promise in the same fashion as a ```then()``` call.
    */
    public func success<S>(onSuccess: (T) throws -> S) -> Promise<S> {
        return self.then(onSuccess)
    }
    
    /**
    Appends a rejection handler callback to the promise, and returns a new promise
    Basically calls ```Promise.then(nil, onFailure: onFailure)```
    
    - Parameter onFailure: Function to be executed when this promise is rejected.
    
    - Returns: A new promise in the same fashion as a ```then()``` call.
    */
    public func failure<S>(onFailure: (ErrorType) throws -> S) -> Promise<S> {
        return self.then(nil, onFailure: onFailure)
    }
    
    //
    // MARK: - class methods
    //
    
    /**
    Returns a Promise object that is rejected with the given reason.
    - Parameter reason: A value (```ErrorType```) which will be set as rejection reason.
    
    - Returns: A rejected promise.
    */
    public class func reject(reason: ErrorType) -> Promise {
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
    public class func fulfill(result: T) -> Promise<T> {
        let promise = Promise(state: .Fulfilled)
        promise._result = result
        
        return promise
    }
    
    /**
    Returns a promise that is fulfilled or rejected as soon as one of the promises in the array
    is fulfilled or rejected, with the value or reason from that promise.
    - Parameter promises: An array of ```Promise``` objects
    - Returns: A promise, which will be resolved as soon as any of ```promises``` is resolved.
    */
    public class func race<S>(promises: [Promise<S>]) -> Promise<S> {
        return Promise<S> {
            fulfill, reject in
            
            var done: Bool = false
            
            for promise in promises {
                promise.success { (result: S) -> S in
                    if (!done) {
                        synchronized(self, closure: {
                            done = true
                            fulfill(result)
                        })
                    }
                    return result
                }
                
                promise.failure { (reason: ErrorType) -> ErrorType in
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
    public class func all<S>(promises: [Promise<S>]) -> Promise<[(S?, ErrorType?)]> {
        return Promise<[(S?, ErrorType?)]> {
            fulfill, reject in
            
            var finishLineCount = 0
            var finishLine = [(S?, ErrorType?)](count: promises.count, repeatedValue: (nil, nil))
            
            for (i, promise) in promises.enumerate() {
                promise.success { (p: S) in
                    synchronized(finishLineCount) {
                        finishLine[i] = (p, nil)
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            print(finishLine)
                            fulfill(finishLine)
                        }
                    }
                }
                
                promise.failure { (p: ErrorType) in
                    synchronized(finishLineCount) {
                        finishLine[i] = (nil, p)
                        finishLineCount++
                        
                        if (finishLineCount == promises.count) {
                            print(finishLine)
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
        else if result is T {
            self._result = result as? T
            self._state = .Fulfilled
        }
    }
    
    /**
    This function is passed as the second argument to the executor function. It should be
    called as soon as this promise is rejected.
    - Parameter reason: A rejection reason passed by the executor function.
    */
    private func reject(reason: ErrorType) {
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
                try self.executor?({ self.fulfill($0) }, self.reject)
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
            self.executeSuccess()
        case .Rejected:
            self.executeFailure()
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
    private func enqueueSuccess<S>(handler: ((T) throws -> S)?, withPromise promise:Promise<S>) {
        self.onSuccessQueue.push({ value in
            do {
                let result = try handler?(value)
                promise.fulfill(result)
                return result
            }
            catch let error {
                promise.reject(error)
                throw error
            }
        })
    }
    
    private func enqueueFailure<S>(handler: ((ErrorType) throws -> S)?, withPromise promise:Promise<S>) {
        self.onFailureQueue.push({ value in
            do {
                if let handler = handler {
                    let result = try handler(value)
                    promise.fulfill(result)
                    return result
                }
                else {
                    promise.reject(value)
                    throw value
                }
            }
            catch let error {
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
    private func handleSuccess<S>(handler: ((T) throws -> S)?, withPromise promise: Promise<S>) {
        do {
            if let result = self.result, handler = handler {
                promise.fulfill(try handler(result))
            }
            else if let result = self.result {
                promise.fulfill(result)
            }
            else {
                promise.reject(PromiseError.NilResult)
            }
        }
        catch let error {
            promise.reject(error)
        }
    }
    
    private func handleFailure<S>(handler: ((ErrorType) throws -> S)?, withPromise promise: Promise<S>) {
        do {
            if let reason = self.reason, handler = handler {
                promise.fulfill(try handler(reason))
            }
            else if let reason = self.reason {
                promise.reject(reason)
            }
            else {
                promise.reject(PromiseError.NilReason)
            }
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
    private func executeSuccess() {
        guard let result = self.result else {
            self.executeFailure()
            return
        }
        
        while !onSuccessQueue.isEmpty() {
            let action : (T) throws -> Any = onSuccessQueue.pop()!
            
            dispatch_async(dispatch_get_main_queue()) {
                do {
                    try action(result)
                    // ignore the value
                }
                catch _ {
                    // inore the error
                }
            }
        }
    }
    
    private func executeFailure() {
        guard let reason = self.reason else {
            self._reason = PromiseError.NilReason
            self.executeFailure()
            return
        }
        
        while !onFailureQueue.isEmpty() {
            let action : (ErrorType) throws -> Any = onFailureQueue.pop()!
            
            dispatch_async(dispatch_get_main_queue()) {
                do {
                    try action(reason)
                    // ignore the value
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
public func async<T>(work: () throws -> T) -> Promise<T> {
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