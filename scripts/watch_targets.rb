# watch_targets.rb
# Famlist – legt die watchOS-Targets an und gleicht die geteilten Quelldateien ab.
#
# Aufruf (idempotent, beliebig oft):   ruby scripts/watch_targets.rb
#
# - FamlistWatch       watchOS-App (ein Target), eingebettet in die iOS-App („Embed Watch Content“)
# - FamlistWatchTests  Unit-Tests der Watch-App
# - Geteilte Dateien:  scripts/watch_shared_sources.txt – dieselben Dateien wie im iOS-Target
#                      (Target-Mitgliedschaft statt Kopie, design-handoff/WATCH_PLAN.md §2).
# Die Widget-Erweiterung folgt in Phase 6 (sie braucht die Widget-Views als Einstieg).
#
# Benötigt das Gem xcodeproj (1.23.0 auf diesem Mac vorhanden).

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Famlist.xcodeproj')
SHARED_LIST = File.join(__dir__, 'watch_shared_sources.txt')

TEAM = 'YHSZ8G8RWJ'
WATCH_NAME = 'FamlistWatch'
TESTS_NAME = 'FamlistWatchTests'
WATCH_BUNDLE_ID = 'com.roxo.famlist.watchkitapp'
DEPLOYMENT = '10.0'

project = Xcodeproj::Project.open(PROJECT_PATH)
ios = project.targets.find { |t| t.name == 'Famlist' } or abort('iOS-Target Famlist fehlt')

# Zuerst prüfen, ob alle geteilten Dateien schon im Projekt stehen – sonst nichts verändern.
wanted = File.readlines(SHARED_LIST).map(&:strip).reject { |l| l.empty? || l.start_with?('#') }
missing = wanted.reject { |rel| project.files.any? { |f| f.real_path.to_s == File.join(ROOT, rel) } }
abort("Nicht im Projekt (zuerst scripts/add_files.rb Famlist …):\n  #{missing.join("\n  ")}") unless missing.empty?

# ---------------------------------------------------------------- Hilfen

def common_watch_settings(config)
  s = config.build_settings
  s['SDKROOT'] = 'watchos'
  s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['WATCHOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  s['SWIFT_VERSION'] = '6.0'
  s['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s.delete('IPHONEOS_DEPLOYMENT_TARGET')
end

def group_for(project, relative_dir)
  relative_dir.split('/').reduce(project.main_group) do |parent, name|
    parent.children.find { |c| c.display_name == name && c.isa == 'PBXGroup' } ||
      parent.new_group(name, name)
  end
end

# Fügt alle Dateien eines Ordners (rekursiv) dem Target hinzu; Swift → Sources, Rest → Resources.
def add_folder(project, target, relative_dir)
  Dir.glob(File.join(ROOT, relative_dir, '**', '*')).sort.each do |path|
    next if File.directory?(path) && !path.end_with?('.xcassets')
    next if path.include?('.xcassets/')
    next if path.end_with?('Info.plist', '.entitlements')
    rel = path.sub("#{ROOT}/", '')
    group = group_for(project, File.dirname(rel))
    ref = group.files.find { |f| f.real_path.to_s == path } || group.new_reference(File.basename(rel))
    phase = rel.end_with?('.swift') ? target.source_build_phase : target.resources_build_phase
    phase.add_file_reference(ref, true)
  end
end

def file_ref(project, relative_path)
  path = File.join(ROOT, relative_path)
  project.files.find { |f| f.real_path.to_s == path }
end

# ---------------------------------------------------------------- Watch-App

watch = project.targets.find { |t| t.name == WATCH_NAME }
unless watch
  watch = project.new_target(:application, WATCH_NAME, :watchos, DEPLOYMENT)
  watch.build_configurations.each do |config|
    common_watch_settings(config)
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = WATCH_BUNDLE_ID
    s['INFOPLIST_FILE'] = 'FamlistWatch/Info.plist'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['INFOPLIST_KEY_CFBundleDisplayName'] = 'Famlist'
    s['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'com.roxo.famlist'
    s['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'
    s['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown'
    s['CODE_SIGN_ENTITLEMENTS'] = 'FamlistWatch/FamlistWatch.entitlements'
    s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
    s['ENABLE_PREVIEWS'] = 'YES'
    s['SKIP_INSTALL'] = 'YES'
    s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  end
  add_folder(project, watch, 'FamlistWatch')

  # supabase-swift (bereits als Paket im Projekt) auch für die Uhr.
  package = project.root_object.package_references.find { |p| p.repositoryURL.to_s.include?('supabase-swift') }
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = package
  dep.product_name = 'Supabase'
  watch.package_product_dependencies << dep
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  watch.frameworks_build_phase.files << build_file

  # Schriften wie im iOS-Target (dieselben Dateien).
  %w[Famlist/Resources/Fonts/Outfit-Variable.ttf Famlist/Resources/Fonts/DMSans-Variable.ttf].each do |font|
    ref = file_ref(project, font) or abort("Schrift fehlt im Projekt: #{font}")
    watch.resources_build_phase.add_file_reference(ref, true)
  end

  # In die iOS-App einbetten.
  embed = ios.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' } ||
          ios.new_copy_files_build_phase('Embed Watch Content')
  embed.dst_subfolder_spec = '16'
  embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  embed.add_file_reference(watch.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  ios.add_dependency(watch)
  puts "Target #{WATCH_NAME} angelegt."
end

# ---------------------------------------------------------------- Watch-Tests

tests = project.targets.find { |t| t.name == TESTS_NAME }
unless tests
  tests = project.new_target(:unit_test_bundle, TESTS_NAME, :watchos, DEPLOYMENT)
  tests.build_configurations.each do |config|
    common_watch_settings(config)
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{WATCH_BUNDLE_ID}.tests"
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FamlistWatch.app/FamlistWatch'
    s['BUNDLE_LOADER'] = '$(TEST_HOST)'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  end
  tests.add_dependency(watch)
  add_folder(project, tests, 'FamlistWatchTests')
  puts "Target #{TESTS_NAME} angelegt."
end

# ---------------------------------------------------------------- Geteilte Quellen abgleichen

wanted_paths = wanted.map { |rel| File.join(ROOT, rel) }
wanted.each do |rel|
  ref = file_ref(project, rel) or abort("Datei nicht im Projekt: #{rel}")
  next if watch.source_build_phase.files_references.include?(ref)
  watch.source_build_phase.add_file_reference(ref, true)
  puts "  + #{rel}"
end
# Nicht mehr gelistete geteilte Dateien (außerhalb von FamlistWatch/) wieder entfernen.
watch.source_build_phase.files.dup.each do |bf|
  path = bf.file_ref&.real_path.to_s
  next if path.start_with?(File.join(ROOT, 'FamlistWatch/')) || wanted_paths.include?(path)
  watch.source_build_phase.remove_build_file(bf)
  puts "  - #{path.sub("#{ROOT}/", '')}"
end

project.save

# ---------------------------------------------------------------- Scheme FamlistWatch

scheme_path = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes', "#{WATCH_NAME}.xcscheme")
unless File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(watch, tests, launch_target: true)
  scheme.save_as(PROJECT_PATH, WATCH_NAME, true)
  puts "Scheme #{WATCH_NAME} angelegt."
end
puts 'Fertig.'
