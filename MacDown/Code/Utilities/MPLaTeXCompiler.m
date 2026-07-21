#import "MPLaTeXCompiler.h"

@interface MPLaTeXCompiler ()
@property (nonatomic, strong) NSTask *currentTask;
@end

@implementation MPLaTeXCompiler

+ (instancetype)sharedCompiler {
    static MPLaTeXCompiler *compiler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        compiler = [[MPLaTeXCompiler alloc] init];
    });
    return compiler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _compilationTimeout = 60.0;
        _pdflatexExecutablePath = [self detectedPdfLatexPath];
    }
    return self;
}

- (BOOL)isPdfLatexInstalled {
    return [self detectedPdfLatexPath] != nil;
}

- (NSString *)detectedPdfLatexPath {
    NSArray *possiblePaths = @[
        @"/usr/local/bin/pdflatex",
        @"/opt/homebrew/bin/pdflatex",
        @"/Library/TeX/texbin/pdflatex",
        @"/usr/texbin/pdflatex",
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in possiblePaths) {
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }

    NSTask *whichTask = [[NSTask alloc] init];
    whichTask.executableURL = [NSURL fileURLWithPath:@"/usr/bin/which"];
    whichTask.arguments = @[@"pdflatex"];

    NSPipe *outputPipe = [NSPipe pipe];
    whichTask.standardOutput = outputPipe;
    whichTask.standardError = [NSPipe pipe];

    NSError *error = nil;
    [whichTask launchAndReturnError:&error];

    if (!error) {
        NSData *data = [outputPipe.fileHandleForReading readDataToEndOfFile];
        NSString *path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (path.length > 0) {
            return path;
        }
    }

    return nil;
}

- (void)compileTeXFile:(NSURL *)texFileURL
           outputPDFURL:(NSURL *)pdfFileURL
            completion:(void(^)(NSURL *pdfURL, NSError *error))completion {
    if (!texFileURL) {
        NSError *error = [NSError errorWithDomain:@"MPLaTeXCompiler"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No TeX file provided"}];
        completion(nil, error);
        return;
    }

    if (!self.isPdfLatexInstalled) {
        NSError *error = [NSError errorWithDomain:@"MPLaTeXCompiler"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: @"pdflatex is not installed"}];
        completion(nil, error);
        return;
    }

    NSURL *workingDirectory = [texFileURL URLByDeletingLastPathComponent];

    self.currentTask = [[NSTask alloc] init];
    self.currentTask.executableURL = [NSURL fileURLWithPath:self.pdflatexExecutablePath];
    self.currentTask.currentDirectoryURL = workingDirectory;
    self.currentTask.arguments = @[
        @"-interaction=nonstopmode",
        @"-output-directory", workingDirectory.path,
        texFileURL.lastPathComponent
    ];

    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    self.currentTask.standardOutput = outputPipe;
    self.currentTask.standardError = errorPipe;

    NSError *launchError = nil;
    [self.currentTask launchAndReturnError:&launchError];

    if (launchError) {
        completion(nil, launchError);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));

        dispatch_source_set_timer(timer,
                                 dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.compilationTimeout * NSEC_PER_SEC)),
                                 DISPATCH_TIME_FOREVER,
                                 0);

        dispatch_source_set_event_handler(timer, ^{
            if (self.currentTask && self.currentTask.isRunning) {
                [self.currentTask terminate];
                dispatch_source_cancel(timer);
            }
        });

        dispatch_resume(timer);

        [self.currentTask waitUntilExit];
        dispatch_source_cancel(timer);

        NSData *outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
        NSString *compilationOutput = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";

        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL pdfExists = [fileManager fileExistsAtPath:pdfFileURL.path];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (pdfExists) {
                completion(pdfFileURL, nil);
            } else {
                NSError *error = [NSError errorWithDomain:@"MPLaTeXCompiler"
                                                     code:3
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"PDF compilation failed:\n%@", compilationOutput]}];
                completion(nil, error);
            }
        });
    });
}

- (void)dealloc {
    if (self.currentTask && self.currentTask.isRunning) {
        [self.currentTask terminate];
    }
}

@end
