#import "MPLaTeXRenderer.h"

@interface MPLaTeXRenderer ()
@property (nonatomic, readwrite) NSString *html;
@property (nonatomic, readwrite) BOOL isRendering;
@property (nonatomic, strong) NSTask *pdflatexTask;
@end

@implementation MPLaTeXRenderer

- (instancetype)init {
    self = [super init];
    if (self) {
        _html = @"";
        _isRendering = NO;
        _pdflatexPath = @"/usr/local/bin/pdflatex";
        _temporaryDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    }
    return self;
}

- (void)parseAndRenderNow {
    if (self.isRendering) return;

    self.isRendering = YES;
    if ([self.delegate respondsToSelector:@selector(rendererDidStartParsing:)]) {
        [self.delegate rendererDidStartParsing:self];
    }

    NSString *source = [self.dataSource rendererLaTeXSource];
    if (!source || source.length == 0) {
        self.html = @"";
        self.isRendering = NO;
        [self notifyDelegateWithError:nil];
        return;
    }

    [self compileLaTeXToPDF:source];
}

- (void)parseAndRenderLater {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self parseAndRenderNow];
    });
}

- (void)cancelParsing {
    if (self.pdflatexTask && self.pdflatexTask.isRunning) {
        [self.pdflatexTask terminate];
        self.pdflatexTask = nil;
    }
    self.isRendering = NO;
}

- (void)compileLaTeXToPDF:(NSString *)source {
    NSString *documentTitle = [self.dataSource rendererDocumentTitle] ?: @"document";
    NSString *texFileName = [NSString stringWithFormat:@"%@.tex", documentTitle];
    NSURL *texFileURL = [self.temporaryDirectory URLByAppendingPathComponent:texFileName];
    NSURL *pdfFileURL = [self.temporaryDirectory URLByAppendingPathComponent:[documentTitle stringByAppendingPathExtension:@"pdf"]];

    NSError *writeError = nil;
    [source writeToURL:texFileURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];

    if (writeError) {
        [self notifyDelegateWithError:writeError];
        return;
    }

    self.pdflatexTask = [[NSTask alloc] init];
    self.pdflatexTask.executableURL = [NSURL fileURLWithPath:self.pdflatexPath];
    self.pdflatexTask.arguments = @[
        @"-interaction=nonstopmode",
        @"-output-directory", self.temporaryDirectory.path,
        texFileURL.path
    ];

    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    self.pdflatexTask.standardOutput = outputPipe;
    self.pdflatexTask.standardError = errorPipe;

    NSError *launchError = nil;
    [self.pdflatexTask launchAndReturnError:&launchError];

    if (launchError) {
        [self notifyDelegateWithError:launchError];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.pdflatexTask waitUntilExit];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:pdfFileURL.path]) {
                if ([self.delegate respondsToSelector:@selector(renderer:didProducePDFAtURL:)]) {
                    [self.delegate renderer:self didProducePDFAtURL:pdfFileURL];
                }
                self.html = [NSString stringWithFormat:@"<embed src='file://%@' type='application/pdf' width='100%%' height='100%%'/>", pdfFileURL.path];
            } else {
                NSError *compilationError = [NSError errorWithDomain:@"MPLaTeXRenderer" code:1 userInfo:@{NSLocalizedDescriptionKey: @"PDF compilation failed"}];
                [self notifyDelegateWithError:compilationError];
                return;
            }

            self.isRendering = NO;
            [self notifyDelegate];
        });
    });
}

- (void)notifyDelegate {
    if ([self.delegate respondsToSelector:@selector(renderer:didProduceHTMLOutput:)]) {
        [self.delegate renderer:self didProduceHTMLOutput:self.html];
    }
    if ([self.delegate respondsToSelector:@selector(rendererDidFinishParsing:)]) {
        [self.delegate rendererDidFinishParsing:self];
    }
}

- (void)notifyDelegateWithError:(NSError *)error {
    if (error && [self.delegate respondsToSelector:@selector(renderer:didFailWithError:)]) {
        [self.delegate renderer:self didFailWithError:error];
    }
    self.isRendering = NO;
    [self notifyDelegate];
}

- (void)dealloc {
    [self cancelParsing];
}

@end
