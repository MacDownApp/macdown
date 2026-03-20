//
//  MPSidebarController.h
//  Markly
//

#import <Cocoa/Cocoa.h>

@interface MPSidebarController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate>

@property (nonatomic, readonly) NSSplitView *outerSplitView;
@property (nonatomic, readonly) NSView *sidebarView;
@property (nonatomic, readonly) BOOL sidebarVisible;

- (instancetype)initWithContentView:(NSView *)contentView;
- (void)installInWindow:(NSWindow *)window aroundView:(NSView *)contentSplitView;
- (void)toggleSidebar;
- (void)showSidebar;
- (void)hideSidebar;

// File browser
- (void)setRootURL:(NSURL *)url;

// Document outline
- (void)updateHeadingsFromMarkdown:(NSString *)markdown;

@end


// Represents a file/folder in the file tree
@interface MPFileNode : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSArray<MPFileNode *> *children;
@property (nonatomic, readonly) BOOL isDirectory;
@end


// Represents a heading in the document outline
@interface MPHeadingNode : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic) NSInteger level; // 1-6
@property (nonatomic) NSRange range;
@property (nonatomic, strong) NSMutableArray<MPHeadingNode *> *children;
@end
