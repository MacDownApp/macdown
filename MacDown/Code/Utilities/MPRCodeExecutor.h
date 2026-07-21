#ifndef MPRCodeExecutor_h
#define MPRCodeExecutor_h

#import <Foundation/Foundation.h>

@interface MPRCodeExecutor : NSObject

@property (nonatomic, copy) NSString *rExecutablePath;
@property (nonatomic, assign) NSTimeInterval executionTimeout;

+ (instancetype)sharedExecutor;

- (BOOL)isRInstalled;
- (NSString *)detectedRPath;

- (void)executeCode:(NSString *)rCode
         completion:(void(^)(NSString *output, NSError *error))completion;

@end

#endif
