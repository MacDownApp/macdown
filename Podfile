# Uncomment this line to define a global platform for your project
platform :osx, "10.8"

source 'https://github.com/MacDownApp/cocoapods-specs.git'
source 'https://github.com/CocoaPods/Specs.git'

project 'MacDown.xcodeproj'

target "MacDown" do
  pod 'handlebars-objc', '~> 1.4'
  pod 'hoedown', '~> 3.0.7'
  pod 'JJPluralForm', '~> 2.1'      # Plural form localization.
  pod 'LibYAML', '~> 0.1', :inhibit_warnings => true
  pod 'M13OrderedDictionary', '~> 1.1'
  pod 'MASPreferences', '~> 1.1.3'  # Preference window.
  pod 'PAPreferences', '~> 0.4'     # Preference singleton (Locked until we drop 10.8 support).
  pod 'Sparkle', '~> 1.13'          # Updater.
end

target "MacDownTests" do
  pod 'PAPreferences', '~> 0.4'
end

target "macdown-cmd" do
  pod 'GBCli', '~> 1.1'
end
