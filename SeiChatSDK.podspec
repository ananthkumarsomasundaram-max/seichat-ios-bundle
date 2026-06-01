Pod::Spec.new do |s|
  s.name             = 'SeiChatSDK'
  s.version          = '1.0.0'
  s.summary          = 'Sei Chat iOS embed SDK (RN 0.84)'
  s.description      = 'Embeddable Sei Chat: SeiChatSDK.swift + prebuilt main.jsbundle from UniversalClientMobile.'
  s.homepage         = 'https://github.com/ananthkumarsomasundaram-max/seichat-ios-bundle'
  s.license          = { :type => 'Proprietary', :text => 'Internal use only' }
  s.author           = { 'SEI Mobile Team' => 'mobile@sei.internal' }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'
  s.source           = {
    :git => 'https://github.com/ananthkumarsomasundaram-max/seichat-ios-bundle.git',
    :tag => s.version.to_s,
  }

  s.source_files     = 'Sources/SeiChatSDK/**/*.swift'
  s.resources        = [
    'Shipped/ios/main.jsbundle',
    'Shipped/ios/*.png',
    'Shipped/ios/*.jpg',
    'Shipped/ios/*.jpeg',
  ]
  s.requires_arc     = true

  s.dependency 'React-Core'
  s.dependency 'React-RCTAppDelegate'
  s.dependency 'ReactAppDependencyProvider'
end
