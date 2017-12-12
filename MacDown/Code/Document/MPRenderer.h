//
//  MPRenderer.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol MPRendererDataSource;
@protocol MPRendererDelegate;


typedef NS_ENUM(NSUInteger, MPCodeBlockAccessoryType)
{
    MPCodeBlockAccessoryNone = 0,
    MPCodeBlockAccessoryLanguageName,
    MPCodeBlockAccessoryCustom,
};


@interface MPRenderer : NSObject

@property (nonatomic) int rendererFlags;
@property (weak) id<MPRendererDataSource> dataSource;
@property (weak) id<MPRendererDelegate> delegate;

- (void)parseAndRenderNow;
- (void)parseAndRenderLater;
- (void)parseNowWithCommand:(SEL)action completionHandler:(void(^)())handler;
- (void)parseLaterWithCommand:(SEL)action completionHandler:(void(^)())handler;
- (void)parseIfPreferencesChanged;
- (void)parse;
- (void)renderIfPreferencesChanged;
- (void)render;

- (NSString *)currentHtml;
- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting;

@end


@protocol MPRendererDataSource <NSObject>

- (NSString *)rendererMarkdown:(MPRenderer *)renderer;
- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer;

@end

@protocol MPRendererDelegate <NSObject>

- (int)rendererExtensions:(MPRenderer *)renderer;
- (BOOL)rendererHasSmartyPants:(MPRenderer *)renderer;
- (BOOL)rendererRendersTOC:(MPRenderer *)renderer;
- (NSString *)rendererStyleName:(MPRenderer *)renderer;
- (BOOL)rendererDetectsFrontMatter:(MPRenderer *)renderer;
- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer;
- (BOOL)rendererHasMermaid:(MPRenderer *)renderer;
- (BOOL)rendererHasGraphviz:(MPRenderer *)renderer;
- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer;
- (BOOL)rendererHasMathJax:(MPRenderer *)renderer;
- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer;
- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html;

@end
