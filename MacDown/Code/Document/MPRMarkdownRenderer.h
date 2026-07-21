#ifndef MPRMarkdownRenderer_h
#define MPRMarkdownRenderer_h

#import <Foundation/Foundation.h>
#import "MPRendererProtocol.h"

@protocol MPRMarkdownRendererDataSource
- (NSString *)rendererMarkdownSource;
- (NSString *)rendererDocumentTitle;
@end

@protocol MPRMarkdownRendererDelegate
- (void)renderer:(id)renderer didProduceHTMLOutput:(NSString *)html;
- (void)rendererDidStartParsing:(id)renderer;
- (void)rendererDidFinishParsing:(id)renderer;
@end

@interface MPRMarkdownRenderer : NSObject <MPRendererProtocol>

@property (nonatomic, weak) id<MPRMarkdownRendererDataSource> dataSource;
@property (nonatomic, weak) id<MPRMarkdownRendererDelegate> delegate;
@property (nonatomic, assign) BOOL enableRCodeExecution;
@property (nonatomic, copy) NSString *rPath;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

#endif
