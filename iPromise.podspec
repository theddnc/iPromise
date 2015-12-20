Pod::Spec.new do |s|

  s.name         = "iPromise"
  s.version      = "1.1.0"
  s.summary      = "Javascript promises implemented in Swift 2"

  s.description  = <<-DESC
            "A Promise represents a proxy for a value not necessarily known when the promise is created.
            It allows to associate handlers to an asynchronous action's eventual success value or failure
            reason. This lets asynchronous methods return values like synchronous methods: instead of the
            final value, the asynchronous method returns a promise of having a value at some point in the
            future."
                   DESC

  s.homepage     = "https://github.com/theddnc/iPromise"
  s.license      = "MIT"
  s.author             = { "Jakub Zaczek" => "zaczekjakub@gmail.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/theddnc/iPromise.git", :tag => "1.1.0" }
  s.source_files  = "iPromise/*"
  s.framework = 'XCTest'

end
