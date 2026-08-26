Pod::Spec.new do |s|
  s.name             = 'PPG_LiveActivities'
  s.version          = '4.4.1'
  s.summary          = 'PushPushGo Live Activities SDK for iOS.'

  # A more detailed description of the pod.
  s.description      = <<-DESC
                       The PushPushGo Live Activities SDK enables real-time activity tracking on the Lock Screen
                       and Dynamic Island. Includes pre-built templates (e.g., football match) and supports
                       custom templates. The pod links into apps from iOS 13.0; Live Activities themselves
                       require iOS 17.2 at runtime and report as unsupported below it.
                       DESC

  s.homepage         = 'https://pushpushgo.com/pl/'
  s.license          = 'MIT'
  s.authors          = { 'Adam' => 'adam@pushpushgo.com', 'Mateusz' => 'mateusz@pushpushgo.com' }
  
  s.platform         = :ios
  
  s.source = { :git => 'https://github.com/ppgco/ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.3'

  s.source_files = 'Sources/PPG_LiveActivities/**/*.{h,m,swift}'

  # Framework dependencies
  s.frameworks = 'ActivityKit', 'SwiftUI', 'WidgetKit', 'Foundation', 'CryptoKit'

end
