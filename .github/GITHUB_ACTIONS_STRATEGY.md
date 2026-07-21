# GitHub Actions Build Strategy

This document explains the optimized GitHub Actions workflows for MacDown.

## Overview

MacDown uses a **focused build strategy** optimized for Apple Silicon:
- ✅ Fast feedback during development (Apple Silicon only)
- ✅ Comprehensive releases with native Apple Silicon support
- ✅ Resource efficiency (Apple Silicon ARM64 only)
- ✅ Support for modern Macs (M1/M2/M3 and newer)

## Build Matrix Strategy

```
Push Event
│
└─ Apple Silicon (arm64)  ✅ Builds
   ├─ Runner: macos-14
   ├─ Speed: 5-10 minutes
   └─ Feedback: Fast (ideal for development)

Pull Request
│
└─ Apple Silicon (arm64)  ✅ Builds
   ├─ Runner: macos-14
   └─ Speed: 5-10 minutes

Release Tag (v*.*.*)
│
└─ Apple Silicon (arm64)  ✅ Builds & Releases
   ├─ Runner: macos-14
   ├─ Speed: 10-15 minutes
   ├─ Creates: MacDown-v1.0.0-arm64.dmg
   └─ Ready for M1/M2/M3 users
```

## Scenario Examples

### Scenario 1: Daily Development (Push to branch)

```
$ git push origin feature/new-feature
```

**Workflow runs:**
- ✅ Build for Apple Silicon (arm64)
  - Runner: macos-14
  - Completes in ~5-10 minutes
  - Fast feedback on whether your changes break things

**Best for:** Quick iteration, early feedback

### Scenario 2: Code Review (Pull Request)

```
$ gh pr create
```

**Workflow runs:**
- ✅ Build for Apple Silicon (arm64)
  - Runner: macos-14
  - Completes in ~5-10 minutes
  - Run tests and validate changes

**Best for:** Quality assurance, code review

### Scenario 3: Release (Create Tag)

```
$ git tag v1.0.0
$ git push origin v1.0.0
```

**Workflow runs:**
- ✅ Build Apple Silicon
  - Runner: macos-14
  - Creates: MacDown-v1.0.0-arm64.dmg
  - Completes in ~10-15 minutes
- ✅ Create GitHub release with DMG
  - Ready for all Apple Silicon Mac users (M1/M2/M3/Ultra)

**Result:** Users can download native Apple Silicon version

**Best for:** Production releases with native performance

## Build Time Comparison

```
Scenario                     Build Time    Wait Time
─────────────────────────────────────────────────────
Push (Apple Silicon)         5-10 min      2-5 min
                             ────────      ─────────
                             Total: 7-15 min

PR (Apple Silicon)           5-10 min      2-5 min
                             ─────────     ─────────
                             Total: 7-15 min

Release (Apple Silicon)      10-15 min     2-5 min
                             ──────────    ─────────
                             Total: 12-20 min
```

## Workflow Configuration

### build.yml (Push & PR)

```yaml
on:
  push:
    branches: [ master, main, develop ]
  pull_request:
    branches: [ master, main, develop ]
  workflow_dispatch:  # Manual trigger

jobs:
  build-apple-silicon:
    timeout-minutes: 60
    runs-on: macos-14
    name: "Build Apple Silicon"
    # Apple Silicon only, no conditionals needed
```

### release.yml (Tags)

```yaml
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-apple-silicon:
    timeout-minutes: 90
    runs-on: macos-14
    name: "Release - Apple Silicon"
    # Apple Silicon only native release
```

## Features

### Caching

Both workflows use CocoaPods caching:

```yaml
- name: Cache CocoaPods
  uses: actions/cache@v3
  with:
    path: Pods
    key: ${{ runner.os }}-pods-${{ hashFiles('**/Podfile.lock') }}
```

**Cache behavior:**
- ✅ **Hit**: Pods unchanged → <1 min installation
- ❌ **Miss**: Podfile.lock changed → 5-10 min installation
- 🔄 **Expires**: After 7 days of no activity

### Concurrency

Pull builds (not releases):

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Behavior:**
- ✅ New push cancels old builds on same branch
- ✅ Saves time and resources
- ✅ Doesn't cancel release builds

### Timeout Protection

```yaml
timeout-minutes: 60   # Build jobs
timeout-minutes: 90   # Release jobs
```

Prevents jobs from hanging indefinitely.

## Resource Impact

### Current (Apple Silicon only)
- 1 runner per push × 7-15 min = 7-15 min total
- Fast feedback on modern Macs
- ~15 min total per push for developer
- Reduced CI/CD costs
- Native performance for all users

**Benefit: Optimized for Apple Silicon Macs (M1/M2/M3 generation and newer)**

## When Each Workflow Runs

| Event | Build.yml | Release.yml | Effect |
|-------|-----------|-------------|--------|
| `git push` | ✅ ARM64 | — | Quick feedback |
| Pull Request | ✅ ARM64 | — | Validation |
| `git tag v*` | — | ✅ ARM64 | Create release |
| Manual trigger | ✅ ARM64 | — | On-demand build |

## Troubleshooting

### "Why is only Apple Silicon built?"

✅ **By design** - MacDown is optimized for Apple Silicon Macs (M1/M2/M3 and newer).

**Key benefits:**
- Native performance on modern Macs
- Faster build times
- Efficient CI/CD resource usage
- No "Skipped" job confusion

### "My Mac is Intel"

Intel Macs reach end of support in newer macOS versions. MacDown targets current-generation Macs.

**Alternatives:**
- Use an older version of MacDown built for Intel
- Update to Apple Silicon Mac for better performance
- Build locally: `xcodebuild -workspace MacDown.xcworkspace -scheme MacDown build`

### "Why is my push build so fast?"

✅ **Apple Silicon only!** Takes 5-10 minutes instead of 20-30 for multiple architectures.

**Benefits:**
- Faster feedback during development
- Modern Mac hardware optimizations
- Clean workflow with no skipped jobs

## Best Practices

1. **Development**: Push to your feature branch → Fast ARM64 build (5-10 min)
2. **Code Review**: Create PR → Validation on ARM64
3. **Release**: Create tag (v*.*.* format) → Auto-build and release native DMG
4. **Local Testing**: Test on Apple Silicon Mac before pushing for best results

## Monitoring Builds

### View Build Status

1. Go to: **Actions tab**
2. Select workflow (Build or Release)
3. See status of each run

### Download Artifacts

During builds:
- Build artifacts available in PR (if enabled)
- All artifacts available in release

### Check Runner Info

Each step shows:
```
Building: Apple Silicon (arm64)
Runner: macos-14
Event: push
```

## Future Optimizations

Possible future improvements:
- [ ] Cache Xcode build artifacts
- [ ] Parallel test execution
- [ ] Build time trending
- [ ] Automatic performance reports
- [ ] Conditional builds based on changed files

## References

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Conditional Workflows](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idif)
- [Caching Best Practices](https://docs.github.com/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [macOS Runners](https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
