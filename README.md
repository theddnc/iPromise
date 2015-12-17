# iPromise

[![build](https://travis-ci.org/theddnc/iPromise.svg?branch=master)](https://travis-ci.org/theddnc/iPromise)

A Promise represents a proxy for a value not necessarily known when the promise
is created. It allows to associate handlers to an asynchronous action's eventual
success value or failure reason. This lets asynchronous methods return values like 
synchronous methods: instead of the final value, the asynchronous method returns 
a promise of having a value at some point in the future.

iPromise's implementation of Promise class conforms to javascript specification. 

## Installation

Copy this line into your podfile:

```pod 'iPromise', '~> 0.2'```

Make sure to also add ```!use_frameworks```

## Examples

#### Simple async task

```swift
func computeAnswerToLifeTheUniverseAndEverything() -> Int {
    // ... computing
    return 42
}

async(computeAnswerToLifeTheUniverseAndEverything)
    .success { result in
        // 7.5 million years later
        print("Ok, but what is \(result) the answer to?")
    }   
```

#### Catching failure 

```swift
enum Error: ErrorType {
    case FailureAndError
}

async {
    return 0.5
}.then({ result in
    if result > 0.5 {
        print("This is quite a large number")
    }
    else {
        // we simply cannot accept a number this small!
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
    }
    return 0.1
})
```

## Docs

Documentation is available [here](http://cocoadocs.org/docsets/iPromise/0.1.0/), but
since it was generated from code comments you can also read the code, it's not that
much :)

## Licence

See ```LICENCE``` 
