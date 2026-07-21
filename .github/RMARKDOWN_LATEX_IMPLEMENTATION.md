# RMarkdown and LaTeX Implementation Guide

This document describes the implementation status and remaining integration steps for RMarkdown and LaTeX support in MacDown.

## Implementation Status

### ✅ Completed Components

**Phase 1: Infrastructure**
- [x] File type registration in Info.plist (.rmd, .Rmd, .tex, .latex)
- [x] MPFileType helper for type detection
- [x] MPDocument file type detection extension
- [x] UTType declarations for both formats

**Phase 2: RMarkdown Support**
- [x] MPRMarkdownRenderer - Main RMarkdown rendering engine
- [x] MPRMarkdownParser - Code block and metadata parsing
- [x] MPRCodeExecutor - R code execution via Rscript
- [x] R installation detection and timeout handling
- [x] Chunk option parsing (echo, results, fig.width, etc.)
- [x] Output caching with hash-based invalidation

**Phase 3: LaTeX Support**
- [x] MPLaTeXRenderer - LaTeX compilation and PDF handling
- [x] MPLaTeXParser - Document structure and package detection
- [x] MPLaTeXCompiler - pdflatex compilation wrapper
- [x] LaTeX installation detection
- [x] Error reporting and build log capture
- [x] PDF caching with timestamp validation

**Phase 4: Utilities**
- [x] MPRCodeExecutor - Async R code execution
- [x] MPLaTeXCompiler - Async LaTeX compilation
- [x] Timeout support for both tools
- [x] Process management and cleanup

**Phase 5: Documentation**
- [x] User guide (RMARKDOWN_LATEX_SUPPORT.md)
- [x] Feature overview and examples
- [x] Troubleshooting section
- [x] Preferences configuration

### 🔄 In Progress / Remaining Work

**Phase 6: Full MPDocument Integration**
- [ ] Call updateRendererForFileType in windowControllerDidLoadNib
- [ ] Update readFromData:ofType:error: to handle new types
- [ ] Update dataOfType:error: for serialization
- [ ] Update writableTypes to include new formats
- [ ] Handle file type changes during document lifecycle

**Phase 7: UI Extensions**
- [ ] Create preferences pane for RMarkdown settings
- [ ] Create preferences pane for LaTeX settings
- [ ] Add status indicator for compilation/execution
- [ ] Create error display panel
- [ ] Add progress indicator during R code execution
- [ ] Add progress indicator during LaTeX compilation

**Phase 8: Syntax Highlighting**
- [ ] Extend HGMarkdownHighlighter for R code blocks
- [ ] Add LaTeX command highlighting
- [ ] Add LaTeX environment highlighting
- [ ] Add LaTeX math mode highlighting
- [ ] Support for custom color schemes

**Phase 9: Export Options**
- [ ] RMarkdown → HTML with embedded output
- [ ] RMarkdown → PDF via LaTeX
- [ ] LaTeX → PDF (compiled)
- [ ] LaTeX → Source with full paths
- [ ] RMarkdown → R script extraction
- [ ] Support for custom export templates

**Phase 10: Advanced Features**
- [ ] R package dependency detection
- [ ] LaTeX package availability checking
- [ ] Installation prompts for missing tools
- [ ] Caching statistics and management UI
- [ ] Background compilation queue
- [ ] Incremental compilation support

## Architecture Overview

