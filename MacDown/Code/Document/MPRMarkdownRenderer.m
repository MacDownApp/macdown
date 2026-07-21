#import "MPRMarkdownRenderer.h"
#import <hoedown/html.h>
#import <hoedown/document.h>

@interface MPRMarkdownRenderer ()
@property (nonatomic, readwrite) NSString *html;
@property (nonatomic, readwrite) BOOL isRendering;
@property (nonatomic, strong) NSTask *rTask;
@property (nonatomic, strong) NSMutableString *rOutput;
@end

@implementation MPRMarkdownRenderer

- (instancetype)init {
    self = [super init];
    if (self) {
        _html = @"";
        _isRendering = NO;
        _enableRCodeExecution = YES;
        _rPath = @"/usr/local/bin/Rscript";
        _rOutput = [NSMutableString string];
    }
    return self;
}

- (void)parseAndRenderNow {
    if (self.isRendering) return;

    self.isRendering = YES;
    if ([self.delegate respondsToSelector:@selector(rendererDidStartParsing:)]) {
        [self.delegate rendererDidStartParsing:self];
    }

    NSString *source = [self.dataSource rendererMarkdownSource];
    if (!source || source.length == 0) {
        self.html = @"";
        self.isRendering = NO;
        [self notifyDelegateWithOutput:@""];
        return;
    }

    if (self.enableRCodeExecution) {
        [self renderWithRExecution:source];
    } else {
        [self renderMarkdownOnly:source];
    }
}

- (void)parseAndRenderLater {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self parseAndRenderNow];
    });
}

- (void)cancelParsing {
    if (self.rTask && self.rTask.isRunning) {
        [self.rTask terminate];
        self.rTask = nil;
    }
    self.isRendering = NO;
}

- (void)renderMarkdownOnly:(NSString *)source {
    NSString *html = [self markdownToHTML:source];
    self.html = html;
    self.isRendering = NO;
    [self notifyDelegateWithOutput:html];
}

- (void)renderWithRExecution:(NSString *)source {
    [self parseRCodeBlocks:source completion:^(NSString *processedMarkdown) {
        NSString *html = [self markdownToHTML:processedMarkdown];
        self.html = html;
        self.isRendering = NO;
        [self notifyDelegateWithOutput:html];
    }];
}

- (void)parseRCodeBlocks:(NSString *)source completion:(void(^)(NSString *))completion {
    [self.rOutput setString:@""];

    NSRegularExpression *codeBlockRegex = [NSRegularExpression
        regularExpressionWithPattern:@"```\\{r[^}]*\\}\\n([\\s\\S]*?)\\n```"
                             options:0
                               error:nil];

    NSMutableString *processedSource = [source mutableCopy];
    NSArray *matches = [codeBlockRegex matchesInString:source options:0 range:NSMakeRange(0, source.length)];

    if (matches.count == 0) {
        completion(processedSource);
        return;
    }

    __block NSInteger completedBlocks = 0;
    for (NSTextCheckingResult *match in matches) {
        NSString *codeBlock = [source substringWithRange:[match rangeAtIndex:1]];

        [self executeRCode:codeBlock completion:^(NSString *output, NSError *error) {
            NSString *outputBlock = error
                ? [NSString stringWithFormat:@"\n```\nError: %@\n```\n", error.localizedDescription]
                : [NSString stringWithFormat:@"\n```\n%@\n```\n", output];

            [processedSource replaceOccurrencesOfString:[source substringWithRange:match.range]
                                             withString:outputBlock
                                                options:0
                                                  range:NSMakeRange(0, processedSource.length)];

            completedBlocks++;
            if (completedBlocks == matches.count) {
                completion(processedSource);
            }
        }];
    }
}

- (void)executeRCode:(NSString *)code completion:(void(^)(NSString *, NSError *))completion {
    self.rTask = [[NSTask alloc] init];
    self.rTask.executableURL = [NSURL fileURLWithPath:self.rPath];
    self.rTask.arguments = @[@"-e", code];

    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    self.rTask.standardOutput = outputPipe;
    self.rTask.standardError = errorPipe;

    NSError *launchError = nil;
    [self.rTask launchAndReturnError:&launchError];

    if (launchError) {
        completion(nil, launchError);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.rTask waitUntilExit];

        NSData *outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(output ?: @"", nil);
        });
    });
}

- (NSString *)markdownToHTML:(NSString *)markdown {
    const char *data = [markdown UTF8String];
    size_t size = strlen(data);

    hoedown_document *document = hoedown_document_new(NULL, NULL, 0);
    hoedown_buffer *output = hoedown_buffer_new(64);

    hoedown_document_render(document, output, (uint8_t *)data, size);

    NSString *html = [[NSString alloc] initWithBytes:output->data
                                               length:output->size
                                             encoding:NSUTF8StringEncoding];

    hoedown_buffer_free(output);
    hoedown_document_free(document);

    return html ?: @"";
}

- (void)notifyDelegateWithOutput:(NSString *)html {
    if ([self.delegate respondsToSelector:@selector(renderer:didProduceHTMLOutput:)]) {
        [self.delegate renderer:self didProduceHTMLOutput:html];
    }
    if ([self.delegate respondsToSelector:@selector(rendererDidFinishParsing:)]) {
        [self.delegate rendererDidFinishParsing:self];
    }
}

- (void)dealloc {
    [self cancelParsing];
}

@end
