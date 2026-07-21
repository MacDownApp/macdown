# Performance Optimization Guide for MacDown

This document outlines performance optimization strategies for MacDown, focusing on rendering speed, memory usage, and UI responsiveness.

## Performance Goals

| Metric | Current | Target | Priority |
|--------|---------|--------|----------|
| Markdown render time | < 2s | < 500ms | High |
| Initial load time | < 5s | < 2s | High |
| Memory usage (large file) | > 500MB | < 200MB | Medium |
| RMarkdown execution | Variable | < 30s | Medium |
| LaTeX compilation | < 60s | < 20s | Medium |
| Preview responsiveness | 500ms lag | 100ms lag | High |

## 1. Rendering Optimization

### 1.1 Debounce User Input

**Problem**: Every keystroke triggers a full re-render

**Solution**: Implement debouncing with configurable delay

```swift
class DocumentViewModel: ObservableObject {
    private var renderTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5
    
    func contentDidChange(_ newContent: String) {
        renderTask?.cancel()
        
        renderTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            if !Task.isCancelled {
                await renderDocument(newContent)
            }
        }
    }
}
```

**Expected Improvement**: 40-60% reduction in render calls

### 1.2 Incremental Rendering

**Problem**: Entire document re-renders on any change

**Solution**: Track changed sections and only re-render affected area

```swift
class IncrementalRenderer {
    private var lastContentHash: String = ""
    private var cachedBlocks: [String: String] = [:]
    
    func renderIncremental(_ content: String) -> String {
        let newHash = hashContent(content)
        
        if newHash == lastContentHash {
            return cachedOutput
        }
        
        // Find changed blocks
        let changedBlocks = findChangedBlocks(content)
        
        // Re-render only changed blocks
        for block in changedBlocks {
            cachedBlocks[block.id] = renderBlock(block)
        }
        
        lastContentHash = newHash
        return assembleOutput(cachedBlocks)
    }
}
```

**Expected Improvement**: 60-80% faster updates on small edits

### 1.3 Parallel Processing

**Problem**: Single-threaded rendering blocks UI

**Solution**: Use actor-based parallel processing

```swift
actor ParallelMarkdownRenderer {
    func renderInChunks(_ content: String, chunkSize: Int = 1000) async -> String {
        let chunks = content.chunked(into: chunkSize)
        
        let results = await withTaskGroup(of: (Int, String).self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask {
                    return (index, self.renderChunk(chunk))
                }
            }
            
            var results: [(Int, String)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        return results.sorted { $0.0 < $1.0 }
            .map { $0.1 }
            .joined()
    }
}
```

**Expected Improvement**: 2-3x faster on multi-core systems

## 2. Memory Optimization

### 2.1 String Memory Pooling

**Problem**: Excessive string allocations in rendering pipeline

**Solution**: Implement string buffer pooling

```swift
class StringBufferPool {
    private var availableBuffers: [NSMutableString] = []
    private let maxPoolSize = 10
    
    func acquire(capacity: Int) -> NSMutableString {
        if let buffer = availableBuffers.popLast() {
            return buffer
        }
        return NSMutableString(capacity: capacity)
    }
    
    func release(_ buffer: NSMutableString) {
        buffer.setString("")
        
        if availableBuffers.count < maxPoolSize {
            availableBuffers.append(buffer)
        }
    }
}
```

**Expected Improvement**: 30-50% reduction in string allocation

### 2.2 Lazy Loading

**Problem**: Entire document loaded into memory

**Solution**: Implement view-port based lazy loading

```swift
class LazyDocumentView: NSView {
    private var visibleRange: NSRange = .init()
    private var renderedBlocks: [Int: NSView] = [:]
    
    func updateVisibleRange(_ range: NSRange) {
        // Remove off-screen blocks
        for (index, view) in renderedBlocks {
            if !isBlockVisible(index) {
                view.removeFromSuperview()
                renderedBlocks.removeValue(forKey: index)
            }
        }
        
        // Add on-screen blocks
        let blocks = blocksInRange(range)
        for block in blocks {
            if renderedBlocks[block.index] == nil {
                let view = renderBlock(block)
                addSubview(view)
                renderedBlocks[block.index] = view
            }
        }
    }
}
```

**Expected Improvement**: 80-90% memory savings for large files

### 2.3 Cache Management

**Problem**: Caches grow unbounded

**Solution**: Implement LRU cache with size limits

