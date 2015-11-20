//
//  PromiseTests.swift
//  iPromiseTests
//
//  Created by jzaczek on 24.10.2015.
//  Copyright © 2015 jzaczek. All rights reserved.
//

import XCTest
@testable import iPromise

class PromiseTests: XCTestCase {
    
    enum Error: ErrorType {
        case Error
    }
    
    /**
    Tests promise fulfilling mechanisms
    */
    func testFulfill() {
        let promise = Promise.fulfill(true)
        
        XCTAssertEqual(promise.state, Promise.State.Fulfilled, "Promise should be fulfilled.")
        
        expect { testExpectation in
            promise.success {
                (result) in
                XCTAssertEqual(result as? Bool, true, "Promise's result should be equal to true.")
                testExpectation.fulfill()
                
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run.")
            }
        }
    }
    
    /**
    Tests promise rejection mechanisms
    */
    func testReject() {
        let promise = Promise.reject(false)
        
        XCTAssertEqual(promise.state, Promise.State.Rejected, "Promise should be rejected.")
        
        expect { testExpectation in
            promise.failure {
                (error) in
                XCTAssertEqual(error as? Bool, false, "Promise's rejection reason should be equal to false.")
                testExpectation.fulfill()

                return error
            }
            
            promise.success {
                result in
                XCTFail("Success handler should not have run.")
                return result
            }
        }
    }
    
    /**
    Tests promise construction capabilities and state watchers
    */
    func testFulfillFromExecutor() {
        let promise = Promise {
            fulfill, reject in
            fulfill(true)
        }
        
        expect { testExpectation in
            promise.success {
                result in
                XCTAssertEqual(result as? Bool, true, "Promise's result should be equal to true")
                testExpectation.fulfill()

                
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
                return error
            }
        }
    }
    
    /**
    Tests promise construction capabilities and state watchers
    */
    func testRejectFromExecutor() {
        let promise = Promise {
            fulfill, reject in
            reject(false)
        }
        
        expect { testExpectation in
            promise.failure {
                error in
                XCTAssertEqual(error as? Bool, false, "Promise's rejection reason should be equal to false")
                testExpectation.fulfill()
                
                return error
            }
            
            promise.success {
                result in
                XCTFail("Sucess handler should not have run")
                return result
            }
        }
    }
    
    /**
    Tests fulfilling promise with another promise
    */
    func testFulfillWithPromise() {
        let promise = Promise.fulfill(Promise.fulfill(true))

        XCTAssertEqual(promise.state, Promise.State.Fulfilled, "Promise should be fulfilled")
        
        expect { testExpectation in
            promise.success {
                result in
                XCTAssertEqual(result as? Bool, true, "Promise's result should be equal to true")
                testExpectation.fulfill()
                
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
                return error
            }
        }
    }
    
    /**
    Tests fulfilling with promise from executor function
    */
    func testFulfillWithPromiseFromExecutor() {
        let promise = Promise {
            fulfill, reject in
            fulfill(Promise.fulfill(true))
        }
        
        expect { testExpectation in
            promise.success {
                result in
                XCTAssertEqual(result as? Bool, true, "Promise's result should be equal to true")
                testExpectation.fulfill()
                
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
                return error
            }
        }
    }
    
    func testFulfillWithFailingPromiseFromExecutor() {
        let promise = Promise {
            fulfill, reject in
            fulfill(Promise.reject(false))
        }
        
        expect { testExpectation in
            promise.failure {
                error in
                XCTAssertEqual(error as? Bool, false, "Promise's rejection reason should be equal to false")
                testExpectation.fulfill()
                
                return error
            }
            
            promise.success {
                result in
                XCTFail("Success handler should not have run")
                return result
            }
        }
    }
    
