Pod::Spec.new do |s|
  s.name = "MiniFuture"
  s.version = "0.1.0"
  s.license = {:type => "MIT", :file => "LICENSE.txt"}
  s.summary = "A Future design pattern implementation in Swift"
  s.homepage = "https://github.com/tkareine/MiniFuture"
  s.social_media_url = "http://twitter.com/tkareine"
  s.source = {:git => "https://github.com/tkareine/MiniFuture.git", :tag => s.version}
  s.authors = {"Tuomas Kareinen" => "tkareine@gmail.com"}

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.requires_arc = true

  s.source_files = "Source/**/*.swift"
end
