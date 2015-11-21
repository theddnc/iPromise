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

## Docs

Documentation is available [here](http://cocoadocs.org/docsets/iPromise/0.1.0/), but
since it was generated from code comments you can also read the code, it's not that
much :)

## Licence

See ```LICENCE``` 
