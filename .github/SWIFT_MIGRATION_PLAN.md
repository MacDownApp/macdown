# Swift Migration Plan for MacDown

This document outlines the strategy for migrating MacDown from Objective-C to Swift while maintaining stability and performance.

## Why Migrate to Swift?

### Benefits

1. **Safety**: Eliminating entire classes of bugs (null pointer, memory safety)
2. **Performance**: Swift optimizations and direct runtime access
3. **Maintainability**: Modern language features, cleaner syntax
4. **Type Safety**: Compiler-enforced type checking
5. **Concurrency**: Swift's async/await and structured concurrency
6. **Community**: Larger modern Swift ecosystem

### Timeline Considerations

- Phased migration (3-6 months)
- Objective-C and Swift interoperability during transition
- No feature freeze required
- Gradual rollout to users

## Migration Strategy

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Set up Swift infrastructure without changing existing code

1. **Add Swift Support to Project**
   ```bash
   # Add Bridging Header
   # Configure Swift Language Version in build settings
   # Ensure module name is set correctly
   ```

2. **Create Swift Package Structure**
   - `Sources/MacDownCore/` - Core logic (Renderer, Parsers)
   - `Sources/MacDownUI/` - UI components
   - `Sources/MacDownUtils/` - Utilities

3. **Set Up Testing**
   - Create Swift test targets
   - Maintain existing Objective-C tests
   - Create integration tests

### Phase 2: Utilities Layer (Weeks 2-3)

**Goal**: Migrate non-UI utility classes first

Migrate these classes to Swift:

1. **MPFileType** → `FileTypeDetector.swift`
   ```swift
   enum DocumentFileType {
       case markdown
       case rmarkdown
       case latex
   }
   
   class FileTypeHelper {
       static func detectType(from url: URL) -> DocumentFileType { ... }
       static func detectType(from extension: String) -> DocumentFileType { ... }
   }
   ```

2. **MPRCodeExecutor** → `RCodeExecutor.swift`
   ```swift
   actor RCodeExecutor {
       static let shared = RCodeExecutor()
       
       func execute(code: String, timeout: TimeInterval) async throws -> String {
           // Use Swift's async/await
       }
       
       func isRInstalled() -> Bool { ... }
   }
   ```

3. **MPLaTeXCompiler** → `LaTeXCompiler.swift`
   ```swift
   actor LaTeXCompiler {
       static let shared = LaTeXCompiler()
       
       func compile(texFile: URL, outputPDF: URL) async throws -> URL {
           // Async compilation
       }
       
       func isPdfLatexInstalled() -> Bool { ... }
   }
   ```

### Phase 3: Parser Layer (Weeks 3-4)

**Goal**: Migrate parsers with modern Swift patterns

1. **MPRMarkdownParser** → `RMarkdownParser.swift`
   ```swift
   struct CodeBlock {
       let code: String
       let language: String
       let options: [String: String]
       let range: NSRange
   }
   
   class RMarkdownParser {
       func parseCodeBlocks(from content: String) -> [CodeBlock] { ... }
       func isRCodeBlock(_ fenceInfo: String) -> Bool { ... }
   }
   ```

2. **MPLaTeXParser** → `LaTeXParser.swift`
   ```swift
   struct DocumentMetadata {
       let title: String?
       let author: String?
       let date: String?
   }
   
   class LaTeXParser {
       func parseMetadata(from content: String) -> DocumentMetadata { ... }
       func isStandalone(_ content: String) -> Bool { ... }
   }
   ```

### Phase 4: Renderer Layer (Weeks 4-6)

**Goal**: Create Swift wrappers around existing renderers, then replace Hoedown

1. **Create Swift Renderer Protocol**
   ```swift
   protocol DocumentRenderer {
       associatedtype Input
       associatedtype Output
       
       func render(_ input: Input) async throws -> Output
   }
   
   protocol RenderDataSource: AnyObject {
       var documentTitle: String { get }
       var documentContent: String { get }
   }
   
   protocol RenderDelegate: AnyObject {
       func renderer(_ renderer: DocumentRenderer, 
                    didProduceOutput: String)
       func rendererDidStartProcessing(_ renderer: DocumentRenderer)
       func rendererDidFinishProcessing(_ renderer: DocumentRenderer)
   }
   ```

