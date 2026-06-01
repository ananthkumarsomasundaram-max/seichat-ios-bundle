version_file = File.join(__dir__, 'VERSION')
unless File.exist?(version_file)
  raise "Missing VERSION file — run scripts/bump-version.sh or add VERSION before pod install"
end
version = File.read(version_file).strip

Pod::Spec.new do |s|
  s.name             = 'SeiChatSDK'
  s.version          = version
  s.summary          = 'Sei Chat iOS embed SDK (React Native 0.84)'
  s.description      = 'Embeddable Sei Chat: SeiChatSDK.swift + prebuilt main.jsbundle from UniversalClientMobile.'
  s.homepage         = 'https://github.com/ananthkumarsomasundaram-max/seichat-ios-bundle'
  s.license          = { :type => 'Proprietary', :text => 'Internal use only' }
  s.author           = { 'SEI Mobile Team' => 'mobile@sei.internal' }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.7'
  s.source           = {
    :git => 'https://github.com/ananthkumarsomasundaram-max/seichat-ios-bundle.git',
    :tag => "v#{version}",
  }

  s.source_files = 'Sources/SeiChatSDK/**/*.swift'
  # Keep in sync with scripts/ship-from-uc.sh REQUIRED_SHIP_ASSETS.
  s.resources = [
    'Shipped/ios/main.jsbundle',
    'Shipped/ios/assets/assets/images/strayer-logo.png',
    'Shipped/ios/assets/assets/images/strayer-wordmark.png',
  ]
  s.frameworks   = 'Foundation', 'UIKit'
  s.requires_arc = true

  s.dependency 'React-Core', '~> 0.84.0'
  s.dependency 'React-RCTAppDelegate', '~> 0.84.0'
  s.dependency 'ReactAppDependencyProvider', '~> 0.84.0'
end
