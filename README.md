# CocoaPods: objects created in a Podfile `post_install` can reuse existing UUIDs

`repro.rb` shows why `pod install` can write a `Pods.xcodeproj` that Xcode cannot open ("The project 'Pods' is
damaged") when a pod declares a Swift package through React Native's `spm_dependency`.

1. `Installer#stabilize_target_uuids` runs on every install. Through `Xcodeproj::Project::UUIDGenerator#generate!` it
   resets the sequential UUID counter behind `Pod::Project#generate_available_uuid_list` to the current batch's spare
   ids.
2. React Native's `scripts/cocoapods/spm.rb` then creates three objects per Swift package in the Podfile's
   `post_install`.
3. When fewer than three spare ids are left, those objects take UUIDs already in use. With 0 spare, the
   `XCRemoteSwiftPackageReference` takes the project root's UUID, and the `PBXProject` object is gone.

Run it with CocoaPods installed (Homebrew: `GEM_HOME=$(brew --prefix cocoapods)/libexec ruby repro.rb`, or
`ruby repro.rb` with the gem):

```
spare UUIDs before post_install: 0 | root 46EB2E00000000 | reused: XCRemoteSwiftPackageReference 46EB2E00000000, XCSwiftPackageProductDependency 46EB2E00000010, PBXBuildFile 46EB2E00000020 | PBXProject lost: true
spare UUIDs before post_install: 1 | root 46EB2E00000000 | reused: XCSwiftPackageProductDependency 46EB2E00000000, PBXBuildFile 46EB2E00000010 | PBXProject lost: true
spare UUIDs before post_install: 2 | root 46EB2E00000000 | reused: PBXBuildFile 46EB2E00000000 | PBXProject lost: false
spare UUIDs before post_install: 3 | root 46EB2E00000000 | reused: none | PBXProject lost: false
spare UUIDs before post_install: 4 | root 46EB2E00000000 | reused: none | PBXProject lost: false
```

Tested with CocoaPods 1.17.0 (xcodeproj 1.28.1), Ruby 4.0.
