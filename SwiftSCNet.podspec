Pod::Spec.new do |s|
  s.name             = 'SwiftSCNet'
  s.version          = '0.2.5'
  s.summary          = 'Cross platform networking library.'

  s.description      = <<-DESC
Cross platform(iOS, Android, C) networking library.
                       DESC

  s.homepage         = 'https://github.com/dinobei/SwiftSCNet'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dinobei' => 'dinobei89@gmail.com' }
  s.source           = { :git => 'https://github.com/dinobei/SwiftSCNet.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = "10.10"

  s.source_files = 'SwiftSCNet/**/*'
  s.swift_version = '4'

  s.dependency 'SwiftProtobuf', '~> 1.1.0'
  s.dependency 'SwiftKcp', '~> 0.1.0'
  s.dependency 'SwiftSocket', '~> 2.0.5'
  
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }
end