2. **MarkdownRenderer.swift** (Wrap existing Hoedown)
   ```swift
   actor MarkdownRenderer: DocumentRenderer {
       weak var dataSource: RenderDataSource?
       weak var delegate: RenderDelegate?
       
       func render(_ input: String) async throws -> String {
           // Call Hoedown from C
           // Return HTML
       }
   }
   ```

3. **RMarkdownRenderer.swift** (Replace Objective-C version)
   ```swift
   actor RMarkdownRenderer: DocumentRenderer {
       let rExecutor = RCodeExecutor.shared
       let parser = RMarkdownParser()
       
       func render(_ input: String) async throws -> String {
           let blocks = parser.parseCodeBlocks(from: input)
           
           for block in blocks {
               let output = try await rExecutor.execute(code: block.code)
               // Process output
           }
           
           // Render markdown
       }
   }
   ```

4. **LaTeXRenderer.swift** (Replace Objective-C version)
   ```swift
   actor LaTeXRenderer: DocumentRenderer {
       let compiler = LaTeXCompiler.shared
       let parser = LaTeXParser()
       
       func render(_ input: String) async throws -> String {
           let metadata = parser.parseMetadata(from: input)
           let pdfURL = try await compiler.compile(input)
           return generateHTMLViewer(for: pdfURL)
       }
   }
   ```

### Phase 5: UI Layer (Weeks 6-10)

**Goal**: Create new SwiftUI components alongside existing AppKit code

1. **Create SwiftUI Document View**
   ```swift
   struct DocumentView: View {
       @StateObject var viewModel: DocumentViewModel
       @State var showPreview = true
       
       var body: some View {
           HSplitView {
               EditorView(text: $viewModel.content)
               
               if showPreview {
                   PreviewView(html: viewModel.renderedHTML)
               }
           }
       }
   }
   ```

2. **Create Modern Preferences UI** (SwiftUI)
   ```swift
   struct PreferencesView: View {
       @AppStorage("rmarkdownExecuteOnEdit") var executeOnEdit = true
       @AppStorage("latexCompileOnEdit") var compileOnEdit = true
       
       var body: some View {
           Form {
               Section("RMarkdown") {
                   Toggle("Execute on edit", isOn: $executeOnEdit)
               }
               Section("LaTeX") {
                   Toggle("Compile on edit", isOn: $compileOnEdit)
               }
           }
       }
   }
   ```

3. **Gradual Integration**
   - Use SwiftUI as overlays on existing AppKit
   - Implement new features in SwiftUI
   - Keep existing AppKit for stability
   - Plan full transition for v2.0

### Phase 6: Full Migration (Weeks 10+)

**Goal**: Complete transition, remove Objective-C code

1. **Replace MPDocument** → `DocumentController.swift`
2. **Replace MPEditorView** → Modern TextEditor
3. **Replace WebView integration** → SwiftUI WebKit wrapper
4. **Remove all Objective-C code**
5. **Optimize for Swift runtime**

## Swift Best Practices for MacDown

### 1. Use Modern Concurrency

❌ **Before (Callbacks)**
```objc
- (void)executeCode:(NSString *)code 
          completion:(void(^)(NSString *output, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(...), ^{
        // Execute
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(output, error);
        });
    });
}
```

✅ **After (Async/Await)**
```swift
func executeCode(_ code: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        // Execute on background thread
        Task {
            let result = try performExecution()
            return result
        }
    }
}
```

### 2. Use Structured Concurrency

```swift
// Multiple concurrent operations with cancellation support
async let rOutput = rExecutor.execute(code1)
async let laTeXOutput = compiler.compile(texFile)

let (r, latex) = try await (rOutput, laTeXOutput)
```

### 3. Use Value Types

```swift
// Prefer structs for data
struct CodeBlock {
    let code: String
    let language: String
    let options: [String: String]
}

struct DocumentMetadata {
    let title: String?
    let author: String?
}
```

### 4. Use Actors for Thread Safety

```swift
// Automatically thread-safe
actor RCodeExecutor {
    private var cache: [String: String] = [:]
    
    func execute(_ code: String) async throws -> String {
        if let cached = cache[code] {
            return cached
        }
        let result = try await performExecution(code)
        cache[code] = result
        return result
    }
}
```

### 5. Use Property Wrappers

```swift
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var renderedHTML: String = ""
    @Published var isRendering: Bool = false
}
```

## Interoperability During Migration

### Bridging Header Pattern