```
MacDown Application
├─ MPDocument (Document Controller)
│  ├─ MPDocument+FileTypeSupport (Type detection)
│  ├─ File Type Detection
│  │  ├─ .md → MPRenderer (existing)
│  │  ├─ .rmd → MPRMarkdownRenderer
│  │  └─ .tex → MPLaTeXRenderer
│  │
│  ├─ RMarkdown Processing Pipeline
│  │  ├─ MPRMarkdownParser (parse code blocks)
│  │  ├─ MPRCodeExecutor (execute R code)
│  │  └─ Hoedown (render markdown)
│  │
│  └─ LaTeX Processing Pipeline
│     ├─ MPLaTeXParser (parse document structure)
│     ├─ MPLaTeXCompiler (run pdflatex)
│     └─ PDF.js Viewer (display PDF)
│
├─ External Tools
│  ├─ R/Rscript (/usr/local/bin/Rscript)
│  └─ pdflatex (/usr/local/bin/pdflatex)
│
└─ Caching System
   ├─ ~/.macdown/rmd_cache/{hash}/
   └─ ~/.macdown/latex_cache/{hash}/
```

## Integration Checklist

### 1. MPDocument Integration

**File**: `MacDown/Code/Document/MPDocument.m`

Add to imports:
```objc
#import "MPDocument+FileTypeSupport.h"
#import "MPRMarkdownRenderer.h"
#import "MPLaTeXRenderer.h"
```

In `windowControllerDidLoadNib:` or initialization:
```objc
- (void)windowControllerDidLoadNib:(NSWindowController *)controller {
    // ... existing code ...
    
    // Detect file type and create appropriate renderer
    [self updateRendererForFileType:self.documentFileType];
    
    // ... rest of setup ...
}
```

Update file I/O methods:
```objc
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!string) {
        if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadInapplicableStringEncodingError userInfo:nil];
        return NO;
    }
    
    switch (self.documentFileType) {
        case MPDocumentFileTypeRMarkdown:
            self.markdown = string;
            break;
        case MPDocumentFileTypeLaTeX:
            // Store as markdown property temporarily for compatibility
            self.markdown = string;
            break;
        default:
            self.markdown = string;
            break;
    }
    
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSString *content = self.markdown ?: @"";
    return [content dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSArray *)writableTypes {
    static NSArray *types = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = @[
            @"net.daringfireball.markdown",
            @"com.macdown.rmarkdown",
            @"com.macdown.latex",
            @"public.plain-text"
        ];
    });
    return types;
}
```

### 2. Syntax Highlighting Extensions

**File**: `MacDown/Code/Dependency/peg-markdown-highlight/HGMarkdownHighlighter.m`

Add regex patterns for R code blocks:
```objc
// In highlightMarkdownInRange:
NSRegularExpression *rCodeBlockRegex = [NSRegularExpression 
    regularExpressionWithPattern:@"```\\{r[^}]*\\}" 
    options:0 error:nil];
// Apply R-specific syntax highlighting
```

Add patterns for LaTeX:
```objc
// Detect LaTeX commands
NSRegularExpression *latexCommandRegex = [NSRegularExpression
    regularExpressionWithPattern:@"\\\\[a-zA-Z]+"
    options:0 error:nil];
