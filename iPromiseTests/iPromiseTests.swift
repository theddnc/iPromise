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
        
        XCTAssertEqual(promise.state, State.Fulfilled, "Promise should be fulfilled.")
        
        expect { testExpectation in
            promise.success { result in
                XCTAssertEqual(result, true, "Promise's result should be equal to true.")
                testExpectation.fulfill()
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run.")
            }
        }
    }
    
    func testReadmeTest() {
        enum Error: ErrorType {
            case FailureAndError
        }
        
        expect { testEx in
            async {
                return 0.5
            }.then({ result in
                if result > 0.5 {
                    print("This is quite a large number")
                }
                else {
                    throw Error.FailureAndError
                }
            }).then({ result in
                // this won't be called
            }).then({ result in
                // this won't be called
            }).failure({ (error) -> Double in
                // but this will
                switch error as! Error {
                case .FailureAndError:
                    print("Long computation has failed miserably :(")
                }
                
                // let's recover
                return 0.6
            }).then ({ result -> Double in
                if result > 0.5 {
                    print("This is quite a large number")
                    testEx.fulfill()
                }
                return 0.1
            })
        }
    }
    
    /**
    Tests promise rejection mechanisms
    */
    func testReject() {
        let promise = Promise<Any>.reject(PromiseError.NilReason)
        
        XCTAssertEqual(promise.state, State.Rejected, "Promise should be rejected.")
        
        expect { testExpectation in
            promise.failure { error in
                XCTAssert(error is PromiseError)
                testExpectation.fulfill()
            }
            
            promise.success { result in
                XCTFail("Success handler should not have run.")
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
            promise.success { result in
                XCTAssertEqual(result, true, "Promise's result should be equal to true")
                testExpectation.fulfill()
            }
            
            promise.failure { error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    /**
    Tests promise construction capabilities and state watchers
    */
    func testRejectFromExecutor() {
        let promise = Promise<Any> {
            fulfill, reject in
            reject(PromiseError.NilReason)
        }
        
        expect { testExpectation in
            promise.failure { error  in
                XCTAssert(error is PromiseError)
                testExpectation.fulfill()
            }
            
            promise.success { result in
                XCTFail("Sucess handler should not have run")
            }
        }
    }
    
    
    func testAsyncReturn() {
        expect { testExpectation in
            let promise = async {
                return true
            }
            
            promise.success { result in
                XCTAssertEqual(result, true, "Async result should be true")
                testExpectation.fulfill()
            }
            
            promise.failure { error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testAsyncThrow() {
        expect { testExpectation in
            let promise = async {
                throw Error.Error
            }
            
            promise.failure { reason in
                XCTAssertEqual(reason as? Error, Error.Error, "Async reason should be Error.Error")
                testExpectation.fulfill()
            }
            
            promise.success { result in
                XCTFail("Success handler should not have run")
            }
        }
    }
    
    func testRace() {
        let bigInt = 10000000
        let promises: [Promise<Int>] = self.promiseArray(bigInt)
        
        expect { testExpectation in
            let promise = Promise<Int>.race(promises)
            promise.success { result -> Int in
                XCTAssertEqual(result, bigInt, "First promise should finish sooner")
                testExpectation.fulfill()
                return result
            }
            
            promise.failure { error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testRaceFailure() {
        let promises: [Promise<Int>] = [
            Promise.reject(PromiseError.NilReason),
            Promise.reject(PromiseError.NilReason)
        ]
        
        expect { testExpectation in
            let promise = Promise<Int>.race(promises)
            promise.failure { error in
                if let error = error as? PromiseError {
                    switch error {
                    case .NilReason:
                        testExpectation.fulfill()
                    default:
                        XCTFail()
                    }
                }
                else {
                    XCTFail()
                }
            }
            
            promise.success { result in
                XCTFail("Success handler should not have run")
            }
        }
    }
    
    func testAllWithFailure() {
        let bigInt = 10000000
        let promises: [Promise<Int>] = self.promiseArray(bigInt, failing: true)
        
        expect { testExpectation in
            let promise = Promise<Any>.all(promises)
            promise.success { result in
                XCTAssertEqual(result[0].0, bigInt, "First promise should yield bigInt")
                XCTAssertEqual(result[1].0, 2*bigInt, "Second promise should yield 2*bigInt")
                XCTAssert(result[2].1 is PromiseError)
                testExpectation.fulfill()
            }
            
            promise.failure {
                error in
                XCTFail("Failure handler should not have run")
            }
        }
    }
    
    func testThrowingFromPromiseHandler() {
        expect { testExpectation in
            let promise = Promise<Bool> { fulfill, reject in
                for _ in 1...1000000 { continue }
                fulfill(true)
            }
            .success {
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
    
    func testChainFailure() {
        let successTask: () -> Promise<String> = { return Promise.fulfill("shortSuccess") }
        
        expect { testExpectation in
            successTask()
                .then({ result in
                    XCTAssertEqual(result, "shortSuccess")
                    throw PromiseError.NilReason
                })
                .then({ result in
                    XCTFail("Expected skip to failure handler")
                })
                .then({ result in
                    XCTFail("Expected skip to failure handler")
                    testExpectation.fulfill()
                })
                .failure({ error -> String in
                    XCTAssert(error is PromiseError)
                    
                    return "recovered"
                })
                .success({ result in
                    XCTAssertEqual(result, "recovered")
                    testExpectation.fulfill()
                })
        }
    }
    
    func testReturningPromiseFromSuccess() {
        expect { testExpectation in
            Promise { fulfill, reject in
                fulfill(10)
            }.then({ result in
                return Promise { fulfill, reject in
                    fulfill(100)
                }
            }).then({ result in
                XCTAssertEqual(result, 100)
                testExpectation.fulfill()
            })
        }
    }
    
    func testReturningPromiseFromFailure() {
        expect { testExpectation in
            Promise<Void>.reject(Error.Error).then(nil, onFailure: { error in
                return Promise { fulfill, reject in
                    fulfill(100)
                }
            }).then({ result in
                XCTAssertEqual(result, 100)
                testExpectation.fulfill()
            })
        }
    }
    
    private func promiseArray(bigInt: Int, failing: Bool = false) -> [Promise<Int>] {
        var promises: [Promise<Int>] = [
            Promise { fulfill, reject in
                var ret = 0
                for i in 1...bigInt {
                    ret = i
                }
                fulfill(ret)
            },
            Promise { fulfill, reject in
                var ret = 0
                for i in 1...bigInt*2 {
                    ret = i
                }
                fulfill(ret)
            }
        ]
        
        if failing {
            promises.append(Promise.reject(PromiseError.NilReason))
        }
        
        return promises
    }
    
    private func expect(testClosure: (XCTestExpectation) -> Void) -> Void {
        let testExpectation = expectationWithDescription("Test expectation")
        
        testClosure(testExpectation)
        
        waitForExpectationsWithTimeout(10, handler: {
            error in
            XCTAssertNil(error, "Error")
        })
    }
}