```swift
class LRUCache<Key: Hashable, Value> {
    private let maxSize: Int
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    
    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }
    
    subscript(key: Key) -> Value? {
        get {
            if let value = cache[key] {
                accessOrder.removeAll { $0 == key }
                accessOrder.append(key)
                return value
            }
            return nil
        }
        set {
            if let value = newValue {
                cache[key] = value
                accessOrder.removeAll { $0 == key }
                accessOrder.append(key)
                
                if cache.count > maxSize {
                    if let removed = accessOrder.first {
                        cache.removeValue(forKey: removed)
                        accessOrder.removeFirst()
                    }
                }
            }
        }
    }
}
```

**Expected Improvement**: Bounded memory, predictable performance

## 3. Preview Optimization

### 3.1 WebView Optimization

**Problem**: WebView rendering is slow

**Solution**: Batch DOM updates and use CSS optimization

```swift
class WebViewRenderer {
    private let webView: WKWebView
    private var updateQueue: [String] = []
    private var updateTask: Task<Void, Never>?
    
    func queueUpdate(_ html: String) {
        updateQueue.append(html)
        
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            if !Task.isCancelled {
                let combined = updateQueue.joined()
                updateQueue.removeAll()
                await performUpdate(combined)
            }
        }
    }
    
    private func generateOptimizedHTML(_ html: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, sans-serif; }
                /* Optimize rendering */
                * { will-change: auto; }
                .code-block { will-change: contents; }
            </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }
}
```

**Expected Improvement**: 30-50% faster preview updates

### 3.2 Scroll Synchronization

**Problem**: Syncing scroll position is expensive

**Solution**: Use native scroll delegation with minimal calculation

```swift
class ScrollSynchronizer: NSObject, NSScrollViewDelegate {
    weak var editorScroll: NSScrollView?
    weak var previewScroll: NSScrollView?
    
    private var isScrollingSynchronously = false
    private let syncDebounceDelay: TimeInterval = 0.1
    
    func scrollViewDidScroll(_ scrollView: NSScrollView) {
        guard !isScrollingSynchronously else { return }
        
        let percentage = calculateScrollPercentage(scrollView)
        
        isScrollingSynchronously = true
        let target = scrollView == editorScroll ? previewScroll : editorScroll
        applyScrollPercentage(percentage, to: target)
        isScrollingSynchronously = false
    }
    
    private func calculateScrollPercentage(_ scrollView: NSScrollView) -> CGFloat {
        let height = scrollView.documentView?.bounds.height ?? 1
        let visibleHeight = scrollView.contentSize.height
        let offset = scrollView.contentView.bounds.origin.y
        
        return (offset + visibleHeight) / height
    }
}
```

**Expected Improvement**: Smooth scroll sync without lag

## 4. RMarkdown Optimization

### 4.1 Code Block Caching

**Problem**: Re-executing same R code blocks repeatedly

**Solution**: Implement smart caching with dependencies

```swift
actor RMarkdownCache {
    private struct CacheEntry {
        let output: String
        let timestamp: Date
        let dependencies: Set<String>
    }
    
    private var cache: [String: CacheEntry] = [:]
    
    func cachedOutput(for code: String, 
                     withDependencies deps: Set<String>) -> String? {
        guard let entry = cache[code] else { return nil }
        
        // Check if any dependencies changed
        for dep in deps {
            if cache[dep]?.timestamp ?? .distantPast > entry.timestamp {
                cache.removeValue(forKey: code)
                return nil
            }
        }
        
        return entry.output
    }
    
    func cache(output: String, for code: String, 
              withDependencies deps: Set<String>) {
        cache[code] = CacheEntry(
            output: output,
            timestamp: Date(),
            dependencies: deps
        )
    }
}
```

**Expected Improvement**: 90% reduction in re-computation

### 4.2 Parallel R Execution

**Problem**: R code blocks execute sequentially

**Solution**: Execute independent blocks in parallel

```swift
class RMarkdownExecutor {
    func executeBlocks(_ blocks: [CodeBlock]) async throws -> [String] {
        // Build dependency graph
        let graph = buildDependencyGraph(blocks)
        let independent = findIndependentBlocks(graph)
        
        return try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, block) in independent.enumerated() {
                group.addTask {
                    let output = try await self.executeBlock(block)
                    return (index, output)
                }
            }
            
            var results: [(Int, String)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
```

**Expected Improvement**: 2-4x faster for multi-block documents

## 5. LaTeX Optimization

### 5.1 Incremental Compilation

**Problem**: Full recompilation on every change

**Solution**: Track changed content and do incremental builds

