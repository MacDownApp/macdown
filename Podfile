platform :osx, "10.8"

source 'https://github.com/MacDownApp/cocoapods-specs.git'  # Patched libraries.
source 'https://cdn.cocoapods.org/'

project 'MacDown.xcodeproj'

inhibit_all_warnings!

post_install do |installer|
  # Support both Intel and Apple Silicon architectures
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Ensure both x86_64 and arm64 are supported
      config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
      config.build_settings['VALID_ARCHS'] = 'x86_64 arm64'
    end
  end
end

target "MacDown" do
  pod 'handlebars-objc', '~> 1.4'
  pod 'hoedown', '~> 3.0.7', :inhibit_warnings => false
  pod 'JJPluralForm', '~> 2.1'
  pod 'LibYAML', '~> 0.1'
  pod 'M13OrderedDictionary', '~> 1.1'
  pod 'MASPreferences', '~> 1.3'
  # Sparkle disabled: 1.18 is x86_64 only, 2.x requires macOS 10.13+
  # TODO: Update deployment target or add arm64-compatible Sparkle build

  # Locked on 0.4.x until we drop 10.8.
  pod 'PAPreferences', '~> 0.4'
end

target "MacDownTests" do
  pod 'PAPreferences', '~> 0.4'
end

target "macdown-cmd" do
  pod 'GBCli', '~> 1.1'
end
