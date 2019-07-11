#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'fitpay_flutter_sdk'
  s.version          = '1.0.0'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
FitPay Flutter SDK iOS
                       DESC
  s.homepage         = 'http://www.fit-pay.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FitPay' => 'sdk@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '11.0'
  s.swift_version = '4.2'
  s.dependency 'SwCrypt'
end

