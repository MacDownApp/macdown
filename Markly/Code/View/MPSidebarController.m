//
//  MPSidebarController.m
//  Markly
//

#import "MPSidebarController.h"

static CGFloat const kMPSidebarMinWidth = 150.0;
static CGFloat const kMPSidebarDefaultWidth = 220.0;
static CGFloat const kMPSidebarMaxWidth = 400.0;


#pragma mark - MPFileNode

@implementation MPFileNode

- (BOOL)isDirectory
{
    return self.children != nil;
}

+ (MPFileNode *)nodeWithURL:(NSURL *)url
{
    MPFileNode *node = [[MPFileNode alloc] init];
    node.name = url.lastPathComponent;
    node.url = url;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    [fm fileExistsAtPath:url.path isDirectory:&isDir];

    if (isDir)
    {
        NSMutableArray *kids = [NSMutableArray array];
        NSArray *contents = [fm contentsOfDirectoryAtURL:url
                              includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];

        // Sort: directories first, then alphabetical
        contents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
            NSNumber *aIsDir, *bIsDir;
            [a getResourceValue:&aIsDir forKey:NSURLIsDirectoryKey error:nil];
            [b getResourceValue:&bIsDir forKey:NSURLIsDirectoryKey error:nil];
            if (aIsDir.boolValue != bIsDir.boolValue)
                return aIsDir.boolValue ? NSOrderedAscending : NSOrderedDescending;
            return [a.lastPathComponent localizedCaseInsensitiveCompare:b.lastPathComponent];
        }];

        for (NSURL *childURL in contents)
        {
            // Only show markdown-related files and directories
            NSString *ext = childURL.pathExtension.lowercaseString;
            NSNumber *childIsDir;
            [childURL getResourceValue:&childIsDir forKey:NSURLIsDirectoryKey error:nil];

            if (childIsDir.boolValue ||
                [ext isEqualToString:@"md"] ||
                [ext isEqualToString:@"markdown"] ||
                [ext isEqualToString:@"txt"] ||
                [ext isEqualToString:@"mdown"] ||
                [ext isEqualToString:@"mkd"])
            {
                [kids addObject:[MPFileNode nodeWithURL:childURL]];
            }
        }
        node.children = kids;
    }

    return node;
}

@end


#pragma mark - MPHeadingNode

@implementation MPHeadingNode

- (instancetype)init
{
    self = [super init];
    if (self)
        _children = [NSMutableArray array];
    return self;
}

+ (NSArray<MPHeadingNode *> *)headingsFromMarkdown:(NSString *)markdown
{
    if (!markdown.length)
        return @[];

    NSMutableArray<MPHeadingNode *> *allHeadings = [NSMutableArray array];
    NSArray *lines = [markdown componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    NSUInteger offset = 0;

    for (NSString *line in lines)
    {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];

        if ([trimmed hasPrefix:@"#"])
        {
            NSInteger level = 0;
            for (NSUInteger i = 0; i < trimmed.length && i < 6; i++)
            {
                if ([trimmed characterAtIndex:i] == '#')
                    level++;
                else
                    break;
            }

            if (level > 0 && level <= 6 && trimmed.length > level)
            {
                NSString *title = [[trimmed substringFromIndex:level]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                // Strip trailing #s
                while ([title hasSuffix:@"#"])
                    title = [[title substringToIndex:title.length - 1]
                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                if (title.length > 0)
                {
                    MPHeadingNode *heading = [[MPHeadingNode alloc] init];
                    heading.title = title;
                    heading.level = level;
                    heading.range = NSMakeRange(offset, line.length);
                    [allHeadings addObject:heading];
                }
            }
        }
        offset += line.length + 1; // +1 for newline
    }

    // Build hierarchy: nest lower-level headings under higher-level ones
    NSMutableArray<MPHeadingNode *> *roots = [NSMutableArray array];
    NSMutableArray<MPHeadingNode *> *stack = [NSMutableArray array];

    for (MPHeadingNode *heading in allHeadings)
    {
        while (stack.count > 0 && stack.lastObject.level >= heading.level)
            [stack removeLastObject];

        if (stack.count > 0)
            [stack.lastObject.children addObject:heading];
        else
            [roots addObject:heading];

        [stack addObject:heading];
    }

    return roots;
}

@end


#pragma mark - MPSidebarController

@interface MPSidebarController ()
@property (nonatomic, strong) NSSplitView *outerSplitView;
@property (nonatomic, strong) NSView *sidebarView;
@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSOutlineView *fileOutlineView;
@property (nonatomic, strong) NSOutlineView *headingOutlineView;
@property (nonatomic, strong) MPFileNode *rootFileNode;
@property (nonatomic, strong) NSArray<MPHeadingNode *> *headingRoots;
@property (nonatomic) BOOL sidebarVisible;
@property (nonatomic) CGFloat savedSidebarWidth;
@end


@implementation MPSidebarController

- (instancetype)initWithContentView:(NSView *)contentView
{
    self = [super init];
    if (!self)
        return nil;

    self.savedSidebarWidth = kMPSidebarDefaultWidth;
    self.headingRoots = @[];

    // Create the outer split view
    self.outerSplitView = [[NSSplitView alloc] initWithFrame:contentView.bounds];
    self.outerSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.outerSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.outerSplitView.vertical = YES;
    self.outerSplitView.delegate = self;

    // Create sidebar container
    self.sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kMPSidebarDefaultWidth, contentView.bounds.size.height)];
    self.sidebarView.autoresizingMask = NSViewHeightSizable;

    // Create tab view for Files / Outline tabs
    self.tabView = [[NSTabView alloc] initWithFrame:self.sidebarView.bounds];
    self.tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.tabView.tabViewType = NSTopTabsBezelBorder;
    self.tabView.controlSize = NSControlSizeSmall;

    // Files tab
    NSTabViewItem *filesTab = [[NSTabViewItem alloc] initWithIdentifier:@"files"];
    filesTab.label = @"Files";
    [self setupFileOutlineInView:filesTab];
    [self.tabView addTabViewItem:filesTab];

    // Outline tab
    NSTabViewItem *outlineTab = [[NSTabViewItem alloc] initWithIdentifier:@"outline"];
    outlineTab.label = @"Outline";
    [self setupHeadingOutlineInView:outlineTab];
    [self.tabView addTabViewItem:outlineTab];

    [self.sidebarView addSubview:self.tabView];

    // Start hidden
    self.sidebarVisible = NO;

    return self;
}

