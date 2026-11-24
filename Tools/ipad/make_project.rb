#!/usr/bin/env ruby
# Generates Viewer/VaultViewer.xcodeproj: an iPad-only app that uses the ViewerCore package
# and bundles the shared KaTeX, Mermaid, Prism and theme files from the macOS app.
# Run again after adding or removing files in Viewer/App.   ruby Tools/ipad/make_project.rb
require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
VIEWER = File.join(ROOT, 'Viewer')
PROJECT_PATH = File.join(VIEWER, 'VaultViewer.xcodeproj')
BUNDLE_ID = ENV['BUNDLE_ID'] || 'local.vaultviewer'
TEAM = ENV['DEVELOPMENT_TEAM'] || ''

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
target = project.new_target(:application, 'VaultViewer', :ios, '16.0')
target.product_reference.name = 'VaultViewer.app'

# Sources
app_group = project.main_group.new_group('App', 'App', :group)
Dir.children(File.join(VIEWER, 'App')).sort.each do |name|
  next unless name.end_with?('.swift')
  target.add_file_references([app_group.new_reference(name)])
end
assets = app_group.new_reference('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets, true)

# Resources shared with the macOS app (referenced in place, not copied).
shared = project.main_group.new_group('Shared', nil, :group)
{ 'KaTeX' => '../MacDown/Resources/KaTeX',
  'Diagrams' => '../MacDown/Resources/Diagrams',
  'BuiltinThemes' => '../MacDown/Resources/BuiltinThemes',
  'components' => '../Dependency/prism/components' }.each do |name, path|
  ref = shared.new_reference(path)
  ref.name = name
  ref.last_known_file_type = 'folder'
  target.resources_build_phase.add_file_reference(ref, true)
end
autoloader = shared.new_reference('../Dependency/prism/plugins/autoloader/prism-autoloader.min.js')
autoloader.last_known_file_type = 'sourcecode.javascript'
target.resources_build_phase.add_file_reference(autoloader, true)

# Local package
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = '.'
project.root_object.package_references << package
dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dependency.product_name = 'ViewerCore'
target.package_product_dependencies << dependency
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = dependency
target.frameworks_build_phase.files << build_file

# Settings
[project.build_configurations, target.build_configurations].flatten.each do |config|
  s = config.build_settings
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  s['SDKROOT'] = 'iphoneos'
  s['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
end
target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = 'VaultViewer'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['TARGETED_DEVICE_FAMILY'] = '2'                 # iPad only
  s['SUPPORTS_MACCATALYST'] = 'NO'
  s['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'Vault Viewer'
  s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  s['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  s['INFOPLIST_KEY_ITSAppUsesNonExemptEncryption'] = 'NO'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
end
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH, 'VaultViewer', true)
puts "Wrote #{PROJECT_PATH} (bundle id #{BUNDLE_ID})"
