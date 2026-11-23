//
//  MPRenderer.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPMarkdownEngine.h"
@protocol MPRendererDataSource;
@protocol MPRendererDelegate;


typedef NS_ENUM(NSUInteger, MPCodeBlockAccessoryType)
{
    MPCodeBlockAccessoryNone = 0,
    MPCodeBlockAccessoryLanguageName,
    MPCodeBlockAccessoryCustom,
};


@interface MPRenderer : NSObject

/// Options used for the most recent parse. Nil before the first parse.
@property (nonatomic, copy, readonly) MPMarkdownRenderOptions *markdownOptions;
@property (weak) id<MPRendererDataSource> dataSource;
@property (weak) id<MPRendererDelegate> delegate;

- (void)parseAndRenderNow;
- (void)parseAndRenderLater;
- (void)parseIfPreferencesChanged;
- (void)renderIfPreferencesChanged;
- (void)render;

- (NSString *)currentHtml;
- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting;

@end


@protocol MPRendererDataSource <NSObject>

- (BOOL)rendererLoading;
- (NSString *)rendererMarkdown:(MPRenderer *)renderer;
- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer;

@end

@protocol MPRendererDelegate <NSObject>

- (MPMarkdownRenderOptions *)rendererMarkdownOptions:(MPRenderer *)renderer;
- (NSString *)rendererStyleName:(MPRenderer *)renderer;
- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer;
- (BOOL)rendererHasMermaid:(MPRenderer *)renderer;
- (BOOL)rendererHasGraphviz:(MPRenderer *)renderer;
- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer;
- (BOOL)rendererHasMathJax:(MPRenderer *)renderer;
- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer;
- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html;

@end
