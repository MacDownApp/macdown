# Benchmarks

Budgets come from `docs/MODERNIZATION_PLAN.md` section 2. The tests live in
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

## Phase 2: cmark-gfm engine (current)

The tests moved to `MacDownTests/Swift/MarkdownPerformanceTests.swift` and now
use the cmark engine. Same machine and document shape as the baseline above.
Optimized numbers come from running the tests with
`SWIFT_OPTIMIZATION_LEVEL=-O GCC_OPTIMIZATION_LEVEL=3` added to the command
(a Debug build with optimization on, which is close to Release).

| Document size | Debug | Optimized | Plan budget |
|---|---|---|---|
| 10 KB | 4 ms | 1 ms | - |
| 100 KB | 17 ms | 6 ms | - |
| 1 MB | 136 ms | 36 ms | preview update < 500 ms |
| 1 MB, all extensions on (math, highlight, TOC, task list, ...) | 274 ms | 116 ms | < 500 ms |
| 5 MB | 652 ms | 165 ms | - |

Notes:
- In Debug the new engine is about 6 times slower than Hoedown was (136 ms
  against 22 ms at 1 MB). Hoedown is plain C; the new engine has Swift code
  that is slow without optimization. The old "3 times Hoedown" rule is
  replaced by the absolute budgets in the table: they hold with a wide margin.
  Hoedown was not measured in an optimized build before it was removed.
- All extensions on costs about 3 times more than the plain case. The extra
  time is the extension scanner and the regular expressions that run over the
  whole HTML (table of contents, task lists). Both can be made faster if a
  real document ever needs it.

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
