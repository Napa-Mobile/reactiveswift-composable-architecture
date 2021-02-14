Pod::Spec.new do |s|
  # Version
  s.version          = "0.11.0"
  s.swift_version    = "5.2"

  # Meta
  s.name         = "ComposableArchitecture"
  s.summary      = "A Reactive Swift fork of The Composable Architecture"
  s.license      = "MIT"
  s.homepage     = 'https://github.com/trading-point/reactiveswift-composable-architecture'
  s.authors      = { 'SR' => 'user@name.com' }
  s.description  = <<-DESC
  Private Podspec
                   DESC

  # Compatibility & Sources
  s.source_files          = 'Sources/**/*.swift'
  s.ios.deployment_target = '11.0'
  s.source                = { :git => 'https://github.com/sroddy/reactiveswift-composable-architecture.git', :tag => s.version.to_s }
  s.dependency 'ReactiveSwift'
  s.dependency 'CasePaths'
end
