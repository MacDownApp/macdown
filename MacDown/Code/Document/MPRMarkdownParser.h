#ifndef MPRMarkdownParser_h
#define MPRMarkdownParser_h

#import <Foundation/Foundation.h>

@interface MPRMarkdownCodeBlock : NSObject
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSDictionary *options;
@property (nonatomic, assign) NSRange range;
@end

@interface MPRMarkdownParser : NSObject

- (NSArray<MPRMarkdownCodeBlock *> *)parseCodeBlocks:(NSString *)rmarkdownContent;
- (NSString *)extractMarkdownWithoutCodeBlocks:(NSString *)rmarkdownContent;
- (BOOL)isRCodeBlock:(NSString *)fenceInfo;
- (NSDictionary *)parseChunkOptions:(NSString *)fenceInfo;

@end

#endif
