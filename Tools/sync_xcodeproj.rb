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
  { url: 'https://github.com/swiftlang/swift-cmark', requirement: { kind: 'branch', branch: 'gfm' },
    products: { 'MacDown' => ['cmark-gfm', 'cmark-gfm-extensions'] } },
].freeze

# -- Build settings -----------------------------------------------------------
[app, tests].each do |t|
  t.build_configurations.each do |c|
    c.build_settings['SWIFT_VERSION'] = '5.0'
    c.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    c.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = (t == app ? 'MacDown/Code/MacDown-Bridging-Header.h' : 'MacDownTests/MacDownTests-Bridging-Header.h')
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

# -- Prune references to files that were deleted or renamed ---------------------
project.files.dup.each do |ref|
  path = ref.real_path.to_s
  next unless path.start_with?(ROOT) && !path.include?('/Pods/') && !File.exist?(path)
  [app, tests].each do |t|
    t.build_phases.each do |phase|
      next unless phase.respond_to?(:files)
      phase.files.dup.each { |bf| bf.remove_from_project if bf.file_ref == ref }
    end
  end
  puts "removed #{ref.path}"
  ref.remove_from_project
end

# -- Objective-C / C files in existing groups ----------------------------------
# New .h/.m/.c files placed in a directory that already has an Xcode group are
# added to that group (and .m/.c to the MacDown target).
swift_root = File.join(ROOT, 'MacDown/Code/Swift')
project.main_group.recursive_children_groups.each do |group|
  dir = group.real_path.to_s
  next unless dir.start_with?(File.join(ROOT, 'MacDown/Code')) && !dir.start_with?(swift_root)
  next unless Dir.exist?(dir)
  known = group.files.map { |f| f.real_path.to_s }
  Dir.children(dir).sort.each do |name|
    path = File.join(dir, name)
    next unless %w[.h .m .c].include?(File.extname(name)) && !known.include?(path)
    ref = group.new_reference(name)
    app.add_file_references([ref]) if %w[.m .c].include?(File.extname(name))
    puts "added #{name}"
  end
end

# Objective-C test files directly in MacDownTests/
tests_group = project.main_group.children.find { |c| c.display_name == 'MacDownTests' }
Dir.children(File.join(ROOT, 'MacDownTests')).sort.each do |name|
  next unless name.end_with?('.m') && tests_group.files.none? { |f| f.path == name }
  tests.add_file_references([tests_group.new_reference(name)])
  puts "added test #{name}"
end

# bridging header reference (for navigation only)
unless project.files.any? { |f| f.path == 'MacDown/Code/MacDown-Bridging-Header.h' }
  project.main_group.new_reference('MacDown/Code/MacDown-Bridging-Header.h')
end
unless project.files.any? { |f| f.path == 'MacDownTests/MacDownTests-Bridging-Header.h' }
  project.main_group.new_reference('MacDownTests/MacDownTests-Bridging-Header.h')
end

# -- Folder resources ---------------------------------------------------------
['MacDown/Resources/BuiltinThemes', 'MacDown/Resources/KaTeX', 'MacDown/Resources/Diagrams'].each do |folder|
  next if app.resources_build_phase.files_references.any? { |r| r && r.path == folder }
  ref = project.files.find { |f| f.path == folder } || project.main_group.new_reference(folder)
  ref.last_known_file_type = 'folder'
  app.resources_build_phase.add_file_reference(ref, true)
end

# Test fixtures (golden-file corpus)
['MacDownTests/Snapshots'].each do |folder|
  next if tests.resources_build_phase.files_references.any? { |r| r && r.path == folder }
  ref = project.files.find { |f| f.path == folder } || project.main_group.new_reference(folder)
  ref.last_known_file_type = 'folder'
  tests.resources_build_phase.add_file_reference(ref, true)
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