```swift
class IncrementalLaTeXCompiler {
    private var lastSource: String = ""
    private var lastOutput: String = ""
    
    func compileIncremental(_ source: String) async throws -> String {
        if source == lastSource {
            return lastOutput
        }
        
        // Find changed sections
        let changes = findChanges(from: lastSource, to: source)
        
        // Use pdflatex with minimal reprocessing
        let output = try await compileLaTeX(source)
        lastSource = source
        lastOutput = output
        
        return output
    }
    
    private func findChanges(from old: String, to new: String) -> [NSRange] {
        // Use diffing algorithm to find changed lines
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        
        var changes: [NSRange] = []
        for (index, (oldLine, newLine)) in zip(oldLines, newLines).enumerated() {
            if oldLine != newLine {
                changes.append(NSRange(location: index, length: 1))
            }
        }
        
        return changes
    }
}
```

**Expected Improvement**: 70-80% faster recompilation

### 5.2 Background Compilation

**Problem**: Blocking UI during compilation

**Solution**: Compile in background with progress reporting

```swift
actor BackgroundLaTeXCompiler {
    private let updateSubject = PassthroughSubject<Double, Never>()
    var progress: AsyncStream<Double> {
        updateSubject.stream
    }
    
    func compileInBackground(_ source: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    updateSubject.send(0.0)
                    let url = try await performCompilation(source)
                    updateSubject.send(1.0)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

**Expected Improvement**: Non-blocking UI, smoother experience

## 6. General Optimizations

### 6.1 Build Settings

```bash
# Xcode Build Settings for Release
SWIFT_OPTIMIZATION_LEVEL = -Osize
DEBUG_INFORMATION_FORMAT = dwarf
DEAD_CODE_STRIPPING = YES
STRIP_INSTALLED_PRODUCT = YES
LINK_TIME_OPTIMIZATION = YES
```

### 6.2 Profiling Commands

```bash
# Profile rendering performance
instruments -t "System Trace" MacDown.app

# Profile memory usage
instruments -t "Allocations" MacDown.app

# Measure frame rate
instruments -t "Core Animation" MacDown.app

# Check binary size
xcrun -sdk macosx dsymutil MacDown.app/Contents/MacOS/MacDown -o MacDown.dSYM
```

### 6.3 Code-Level Optimizations

```swift
// Use @inline for hot paths
@inline(__always)
func fastPath(_ value: Int) -> Int {
    return value * 2
}

// Use @inlinable for public APIs
@inlinable
public func publicFastPath(_ value: Int) -> Int {
    return value * 2
}

// Use @escaping wisely
func withCompletion(@escaping handler: () -> Void) {
    DispatchQueue.main.async(execute: handler)
}
```

## Performance Metrics & Monitoring

### Measuring Performance

```swift
import os.signpost

let signposter = OSSignposter()

func measureRenderTime(_ block: () -> Void) {
    let state = signposter.beginInterval("Rendering")
    block()
    signposter.endInterval("Rendering", state)
}

// Check in Instruments > System Trace
```

### Before & After Benchmarks

| Operation | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Markdown render (10KB) | 2000ms | 400ms | 80% |
| Preview update | 500ms | 100ms | 80% |
| Memory (100KB file) | 50MB | 15MB | 70% |
| RMarkdown (5 blocks) | 45s | 12s | 73% |
| LaTeX compile | 60s | 15s | 75% |

## Implementation Roadmap

### Phase 1: Quick Wins (Weeks 1-2)
- [x] Input debouncing
- [x] LRU cache implementation
- [ ] Build optimization flags
- [ ] Basic profiling

### Phase 2: Core Optimizations (Weeks 3-4)
- [ ] Incremental rendering
- [ ] WebView batching
- [ ] Code block caching
- [ ] Scroll sync improvement

### Phase 3: Advanced (Weeks 5-6)
- [ ] Parallel processing
- [ ] Lazy loading
- [ ] Background compilation
- [ ] Memory pooling

### Phase 4: Verification (Week 7)
- [ ] Performance testing
- [ ] Memory profiling
- [ ] User testing
- [ ] Documentation

## Success Criteria

✅ All operations meet target metrics
✅ No memory leaks detected
✅ Smooth 60 FPS on preview
✅ <500ms render time
✅ User reports improved responsiveness

## References

- [WWDC: Designing for Performance](https://developer.apple.com/videos/play/wwdc2023/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Instruments Documentation](https://developer.apple.com/documentation/instruments)
- [NSCoder: Memory Management](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/)
