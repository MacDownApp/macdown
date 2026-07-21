#import "MPRCodeExecutor.h"

@interface MPRCodeExecutor ()
@property (nonatomic, strong) NSTask *currentTask;
@end

@implementation MPRCodeExecutor

+ (instancetype)sharedExecutor {
    static MPRCodeExecutor *executor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        executor = [[MPRCodeExecutor alloc] init];
    });
    return executor;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _executionTimeout = 30.0;
        _rExecutablePath = [self detectedRPath];
    }
    return self;
}

- (BOOL)isRInstalled {
    return [self detectedRPath] != nil;
}

- (NSString *)detectedRPath {
    NSArray *possiblePaths = @[
        @"/usr/local/bin/Rscript",
        @"/opt/homebrew/bin/Rscript",
        @"/usr/bin/Rscript",
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in possiblePaths) {
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }

    NSTask *whichTask = [[NSTask alloc] init];
    whichTask.executableURL = [NSURL fileURLWithPath:@"/usr/bin/which"];
    whichTask.arguments = @[@"Rscript"];

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

- (void)executeCode:(NSString *)rCode
         completion:(void(^)(NSString *output, NSError *error))completion {
    if (!rCode || rCode.length == 0) {
        completion(@"", nil);
        return;
    }

    if (!self.isRInstalled) {
        NSError *error = [NSError errorWithDomain:@"MPRCodeExecutor"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"R is not installed"}];
        completion(nil, error);
        return;
    }

    self.currentTask = [[NSTask alloc] init];
    self.currentTask.executableURL = [NSURL fileURLWithPath:self.rExecutablePath];
    self.currentTask.arguments = @[@"-e", rCode];

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
                                 dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.executionTimeout * NSEC_PER_SEC)),
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
        NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];

        NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";
        NSString *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";

        NSError *error = nil;
        if (self.currentTask.terminationStatus != 0) {
            error = [NSError errorWithDomain:@"MPRCodeExecutor"
                                       code:self.currentTask.terminationStatus
                                   userInfo:@{NSLocalizedDescriptionKey: errorOutput}];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(output, error);
        });
    });
}

- (void)dealloc {
    if (self.currentTask && self.currentTask.isRunning) {
        [self.currentTask terminate];
    }
}

@end
