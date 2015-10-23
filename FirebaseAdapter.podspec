Pod::Spec.new do |s|
  s.name         = "FirebaseAdapter"
  s.version      = "0.3.0"
  s.summary      = "."
  s.homepage     = "https://github.com/spf2/FirebaseAdapter"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Steve Farrell" => "sfarrell@gmail.com" }
  s.social_media_url = "https://twitter.com/spf2"
  s.source       = { :git => "https://github.com/spf2/FirebaseAdapter.git", :tag => 'v0.3.0' }
  s.source_files = "FirebaseAdapter/**/*"
  s.dependency  "Firebase", "~> 2.3"
  s.platform = :ios
  s.ios.deployment_target = "8.0"
  s.libraries = "c++", "icucore"
  s.ios.framework = "UIKit", "Firebase", "Security", "CFNetwork", "SystemConfiguration"
  s.xcconfig     = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/Firebase"' }
  s.requires_arc = true
end
