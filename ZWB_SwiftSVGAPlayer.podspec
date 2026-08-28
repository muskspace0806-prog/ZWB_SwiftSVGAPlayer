Pod::Spec.new do |s|
  s.name             = 'ZWB_SwiftSVGAPlayer'
  s.version          = '1.0.14'
  s.summary          = 'A Swift-based SVGA animation player for iOS 13+'
  s.description      = <<-DESC
    SwiftSVGAPlayer is a Swift-based implementation of an SVGA animation player.
    It supports iOS 13+, CocoaPods distribution, and provides a modern Swift API.
    No pbobjc. No GPBProtocolBuffers.
    Features: bitmap playback, dynamic image/text, loop control, seek, range playback,
    loading de-duplication, memory & disk cache, animated GIF/WebP dynamic image overlay.
  DESC

  s.homepage         = 'https://github.com/muskspace0806-prog/ZWB_SwiftSVGAPlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'owner' => 'owner@example.com' }
  s.source           = { :git => 'https://github.com/muskspace0806-prog/ZWB_SwiftSVGAPlayer.git', :tag => s.version.to_s }
  s.module_name      = 'SwiftSVGAPlayer'

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'

  s.source_files     = 'Sources/SwiftSVGAPlayer/**/*.swift'

  s.resource_bundles = {
    'ZWB_SwiftSVGAPlayer' => ['Sources/SwiftSVGAPlayer/PrivacyInfo.xcprivacy']
  }

  s.frameworks = 'UIKit', 'QuartzCore', 'CoreGraphics', 'Foundation',
                 'AVFoundation', 'ImageIO', 'CryptoKit'
  s.libraries  = 'compression'
  s.dependency 'Kingfisher', '~> 8.0'
  s.dependency 'KingfisherWebP', '~> 1.7'

  # SwiftProtobuf 依赖已移除：本库使用自研轻量 Protobuf 解析器
  # 如需 ZIPFoundation 可取消注释：
  # s.dependency 'ZIPFoundation', '~> 0.9'
end
