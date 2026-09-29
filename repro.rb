# Minimal repro (CocoaPods 1.17, xcodeproj 1.28): objects created in a Podfile `post_install` (as React Native's
# scripts/cocoapods/spm.rb does for `spm_dependency`) can reuse UUIDs already in the Pods project.
#
# `Installer#stabilize_target_uuids` (installer.rb:332) runs on every install — unlike `predictabilize_uuids`, which
# React Native turns off (`deterministic_uuids => false`) — and its generator inherits `UUIDGenerator#generate!`,
# which ends with `@generated_uuids = @available_uuids` (uuid_generator.rb:23): the counter behind
# `Pod::Project#generate_available_uuid_list` forgets every UUID it handed out. Only targets are renumbered, so every
# other object keeps its sequential UUID — the project root keeps the very first one.
require 'cocoapods'
require 'tmpdir'

def install(objects_before)
  dir = Dir.mktmpdir
  project = Pod::Project.new(File.join(dir, 'Pods.xcodeproj'))
  objects_before.times { |i| project.new_file("f#{i}.m") }          # the pods' own objects
  spare = project.instance_variable_get(:@available_uuids).size
  Pod::Installer::TargetUUIDGenerator.new([project]).generate!       # installer.rb:332
  existing = project.objects.map(&:uuid).to_set
  # Podfile post_install → react_native_post_install → spm.rb add_spm_to_target (3 objects per package):
  pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = 'https://github.com/clerk/clerk-ios.git'
  project.root_object.package_references << pkg
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg
  dep.product_name = 'ClerkKit'
  file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  file.product_ref = dep
  reused = [pkg, dep, file].select { |o| existing.include?(o.uuid) }.map { |o| "#{o.isa} #{o.uuid}" }
  project.save
  lost_root = !File.read(File.join(dir, 'Pods.xcodeproj', 'project.pbxproj')).include?('isa = PBXProject;')
  [spare, project.root_object.uuid, reused, lost_root]
end

(0..4).each do |want|
  n = 0
  n += 1 until install(n)[0] == want
  spare, root, reused, lost_root = install(n)
  puts "spare UUIDs before post_install: #{spare} | root #{root} | reused: #{reused.empty? ? 'none' : reused.join(', ')} | PBXProject lost: #{lost_root}"
end
