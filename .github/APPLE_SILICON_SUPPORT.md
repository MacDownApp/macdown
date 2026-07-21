# Apple Silicon Support

MacDown now has full support for Apple Silicon (ARM64) Macs running macOS 11 Big Sur and later.

## Architecture Support

The project is built and tested on **two architectures**:

- **Apple Silicon (ARM64)**: Built on macOS 14 (latest Apple Silicon runner)
- **Intel (x86_64)**: Built on macOS 12 (Intel runner)

## Build Configuration

### Podfile
The `Podfile` includes a `post_install` hook that ensures all CocoaPods dependencies support both architectures:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
      config.build_settings['VALID_ARCHS'] = 'x86_64 arm64'
    end
  end
end
```

### CI/CD Build Process

Both `.github/workflows/build.yml` and `.github/workflows/release.yml` use a matrix strategy to build for both architectures:

- Each architecture gets its own dedicated macOS runner
- `ARCHS` flag is explicitly set during xcodebuild to target the specific architecture
- Separate build products and artifacts are created for each architecture

## Releases

When you create a release (via `git tag v1.0.0`), the CI/CD pipeline automatically:

1. Builds for both ARM64 and x86_64
2. Creates separate DMG files for each architecture:
   - `MacDown-v1.0.0-arm64.dmg` (Apple Silicon)
   - `MacDown-v1.0.0-x86_64.dmg` (Intel)
3. Publishes both DMGs to the GitHub release

Users can download the version appropriate for their Mac:
- **Apple Silicon Mac**: Use `arm64` version
- **Intel Mac**: Use `x86_64` version

## Local Development

### Building for Apple Silicon (on Apple Silicon Mac)
```bash
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  ARCHS=arm64 \
  build
```

### Building for Intel (on Apple Silicon Mac with Rosetta)
```bash
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  ARCHS=x86_64 \
  build
```

### Building for Both (Universal Binary)
```bash
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  ARCHS='arm64 x86_64' \
  build
```

## CocoaPods Compatibility

All CocoaPods dependencies used in MacDown support Apple Silicon:

- handlebars-objc
- hoedown
- JJPluralForm
- LibYAML
- M13OrderedDictionary
- MASPreferences
- Sparkle
- PAPreferences
- GBCli (macdown-cmd target)

If you need to add new dependencies, ensure they support ARM64 architecture before adding to the Podfile.

## Testing

Both architectures are tested in CI/CD:

```bash
# Tests run on both macOS 14 (Apple Silicon) and macOS 12 (Intel)
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Debug \
  test
```

## Troubleshooting

### Pod Install Fails for ARM64

If you encounter pod install issues on Apple Silicon, try:

```bash
# Clear pods and reinstall
rm -rf Pods
rm Podfile.lock
pod install
```

### Build Fails with "Architecture Mismatch"

Ensure you're using the correct `ARCHS` setting and that all dependencies are properly installed via CocoaPods.

### Rosetta 2 Builds on Apple Silicon

If building for x86_64 on Apple Silicon via Rosetta 2:

```bash
# Use arch command to run in x86_64 mode
arch -x86_64 /usr/bin/ruby -I/usr/local/lib/ruby/gems/3.0.0 /usr/local/bin/pod install
```

## Future Improvements

- Consider creating universal binaries (both arm64 + x86_64 in one DMG) for simplified distribution
- Monitor minimum macOS deployment target for potential modernization
- Keep CocoaPods dependencies updated for optimal ARM64 support
