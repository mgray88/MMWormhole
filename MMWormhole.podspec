Pod::Spec.new do |s|
  s.name     = 'MMWormhole'
  s.version  = '2.1.0'
  s.license  = 'MIT'
  s.summary  = 'Message passing between apps and extensions.'
  s.homepage = 'https://github.com/mutualmobile/MMWormhole'
  s.authors  = {
    'Conrad Stoll' => 'conrad.stoll@mutualmobile.com',
    'Mike Gray' => 'mgray88@gmail.com'
  }
  s.source   = { :git => 'https://github.com/mgray88/MMWormhole.git', :tag => s.version.to_s }
  s.requires_arc = true
  
  s.default_subspec = 'Core'

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  
  s.ios.frameworks = 'Foundation', 'WatchConnectivity'
  s.osx.frameworks = 'Foundation'
  s.watchos.frameworks = 'Foundation', 'WatchConnectivity'
  
  s.subspec 'Core' do |core|
    core.ios.source_files = 'Sources/MMWormhole/**/*.{h,m}', 'Sources/Wormhole/*.swift'
    core.watchos.source_files = 'Sources/MMWormhole/**/*.{h,m}', 'Source/Wormhole/*.swift'
    core.osx.source_files = 'Sources/MMWormhole/**/MMWormhole.{h,m}', 'Sources/MMWormhole/**/MMWormholeFileTransiting.{h,m}', 'Sources/MMWormhole/**/MMWormholeCoordinatedFileTransiting.{h,m}', 'Sources/MMWormhole/include/MMWormholeTransiting.h'
  end  
end
