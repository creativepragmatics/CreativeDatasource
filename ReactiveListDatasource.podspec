Pod::Spec.new do |s|
  s.name             = 'ReactiveListDatasource'
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
  s.homepage         = 'https://github.com/creativepragmatics/ReactiveListDatasource'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Maly @ Creative Pragmatics' => 'https://twitter.com/manuelmaly' }
  s.source           = { :git => 'https://github.com/creativepragmatics/ReactiveListDatasource.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/manuelmaly'

  s.ios.deployment_target = '9.0'
  s.swift_version = '4.2'
  s.dependency 'ReactiveSwift', '~> 4.0.0'

  s.subspec 'Core' do |ss|
    ss.source_files = 'ReactiveListDatasource/Classes/Core/**/*'
  end

  s.subspec 'UITableView' do |ss|
    ss.source_files = 'ReactiveListDatasource/Classes/TableView/**/*'
    ss.dependency 'ReactiveListDatasource/Core'
    ss.dependency 'Dwifft', '~> 0.9'
  end

  s.subspec 'UITableView-Persisted' do |ss|
    ss.dependency 'ReactiveListDatasource/Core'
    ss.dependency 'ReactiveListDatasource/UITableView'
    ss.source_files = 'ReactiveListDatasource/Classes/TableView-Persisted/**/*'
  end

    s.subspec 'UICollectionView' do |ss|
    ss.source_files = 'ReactiveListDatasource/Classes/CollectionView/**/*'
    ss.dependency 'ReactiveListDatasource/Core'
    ss.dependency 'Dwifft', '~> 0.9'
  end

  s.subspec 'CachePersister' do |ss|
    ss.source_files = 'ReactiveListDatasource/Classes/CachePersister/**/*'
    ss.dependency 'ReactiveListDatasource/Core'
    ss.dependency 'Cache', '~> 5.2.0'
  end

end