```

### 3. Preferences UI

Create new files:
- `MacDown/Code/Preferences/MPRMarkdownPreferencesViewController.h`
- `MacDown/Code/Preferences/MPRMarkdownPreferencesViewController.m`
- `MacDown/Code/Preferences/MPLaTeXPreferencesViewController.h`
- `MacDown/Code/Preferences/MPLaTeXPreferencesViewController.m`

Add to MainMenu.xib:
- RMarkdown preferences tab with:
  - Execute code on edit (checkbox)
  - Execution timeout (slider, 5-120 seconds)
  - Show chunk output (checkbox)
  - R executable path (text field with picker)

- LaTeX preferences tab with:
  - Compile on edit (checkbox)
  - LaTeX engine (dropdown: pdflatex/xelatex/lualatex)
  - Show build log (checkbox)
  - Use BibTeX (checkbox)
  - pdflatex executable path (text field with picker)

### 4. Error Display Panel

Create new files:
- `MacDown/Code/View/MPCompilationErrorViewController.h`
- `MacDown/Code/View/MPCompilationErrorViewController.m`

Display in a collapsible panel at the bottom of the preview pane showing:
- Error type (R execution error, LaTeX compilation error)
- Error message
- Relevant line numbers
- Build log (for LaTeX)

### 5. Export Options

Modify `MPExportPanelAccessoryViewController.m`:
- Add format selection based on document type
- For RMarkdown:
  - Export as HTML (with R output)
  - Export as PDF (via LaTeX)
  - Export as R script (code only)
- For LaTeX:
  - Export as PDF (compiled)
  - Export as source (with full paths)

### 6. Status Indicators

Add to toolbar/status bar:
- Compilation status for current document
- Clickable to show last error
- Progress indicator during compilation/execution

## Testing Strategy

### Unit Tests

Create `MacDownTests/` files:
- `MPRMarkdownParserTests.m`
- `MPLaTeXParserTests.m`
- `MPRCodeExecutorTests.m`
- `MPLaTeXCompilerTests.m`

Test cases:
- Code block parsing with various options
- LaTeX document structure detection
- R execution with timeouts
- LaTeX compilation error handling
- Cache invalidation logic

### Integration Tests

- Opening .rmd file and executing code
- Opening .tex file and compiling
- Switching between file types
- Error handling when tools missing
- Preview updates on content change

### Sample Files

Create in `MacDown/Samples/`:
- `RMarkdown_Example.rmd` - Basic RMarkdown demo
- `LaTeX_Example.tex` - Basic LaTeX demo
- `Complex_RMarkdown.rmd` - With multiple chunks and options
- `Academic_Paper.tex` - Full paper example

## Performance Considerations

1. **Caching Strategy**
   - RMarkdown: Hash-based chunk caching
   - LaTeX: Timestamp-based PDF caching
   - Clear cache on document save

2. **Asynchronous Processing**
   - R execution on background thread
   - LaTeX compilation on background thread
   - Non-blocking UI during processing

3. **Debouncing**
   - Delay compilation 500ms after last edit
   - Cancel previous compilation if new one starts
   - Prevent rapid fire operations

## Known Limitations

1. **RMarkdown**
   - No inline R evaluation (only code blocks)
   - Chunk dependencies not tracked
   - No interactive plots/Shiny support

2. **LaTeX**
   - Single-engine selection (not universal binary)
   - No synctex support for reverse search
   - No collaborative editing

3. **General**
   - Requires manual tool installation (no auto-install)
   - No package manager integration
   - Limited to 60-second timeout for operations

## Future Enhancements

- [ ] XeLaTeX and LuaLaTeX support
- [ ] Pandoc integration for format conversion
- [ ] Git-aware diff for version control
- [ ] Collaborative editing with live updates
- [ ] Package auto-installation (R packages, LaTeX packages)
- [ ] Interactive console for R
- [ ] Forward/inverse search for LaTeX
- [ ] Math-only preview mode for LaTeX
- [ ] R Notebook format support
- [ ] Jupyter Notebook interoperability

## Debugging

Enable debug logging:
```objc
// In implementation files
#define MP_DEBUG_LOGGING 1

#if MP_DEBUG_LOGGING
    NSLog(@"[MPRMarkdownRenderer] %@", message);
#endif
```

Monitor processes:
```bash
# Watch R execution
ps aux | grep Rscript

# Watch LaTeX compilation
ps aux | grep pdflatex

# Check cached files
ls -la ~/.macdown/rmd_cache/
ls -la ~/.macdown/latex_cache/
```

## Contributing

To extend RMarkdown/LaTeX support:
1. Follow existing code style (2-space indents, Apple naming conventions)
2. Add unit tests for new functionality
3. Update documentation
4. Test with sample files
5. Submit PR with detailed description

## References

- [RMarkdown Documentation](https://rmarkdown.rstudio.com/)
- [LaTeX Project](https://www.latex-project.org/)
- [Pandoc User Guide](https://pandoc.org/MANUAL.html)
- [R Documentation](https://www.r-project.org/doc/manuals/r-release/R-intro.pdf)
