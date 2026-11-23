#!/usr/bin/env ruby
# Keeps MacDown.xcodeproj in sync with the Swift sources on disk.
#
#   ruby Tools/sync_xcodeproj.rb
#
# Idempotent. Adds every *.swift file under MacDown/Code/Swift to the MacDown
# target and every *.swift file under MacDownTests/Swift to MacDownTests.
# Also configures Swift build settings and the Swift packages listed below.
# Requires the `xcodeproj` gem (installed together with CocoaPods).
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'MacDown.xcodeproj'))
app = project.targets.find { |t| t.name == 'MacDown' }
tests = project.targets.find { |t| t.name == 'MacDownTests' }

PACKAGES = [
  { url: 'https://github.com/jpsim/Yams', requirement: { kind: 'upToNextMajorVersion', minimumVersion: '5.0.0' },
    products: { 'MacDown' => ['Yams'] } },
].freeze

# -- Build settings -----------------------------------------------------------
[app, tests].each do |t|
  t.build_configurations.each do |c|
    c.build_settings['SWIFT_VERSION'] = '5.0'
    c.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    c.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'MacDown/Code/MacDown-Bridging-Header.h' if t == app
    c.build_settings['ENABLE_TESTABILITY'] = 'YES' if c.name == 'Debug'
    c.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = (c.name == 'Debug' ? '-Onone' : '-O')
  end
end

# -- Source files -------------------------------------------------------------
def sync_dir(project, target, rel_root, group_name)
  abs_root = File.join(ROOT, rel_root)
  return unless Dir.exist?(abs_root)
  group = project.main_group[group_name] || project.main_group.new_group(group_name, rel_root, :project)
  existing = target.source_build_phase.files_references.compact.map { |r| r.real_path.to_s }

  walk = lambda do |dir, grp|
    Dir.children(dir).sort.each do |name|
      path = File.join(dir, name)
      if File.directory?(path)
        sub = grp[name] || grp.new_group(name, name)
        walk.call(path, sub)
      elsif name.end_with?('.swift') && !existing.include?(path)
        ref = grp.new_reference(name)
        target.add_file_references([ref])
      end
    end
  end
  walk.call(abs_root, group)
end

sync_dir(project, app, 'MacDown/Code/Swift', 'Swift')
sync_dir(project, tests, 'MacDownTests/Swift', 'SwiftTests')

# bridging header reference (for navigation only)
unless project.files.any? { |f| f.path == 'MacDown/Code/MacDown-Bridging-Header.h' }
  project.main_group.new_reference('MacDown/Code/MacDown-Bridging-Header.h')
end

# -- Folder resources ---------------------------------------------------------
['MacDown/Resources/BuiltinThemes'].each do |folder|
  next if app.resources_build_phase.files_references.any? { |r| r && r.path == folder }
  ref = project.files.find { |f| f.path == folder } || project.main_group.new_reference(folder)
  ref.last_known_file_type = 'folder'
  app.resources_build_phase.add_file_reference(ref, true)
end

# -- Swift packages -----------------------------------------------------------
PACKAGES.each do |pkg|
  ref = project.root_object.package_references.find { |r| r.repositoryURL == pkg[:url] }
  unless ref
    ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    ref.repositoryURL = pkg[:url]
    ref.requirement = pkg[:requirement]
    project.root_object.package_references << ref
  end
  pkg[:products].each do |target_name, products|
    target = project.targets.find { |t| t.name == target_name }
    products.each do |product|
      next if target.package_product_dependencies.any? { |d| d.product_name == product }
      dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      dep.product_name = product
      dep.package = ref
      target.package_product_dependencies << dep
      # Link
      bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      bf.product_ref = dep
      target.frameworks_build_phase.files << bf
    end
  end
end

project.save
puts 'MacDown.xcodeproj synced.'