- (void)setupFileOutlineInView:(NSTabViewItem *)tabItem
{
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;

    self.fileOutlineView = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    self.fileOutlineView.headerView = nil;
    self.fileOutlineView.rowHeight = 22;
    self.fileOutlineView.indentationPerLevel = 16;
    self.fileOutlineView.autoresizesOutlineColumn = YES;
    self.fileOutlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    self.fileOutlineView.dataSource = self;
    self.fileOutlineView.delegate = self;
    self.fileOutlineView.doubleAction = @selector(fileDoubleClicked:);
    self.fileOutlineView.target = self;

    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    col.editable = NO;
    [self.fileOutlineView addTableColumn:col];
    self.fileOutlineView.outlineTableColumn = col;

    scrollView.documentView = self.fileOutlineView;
    tabItem.view = scrollView;
}

- (void)setupHeadingOutlineInView:(NSTabViewItem *)tabItem
{
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;

    self.headingOutlineView = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    self.headingOutlineView.headerView = nil;
    self.headingOutlineView.rowHeight = 20;
    self.headingOutlineView.indentationPerLevel = 14;
    self.headingOutlineView.autoresizesOutlineColumn = YES;
    self.headingOutlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    self.headingOutlineView.dataSource = self;
    self.headingOutlineView.delegate = self;
    self.headingOutlineView.doubleAction = @selector(headingDoubleClicked:);
    self.headingOutlineView.target = self;

    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"heading"];
    col.editable = NO;
    [self.headingOutlineView addTableColumn:col];
    self.headingOutlineView.outlineTableColumn = col;

    scrollView.documentView = self.headingOutlineView;
    tabItem.view = scrollView;
}


#pragma mark - Public API

- (void)installInWindow:(NSWindow *)window aroundView:(NSView *)contentSplitView
{
    NSView *windowContentView = window.contentView;
    NSRect frame = contentSplitView.frame;

    // Remove existing content from window
    [contentSplitView removeFromSuperview];

    // Configure outer split view
    self.outerSplitView.frame = frame;

    // Add sidebar + content
    [self.outerSplitView addSubview:self.sidebarView];
    [self.outerSplitView addSubview:contentSplitView];

    // Pin outer split view to fill window content
    self.outerSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [windowContentView addSubview:self.outerSplitView];
    [NSLayoutConstraint activateConstraints:@[
        [self.outerSplitView.topAnchor constraintEqualToAnchor:windowContentView.topAnchor],
        [self.outerSplitView.bottomAnchor constraintEqualToAnchor:windowContentView.bottomAnchor],
        [self.outerSplitView.leadingAnchor constraintEqualToAnchor:windowContentView.leadingAnchor],
        [self.outerSplitView.trailingAnchor constraintEqualToAnchor:windowContentView.trailingAnchor],
    ]];

    // Start with sidebar hidden
    [self hideSidebar];
}

