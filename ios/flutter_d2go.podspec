#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_d2go.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_d2go'
  s.version          = '0.6.1'
  s.summary          = 'Flutter Plugin inferring using d2go, the mobile model of detectron2.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/tsubauaaa/flutter_d2go'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'tsubasa1173@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.swift_version = '5.0'
  s.dependency "LibTorch", "~> 1.10.0"
  s.dependency "LibTorchvision", "0.10.0"
  s.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/LibTorch/install/include"' }

 end