```objc
// MacDown-Bridging-Header.h
#ifndef MacDown_Bridging_Header_h
#define MacDown_Bridging_Header_h

#import "MPDocument.h"
#import "MPRenderer.h"
// ... other Objective-C headers

#endif /* MacDown_Bridging_Header_h */
```

### Exposing Swift to Objective-C

```swift
// In Swift file (automatically exposed)
@objc class SwiftDocumentRenderer: NSObject {
    @objc func render(_ content: String, 
                     completion: @escaping (String) -> Void) {
        Task {
            let result = try await performRender(content)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
```

### Objective-C Using Swift

```objc
// In Objective-C file
#import "MacDown-Swift.h"

SwiftDocumentRenderer *renderer = [[SwiftDocumentRenderer alloc] init];
[renderer renderWithContent:markdown completion:^(NSString *html) {
    // Use result
}];
```

## Performance Optimization During Migration

### Memory Management

- Use `autoreleasepool` for large batches
- Enable `-Osize` for optimized builds
- Profile with Instruments
- Use WWDC performance videos as reference

### Concurrency Performance

- Use `nonisolated` for thread-safe functions
- Avoid context switches
- Use `@inline(__always__)` for hot paths
- Profile with os_signpost

### Hoedown Replacement Options

1. **Keep Hoedown** (Recommended for Phase 1-4)
   - Stable, battle-tested
   - Easy to keep during migration
   - Replace after full migration

2. **Migrate to Swift-Markdown** (Future)
   - Apple's official Swift markdown library
   - Modern, type-safe
   - Easier to extend

```swift
import Markdown

let document = Document(parsing: markdownString)
let html = HtmlRenderer().render(document)
```

## Testing Strategy

### Unit Tests

```swift
class RCodeExecutorTests: XCTestCase {
    let executor = RCodeExecutor.shared
    
    @MainActor
    func testRCodeExecution() async throws {
        let output = try await executor.execute("1 + 1")
        XCTAssertTrue(output.contains("2"))
    }
}
```

### Integration Tests

```swift
class RMarkdownRendererTests: XCTestCase {
    @MainActor
    func testRMarkdownRendering() async throws {
        let markdown = """
        # Test
        
        ```{r}
        x <- 1:10
        mean(x)
        ```
        """
        
        let renderer = RMarkdownRenderer()
        let html = try await renderer.render(markdown)
        XCTAssertTrue(html.contains("mean"))
    }
}
```

## Migration Timeline

```
Week 1-2:    Foundation setup
Week 2-3:    Utilities (FileType, Executors)
Week 3-4:    Parsers (RMarkdown, LaTeX)
Week 4-6:    Core renderers
Week 6-10:   UI components (SwiftUI)
Week 10+:    Full migration, optimization
```

## Rollout Strategy

### Beta Releases

1. **Beta 1**: Swift utilities + existing Objective-C UI
2. **Beta 2**: Swift renderers + optional SwiftUI UI
3. **Beta 3**: SwiftUI as default with AppKit fallback
4. **Release**: Full Swift codebase

### Version Numbering

- v1.8.x: Swift utilities (Objective-C main code)
- v1.9.x: Swift renderers (Objective-C UI)
- v2.0.0: Full Swift, modern UI

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Performance regression | Medium | Profile continuously, use Instruments |
| Stability issues | High | Extensive beta testing, gradual rollout |
| Binary size increase | Low | Strip debug symbols, use LTO |
| Hoedown replacement | Medium | Keep Hoedown until proven replacement |
| User experience change | Medium | Maintain AppKit UI until smooth transition |

## Success Criteria

✅ **Phase Complete When**:
- All tests pass (existing + new)
- No performance regression
- Zero crashes in beta
- User feedback positive
- Code review approved

## Future Improvements After Swift Migration

1. **Async Rendering**
   - Non-blocking preview updates
   - Cancellation support
   - Progress reporting

2. **Modern UI**
   - Native SwiftUI interface
   - Floating panels
   - Drag-and-drop support

3. **Advanced Features**
   - Plugin system in Swift
   - Real-time collaboration
   - Cloud sync support

4. **Performance Optimizations**
   - Incremental rendering
   - Parallel processing
   - Memory pool optimization

## References

- [Swift Official Documentation](https://docs.swift.org/)
- [Concurrency in Swift](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [WWDC Videos on Swift](https://developer.apple.com/videos/)
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)
- [Interoperability with Objective-C](https://developer.apple.com/documentation/swift/interoperating-with-objective-c)