- (void)toggleSidebar
{
    if (self.sidebarVisible)
        [self hideSidebar];
    else
        [self showSidebar];
}

- (void)showSidebar
{
    if (self.sidebarVisible)
        return;
    self.sidebarVisible = YES;
    [self.outerSplitView setPosition:self.savedSidebarWidth
                    ofDividerAtIndex:0];

    // Auto-set root to the current file's directory if not set
    if (!self.rootFileNode)
    {
        // Will be set by the document when it opens
    }
}

- (void)hideSidebar
{
    if (!self.sidebarVisible && self.sidebarView.frame.size.width == 0)
        return;
    if (self.sidebarView.frame.size.width > 0)
        self.savedSidebarWidth = self.sidebarView.frame.size.width;
    self.sidebarVisible = NO;
    [self.outerSplitView setPosition:0 ofDividerAtIndex:0];
}

- (void)setRootURL:(NSURL *)url
{
    if (!url)
        return;
    self.rootFileNode = [MPFileNode nodeWithURL:url];
    [self.fileOutlineView reloadData];
    [self.fileOutlineView expandItem:self.rootFileNode];
}

- (void)updateHeadingsFromMarkdown:(NSString *)markdown
{
    self.headingRoots = [MPHeadingNode headingsFromMarkdown:markdown];
    [self.headingOutlineView reloadData];
    [self.headingOutlineView expandItem:nil expandChildren:YES];
}


#pragma mark - Actions

- (void)fileDoubleClicked:(id)sender
{
    MPFileNode *node = [self.fileOutlineView itemAtRow:self.fileOutlineView.clickedRow];
    if (!node || node.isDirectory)
        return;

    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    [dc openDocumentWithContentsOfURL:node.url display:YES
                    completionHandler:^(NSDocument *doc, BOOL wasOpen, NSError *err) {}];
}

- (void)headingDoubleClicked:(id)sender
{
    // Handled by document via notification
    MPHeadingNode *heading = [self.headingOutlineView itemAtRow:self.headingOutlineView.clickedRow];
    if (!heading)
        return;

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"MPSidebarDidSelectHeading"
                      object:self
                    userInfo:@{@"range": [NSValue valueWithRange:heading.range]}];
}


#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (outlineView == self.fileOutlineView)
    {
        if (!item)
            return self.rootFileNode ? self.rootFileNode.children.count : 0;
        return ((MPFileNode *)item).children.count;
    }
    else
    {
        if (!item)
            return self.headingRoots.count;
        return ((MPHeadingNode *)item).children.count;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (outlineView == self.fileOutlineView)
    {
        if (!item)
            return self.rootFileNode.children[index];
        return ((MPFileNode *)item).children[index];
    }
    else
    {
        if (!item)
            return self.headingRoots[index];
        return ((MPHeadingNode *)item).children[index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (outlineView == self.fileOutlineView)
        return ((MPFileNode *)item).isDirectory;
    else
        return ((MPHeadingNode *)item).children.count > 0;
}


#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"cell" owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        cell.identifier = @"cell";

        NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
        imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [cell addSubview:imageView];
        cell.imageView = imageView;

        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.font = [NSFont systemFontOfSize:12];
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:textField];
        cell.textField = textField;

        // Layout
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [imageView.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
            [imageView.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [imageView.widthAnchor constraintEqualToConstant:16],
            [imageView.heightAnchor constraintEqualToConstant:16],
            [textField.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:4],
            [textField.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-2],
            [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    if (outlineView == self.fileOutlineView)
    {
        MPFileNode *node = (MPFileNode *)item;
        cell.textField.stringValue = node.name;
        if (node.isDirectory)
            cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
        else
            cell.imageView.image = [[NSWorkspace sharedWorkspace] iconForFileType:node.url.pathExtension];
    }
    else
    {
        MPHeadingNode *heading = (MPHeadingNode *)item;
        cell.textField.stringValue = heading.title;
        // Indent visually by font size based on heading level
        CGFloat fontSize = MAX(13.0 - heading.level, 10.0);
        cell.textField.font = (heading.level <= 2)
            ? [NSFont boldSystemFontOfSize:fontSize]
            : [NSFont systemFontOfSize:fontSize];
        cell.imageView.image = nil;
    }

    return cell;
}


#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    if (splitView == self.outerSplitView && dividerIndex == 0)
        return kMPSidebarMinWidth;
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    if (splitView == self.outerSplitView && dividerIndex == 0)
        return kMPSidebarMaxWidth;
    return proposedMaximumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return (subview == self.sidebarView);
}

@end
