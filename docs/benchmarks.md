# Benchmarks

Budgets come from `MODERNIZATION_PLAN.md` section 2. The tests live in
`MacDownTests/MPPerformanceTests.m` and run with the normal test command.
Each test records timings with XCTest `measure` and also asserts a generous
hard limit, so a large regression fails the build.

Run only the benchmarks:

```
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -destination 'platform=macOS' \
  test -only-testing:MacDownTests/MPPerformanceTests CODE_SIGNING_ALLOWED=NO
```

Signposts: the Markdown engine emits an `os_signpost` interval named `render`
(subsystem `app.macdown`, category `markdown`). Open Instruments > Points of
Interest or the os_signpost instrument to see them.

## Baseline: Hoedown engine (before Phase 2)

Recorded 2026-11-23 on Apple M3 Pro, 18 GB RAM, macOS 27, Debug build, Xcode 27.2.
Synthetic document (headings, paragraphs with inline markup, lists, a table,
a fenced code block), Markdown to body HTML, warm run, average of 10 runs.

| Document size | Average | Hard limit in test | Plan budget |
|---|---|---|---|
| 10 KB | 1.6 ms | 50 ms | - |
| 100 KB | 2 to 5 ms | 100 ms | - |
| 1 MB | 18 ms | 500 ms | preview update < 500 ms |
| 5 MB | 93 ms | 2,500 ms | - |

Rule for Phase 2: the replacement parser must stay within about 3 times these
numbers. Debug builds are slower than Release; compare Debug with Debug.

## Not yet measured

These need code that does not exist yet. Each phase must add its benchmark
when it adds the feature.

| Metric | Budget | Added in |
|---|---|---|
| Keystroke to screen at 1 MB | < 16 ms | Phase 3 (editor) |
| Preview update after typing stops | < 100 ms normal, < 500 ms at 1 MB | Phase 4 (preview) |
| Cold launch to editable window | < 0.5 s | Phase 4 |
| Open a 5,000-file folder | sidebar < 200 ms | Phase 9 |
| Idle CPU | about 0 % | Phase 4 |
| Memory with one document | < 150 MB | Phase 4 |
