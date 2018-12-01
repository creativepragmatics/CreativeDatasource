Pod::Spec.new do |s|
  s.name             = 'CreativeDatasource'
  s.version          = '0.1.0'
  s.summary          = 'Datasources for iOS apps using ReactiveSwift'
  s.description      = <<-DESC
Lets you quickly hook up your predefined Models and various data 
streams (API, Cache, Geiger counter,...) into your ViewModel. 
Batteries included: UITableViewControllers that insert changes using
the amazing Dwifft library for animated updates. 
Built with a composition-over-inheritance and single-responsibility 
mindset. Will eventually be 100% unit tested. Pure Swift.
                       DESC
  s.homepage         = 'https://github.com/creativepragmatics/CreativeDatasource'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Maly @ Creative Pragmatics' => 'https://twitter.com/manuelmaly' }
  s.source           = { :git => 'https://github.com/creativepragmatics/CreativeDatasource.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/manuelmaly'

  s.ios.deployment_target = '9.0'
  s.swift_version = '4.2'
  s.source_files = 'CreativeDatasource/Classes/**/*'
  s.exclude_files = ['CreativeDatasource/Classes/TableView/**', 'CreativeDatasource/Classes/CachePersister/**']
  s.dependency 'ReactiveSwift', '~> 4.0.0'

  s.subspec 'CreativeDatasource-UITableView' do |uitv|
    uitv.source_files = 'CreativeDatasource/Classes/TableView/**/*'
    uitv.dependency 'Dwifft', '~> 0.9'
  end

  s.subspec 'CreativeDatasource-CachePersister' do |cache|
    cache.source_files = 'CreativeDatasource/Classes/CachePersister/**/*'
    cache.dependency 'Cache', '~> 5.2.0'
  end

end
