#ifndef MPRendererProtocol_h
#define MPRendererProtocol_h

@protocol MPRendererProtocol <NSObject>

@required

- (void)parseAndRenderNow;
- (void)parseAndRenderLater;
- (void)cancelParsing;

@property (nonatomic, readonly) NSString *html;
@property (nonatomic, readonly) BOOL isRendering;

@optional

- (void)didProduceHTMLOutput:(NSString *)html;

@end

#endif
