# iPromise

![build](https://travis-ci.org/theddnc/iPromise.svg?branch=master)

A Promise represents a proxy for a value not necessarily known when the promise
is created. It allows to associate handlers to an asynchronous action's eventual
success value or failure reason. This lets asynchronous methods return values like 
synchronous methods: instead of the final value, the asynchronous method returns 
a promise of having a value at some point in the future.

iPromise's implementation of Promise class conforms to javascript specification. 

## Installation

Copy this line into your podfile:

```pod 'iPromise', '~> 0.1'```

Make sure to also add ```!use_frameworks```

## Examples

#### Simple async task

```swift
func computeAnswerToLifeTheUniverseAndEverything() -> Int { 
    // ... computing
    return 42
}

async {
    return computeAnswerToLifeTheUniverseAndEverything()
}.success { result in
    // 7.5 million years later

    if let answer = result as? Int {
        print("Ok, but what is \(answer) the answer to?")
    }

    return result
}
```

#### Catching failure 

```swift
enum Error: ErrorType {
    case FailureAndError
}


async {
    // computing, counting, multiplying
    return 0.5
}.success { result in
    if let computation = result as? Double where computation > 0.5 {
        print("This is quite a large number")
    }
    else {
        // we simply cannot accept a number this small!gi
        throw Error.FailureAndError
    }
    return result
}.sucess { result in
    // this won't be called
    return result
}.success { result in
    // this also won't be called
    return result
}.failure { error in
    // but this will
    if let error = error as? Error {
        print("Long computation has failed miserably")
    } 

    // let's recover
    return 0.6
}.success { result in
    if let computation = result as? Double where computation > 0.5 {

        // result is 0.6!
        print("This is quite a large number")
    }

    return result
}
```

## Docs

Documentation is available [here](http://cocoadocs.org/docsets/iPromise/0.1.0/), but
since it was generated from code comments you can also read the code, it's not that
much :)

## Licence

See ```LICENCE``` 