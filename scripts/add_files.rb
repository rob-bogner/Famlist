# add_files.rb
# Famlist – trägt neue Dateien in die pbxproj ein (Gruppe nach Ordner, Build-Phase nach Endung).
#
# Aufruf:  ruby scripts/add_files.rb <Target> <Pfad> [<Pfad> …]
# Beispiel: ruby scripts/add_files.rb Famlist Famlist/Core/Utils/ProductImageCodec+Encoding.swift
#
# Idempotent: Bereits eingetragene Dateien bleiben unverändert. Swift → Sources, sonst → Resources.
# Dateien, die auch die Watch-App braucht, gehören zusätzlich in scripts/watch_shared_sources.txt.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
target_name, *paths = ARGV
abort('Aufruf: ruby scripts/add_files.rb <Target> <Pfad> …') if target_name.nil? || paths.empty?

project = Xcodeproj::Project.open(File.join(ROOT, 'Famlist.xcodeproj'))
target = project.targets.find { |t| t.name == target_name } or abort("Target fehlt: #{target_name}")

# Sucht die Gruppe, deren Ordner zum Pfad passt; legt fehlende Untergruppen an.
def group_for(project, relative_dir)
  relative_dir.split('/').reduce(project.main_group) do |parent, name|
    parent.children.find { |c| c.isa == 'PBXGroup' && (c.path == name || c.display_name == name) } ||
      parent.new_group(name, name)
  end
end

paths.each do |rel|
  abs = File.join(ROOT, rel)
  abort("Datei fehlt: #{rel}") unless File.exist?(abs)
  ref = project.files.find { |f| f.real_path.to_s == abs }
  ref ||= group_for(project, File.dirname(rel)).new_reference(File.basename(rel))
  abort("Gruppe passt nicht zum Ordner: #{rel} → #{ref.real_path}") unless ref.real_path.to_s == abs
  phase = rel.end_with?('.swift') ? target.source_build_phase : target.resources_build_phase
  if phase.files_references.include?(ref)
    puts "  = #{rel}"
  else
    phase.add_file_reference(ref, true)
    puts "  + #{rel} → #{target_name}"
  end
end
project.save
