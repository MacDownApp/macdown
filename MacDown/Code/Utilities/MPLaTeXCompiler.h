#ifndef MPLaTeXCompiler_h
#define MPLaTeXCompiler_h

#import <Foundation/Foundation.h>

@interface MPLaTeXCompiler : NSObject

@property (nonatomic, copy) NSString *pdflatexExecutablePath;
@property (nonatomic, assign) NSTimeInterval compilationTimeout;

+ (instancetype)sharedCompiler;

- (BOOL)isPdfLatexInstalled;
- (NSString *)detectedPdfLatexPath;

- (void)compileTeXFile:(NSURL *)texFileURL
           outputPDFURL:(NSURL *)pdfFileURL
            completion:(void(^)(NSURL *pdfURL, NSError *error))completion;

@end

#endif
