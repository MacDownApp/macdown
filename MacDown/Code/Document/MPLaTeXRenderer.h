#ifndef MPLaTeXRenderer_h
#define MPLaTeXRenderer_h

#import <Foundation/Foundation.h>
#import "MPRendererProtocol.h"

@protocol MPLaTeXRendererDataSource
- (NSString *)rendererLaTeXSource;
- (NSString *)rendererDocumentTitle;
@end

@protocol MPLaTeXRendererDelegate
- (void)renderer:(id)renderer didProduceHTMLOutput:(NSString *)html;
- (void)renderer:(id)renderer didProducePDFAtURL:(NSURL *)pdfURL;
- (void)rendererDidStartParsing:(id)renderer;
- (void)rendererDidFinishParsing:(id)renderer;
- (void)renderer:(id)renderer didFailWithError:(NSError *)error;
@end

@interface MPLaTeXRenderer : NSObject <MPRendererProtocol>

@property (nonatomic, weak) id<MPLaTeXRendererDataSource> dataSource;
@property (nonatomic, weak) id<MPLaTeXRendererDelegate> delegate;
@property (nonatomic, copy) NSString *pdflatexPath;
@property (nonatomic, copy) NSURL *temporaryDirectory;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

#endif
