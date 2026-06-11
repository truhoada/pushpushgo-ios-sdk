Pod::Spec.new do |s|
  s.name             = 'PPG_framework'
  s.version          = '4.3.0'
  s.summary          = 'PushPushGo SDK for iOS.'

  # A more detailed description of the pod.
  s.description      = <<-DESC
                       The PushPushGo SDK allows easy integration of push notification services for iOS applications.
                       DESC

  s.homepage         = 'https://pushpushgo.com/pl/'
  s.license          = 'MIT'
  s.authors          = { 'Adam' => 'adam@pushpushgo.com', 'Mateusz' => 'mateusz@pushpushgo.com' }
  
  s.platform         = :ios
  
  s.source = { :git => 'https://github.com/ppgco/ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.3'

  s.source_files = 'Sources/PPG_framework/**/*.{h,m,swift}'

end