    func testAsyncReturn() {
        expect { testExpectation in
            let promise = async {
                return true
            }
            
            promise.success {
                result in
                XCTAssertEqual(result as? Bool, true, "Async result should be true")
                testExpectation.fulfill()
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testAsyncThrow() {
        expect { testExpectation in
            let promise = async {
                throw Error.Error
            }
            
            promise.failure {
                reason in
                XCTAssertEqual(reason as? Error, Error.Error, "Async reason should be Error.Error")
                testExpectation.fulfill()
                return reason
            }
            
            promise.success {
                result in
                XCTFail("Success handler should not have run")
            }
        }
    }
    
    func testFulfillWithNilValue() {
        let promise = Promise.fulfill(nil)
        
        XCTAssertEqual(promise.state, Promise.State.Fulfilled, "Promise should be fulfilled.")
        
        expect { testExpectation in
            promise.success {
                (result) in
                XCTAssertEqual(result as? NSNull, NSNull(), "Result should be nsnull")
                testExpectation.fulfill()
                
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run.")
            }
        }
    }
    
    func testRace() {
        let bigInt = 10000000
        let promises: [Promise] = self.promiseArray(bigInt)
        
        expect { testExpectation in
            let promise = Promise.race(promises)
            promise.success {
                result in
                if let res = result as? Int {
                    XCTAssertEqual(res, bigInt, "First promise should finish sooner")
                    testExpectation.fulfill()
                }
                else {
                    XCTFail("Promise's result should be int")
                }
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testRaceFailure() {
        let bigInt = 10000000
        let promises: [Promise] = self.promiseArray(bigInt, failing: true)
        
        expect { testExpectation in
            let promise = Promise.race(promises)
            promise.failure {
                error in
                if let err = error as? Bool {
                    XCTAssertEqual(err, false, "This race should fail")
                    testExpectation.fulfill()
                }
                else {
                    XCTFail("Promise's rejection reason should be bool")
                }
                return error
            }
            
            promise.success {
                result in
                XCTFail("Success handler should not have run")
            }
        }
    }
    
    func testAllWithFailure() {
        let bigInt = 10000000
        let promises: [Promise] = self.promiseArray(bigInt, failing: true)
        
        expect { testExpectation in
            let promise = Promise.all(promises)
            promise.success {
                result in
                if let res = result as? [Any] {
                    XCTAssertEqual(res[0] as? Int, bigInt, "First promise should yield bigInt")
                    XCTAssertEqual(res[1] as? Int, 2*bigInt, "Second promise should yield 2*bigInt")
                    XCTAssertEqual(res[2] as? Bool, false, "Third promise should fail with 'false' as reason")
                    testExpectation.fulfill()
                }
                else {
                    XCTFail("Promise's result should be an array")
                }
                return result
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testThrowingFromPromiseHandler() {
        expect { testExpectation in
            let promise = Promise { fulfill, reject in
                for _ in 1...1000000 { continue }
                fulfill(true)
                }.success {
                    result in
                    throw Error.Error
            }
            
            promise.failure {
                error in
                XCTAssertEqual(error as? Error, Error.Error, "Promise's rejection reason should be Error.Error")
                promise.failure {
                    error in
                    XCTAssertEqual(error as? Error, Error.Error, "Promise's rejection reason should be Error.Error")
                    testExpectation.fulfill()
                    throw Error.Error
                }
                throw Error.Error
            }
        }
    }
    
    private func promiseArray(bigInt: Int, failing: Bool = false) -> [Promise] {
        var promises = [
            Promise {
                fulfill, reject in
                var ret = 0
                for i in 1...bigInt {
                    ret = i
                }
                fulfill(ret)
            },
            Promise {
                fulfill, reject in
                var ret = 0
                for i in 1...bigInt*2 {
                    ret = i
                }
                fulfill(ret)
            }
        ]
        
        if failing {
            promises.append(Promise.reject(false))
        }
        
        return promises
    }
    
    private func expect(testClosure: (XCTestExpectation) -> Void) -> Void {
        let testExpectation = expectationWithDescription("Test expectation")
        
        testClosure(testExpectation)
        
        waitForExpectationsWithTimeout(5, handler: {
            error in
            XCTAssertNil(error, "Error")
        })
    }
}
