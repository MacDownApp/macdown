#!/usr/bin/env ruby
# Adds a MacDownQuickLook Quick Look Preview Extension target to MacDown.xcodeproj.
# Idempotent: skips if a target with that name already exists.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MacDown.xcodeproj', __FILE__)
EXT_NAME     = 'MacDownQuickLook'
EXT_DIR      = File.expand_path("../../#{EXT_NAME}", __FILE__)
HOEDOWN_SRC  = File.expand_path('../../Pods/hoedown/src', __FILE__)
APP_TARGET   = 'MacDown'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == EXT_NAME }
  puts "Target #{EXT_NAME} already exists, nothing to do."
  exit 0
end

# Create the appex target.
target = project.new_target(
  :app_extension,
  EXT_NAME,
  :osx,
  '10.13',
  project.products_group,
  :objc
)

# Create a project group for the extension's source files.
ext_group = project.main_group.new_group(EXT_NAME, EXT_NAME)

ext_objc_files = %w[PreviewViewController.h PreviewViewController.m]
ext_objc_files.each do |fname|
  ref = ext_group.new_reference(fname)
  if fname.end_with?('.m')
    target.add_file_references([ref])
  end
end

# Hoedown sources, vendored from Pods/hoedown.
hoedown_group = ext_group.new_group('hoedown', HOEDOWN_SRC)
hoedown_sources = %w[
  autolink.c buffer.c document.c escape.c html.c
  html_blocks.c html_smartypants.c stack.c version.c
]
hoedown_sources.each do |fname|
  ref = hoedown_group.new_reference(File.join(HOEDOWN_SRC, fname))
  target.add_file_references([ref])
end

# Frameworks.
frameworks_group = project.frameworks_group
%w[Cocoa.framework Quartz.framework WebKit.framework].each do |fw|
  fw_ref = frameworks_group.files.find { |f| f.path && f.path.end_with?(fw) }
  fw_ref ||= frameworks_group.new_reference("System/Library/Frameworks/#{fw}", :sdk_root)
  target.frameworks_build_phase.add_file_reference(fw_ref)
end

# Build settings for the new target.
target.build_configurations.each do |config|
  bs = config.build_settings
  bs['INFOPLIST_FILE']                  = "#{EXT_NAME}/Info.plist"
  bs['PRODUCT_BUNDLE_IDENTIFIER']       = 'com.uranusjr.macdown.QuickLook'
  bs['PRODUCT_NAME']                    = '$(TARGET_NAME)'
  bs['CODE_SIGN_ENTITLEMENTS']          = "#{EXT_NAME}/#{EXT_NAME}.entitlements"
  bs['CODE_SIGN_STYLE']                 = 'Automatic'
  bs['CODE_SIGN_IDENTITY']              = '-'
  bs['MACOSX_DEPLOYMENT_TARGET']        = '10.13'
  bs['SKIP_INSTALL']                    = 'YES'
  bs['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
  bs['CLANG_ENABLE_OBJC_ARC']           = 'YES'
  bs['ENABLE_HARDENED_RUNTIME']         = 'YES'
  bs['HEADER_SEARCH_PATHS']             = ['$(inherited)', '$(SRCROOT)/Pods/hoedown/src']
  bs['LD_RUNPATH_SEARCH_PATHS']         = ['$(inherited)', '@executable_path/../Frameworks', '@executable_path/../../../../Frameworks']
  bs['GCC_PREPROCESSOR_DEFINITIONS']    = ['$(inherited)', 'HOEDOWN_USE_FILE_API=0']
  bs['ASSETCATALOG_COMPILER_APPICON_NAME'] = ''
end

# Find the main MacDown app target and embed the extension in it.
app = project.targets.find { |t| t.name == APP_TARGET }
raise "Could not find #{APP_TARGET} target" unless app

# Add target dependency.
app.add_dependency(target)

# Add an "Embed App Extensions" copy files build phase if one doesn't exist.
embed_phase = app.copy_files_build_phases.find do |bp|
  bp.symbol_dst_subfolder_spec == :plug_ins
end
unless embed_phase
  embed_phase = app.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  embed_phase.dst_path = ''
end

product_ref = target.product_reference
unless embed_phase.files_references.include?(product_ref)
  build_file = embed_phase.add_file_reference(product_ref)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save
puts "Added #{EXT_NAME} target and embedded into #{APP_TARGET}."
