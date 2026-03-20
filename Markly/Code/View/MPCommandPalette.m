//
//  MPCommandPalette.m
//  Markly
//

#import "MPCommandPalette.h"
#import <objc/runtime.h>

static CGFloat const kPaletteWidth = 500;
static CGFloat const kPaletteRowHeight = 28;
static CGFloat const kPaletteMaxVisibleRows = 12;


@implementation MPCommandItem

+ (MPCommandItem *)itemWithTitle:(NSString *)title shortcut:(NSString *)shortcut action:(SEL)action target:(id)target
{
    MPCommandItem *item = [[MPCommandItem alloc] init];
    item.title = title;
    item.shortcut = shortcut;
    item.action = action;
    item.target = target;
    item.isOn = NO;
    return item;
}

+ (MPCommandItem *)toggleWithTitle:(NSString *)title shortcut:(NSString *)shortcut action:(SEL)action target:(id)target isOn:(BOOL)isOn
{
    MPCommandItem *item = [self itemWithTitle:title shortcut:shortcut action:action target:target];
    item.isOn = isOn;
    return item;
}

@end


@interface MPCommandPalette ()
@property (nonatomic, strong) NSTextField *searchField;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSArray<MPCommandItem *> *allCommands;
@property (nonatomic, strong) NSArray<MPCommandItem *> *filteredCommands;
@end


@implementation MPCommandPalette

+ (void)showForWindow:(NSWindow *)parentWindow withCommands:(NSArray<MPCommandItem *> *)commands
{
    // Create a panel-style window
    NSRect parentFrame = parentWindow.frame;
    CGFloat panelHeight = 44 + MIN(commands.count, kPaletteMaxVisibleRows) * kPaletteRowHeight;
    CGFloat x = parentFrame.origin.x + (parentFrame.size.width - kPaletteWidth) / 2;
    CGFloat y = parentFrame.origin.y + parentFrame.size.height - panelHeight - 80;
    NSRect frame = NSMakeRect(x, y, kPaletteWidth, panelHeight);

    NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView
        backing:NSBackingStoreBuffered defer:NO];
    panel.titleVisibility = NSWindowTitleHidden;
    panel.titlebarAppearsTransparent = YES;
    panel.movableByWindowBackground = YES;
    panel.level = NSFloatingWindowLevel;
    panel.becomesKeyOnlyIfNeeded = NO;

    MPCommandPalette *controller = [[MPCommandPalette alloc] initWithWindow:panel];
    controller.allCommands = commands;
    controller.filteredCommands = commands;

    // Search field
    controller.searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(12, panelHeight - 36, kPaletteWidth - 24, 28)];
    controller.searchField.placeholderString = @"Type a command...";
    controller.searchField.font = [NSFont systemFontOfSize:16];
    controller.searchField.bezelStyle = NSTextFieldRoundedBezel;
    controller.searchField.focusRingType = NSFocusRingTypeNone;
    controller.searchField.delegate = controller;
    [panel.contentView addSubview:controller.searchField];

    // Table in scroll view
    CGFloat tableHeight = panelHeight - 44;
    controller.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, kPaletteWidth, tableHeight)];
    controller.scrollView.hasVerticalScroller = YES;
    controller.scrollView.autohidesScrollers = YES;
    controller.scrollView.borderType = NSNoBorder;

    controller.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    controller.tableView.headerView = nil;
    controller.tableView.rowHeight = kPaletteRowHeight;
    controller.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    controller.tableView.dataSource = controller;
    controller.tableView.delegate = controller;
    controller.tableView.doubleAction = @selector(executeSelected:);
    controller.tableView.target = controller;

    NSTableColumn *titleCol = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    titleCol.width = kPaletteWidth - 120;
    [controller.tableView addTableColumn:titleCol];

    NSTableColumn *shortcutCol = [[NSTableColumn alloc] initWithIdentifier:@"shortcut"];
    shortcutCol.width = 100;
    [controller.tableView addTableColumn:shortcutCol];

    controller.scrollView.documentView = controller.tableView;
    [panel.contentView addSubview:controller.scrollView];

    if (controller.filteredCommands.count > 0)
        [controller.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

    // Keep controller alive while panel is visible
    objc_setAssociatedObject(panel, "controller", controller, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [parentWindow addChildWindow:panel ordered:NSWindowAbove];
    [panel makeKeyAndOrderFront:nil];
    [panel makeFirstResponder:controller.searchField];

    // Close on escape or losing focus
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification
        object:panel queue:nil usingBlock:^(NSNotification *note) {
            [panel.parentWindow removeChildWindow:panel];
            [panel orderOut:nil];
        }];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSString *query = self.searchField.stringValue.lowercaseString;
    if (query.length == 0)
    {
        self.filteredCommands = self.allCommands;
    }
    else
    {
        NSMutableArray *filtered = [NSMutableArray array];
        for (MPCommandItem *cmd in self.allCommands)
        {
            if ([cmd.title.lowercaseString containsString:query])
                [filtered addObject:cmd];
        }
        self.filteredCommands = filtered;
    }
    [self.tableView reloadData];
    if (self.filteredCommands.count > 0)
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(moveDown:))
    {
        NSInteger row = self.tableView.selectedRow + 1;
        if (row < (NSInteger)self.filteredCommands.count)
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        return YES;
    }
    if (commandSelector == @selector(moveUp:))
    {
        NSInteger row = self.tableView.selectedRow - 1;
        if (row >= 0)
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:))
    {
        [self executeSelected:nil];
        return YES;
    }
    if (commandSelector == @selector(cancelOperation:))
    {
        [self.window.parentWindow removeChildWindow:self.window];
        [self.window orderOut:nil];
        return YES;
    }
    return NO;
}

- (void)executeSelected:(id)sender
{
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.filteredCommands.count)
        return;

    MPCommandItem *cmd = self.filteredCommands[row];
    NSWindow *parent = self.window.parentWindow;

    [parent removeChildWindow:self.window];
    [self.window orderOut:nil];

    if (cmd.target && cmd.action)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [cmd.target performSelector:cmd.action withObject:nil];
#pragma clang diagnostic pop
    }
}


#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.filteredCommands.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    MPCommandItem *cmd = self.filteredCommands[row];
    NSString *identifier = tableColumn.identifier;

    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = identifier;
        NSTextField *tf = [NSTextField labelWithString:@""];
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:tf];
        cell.textField = tf;
        [NSLayoutConstraint activateConstraints:@[
            [tf.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
            [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    if ([identifier isEqualToString:@"title"])
    {
        NSString *prefix = cmd.isOn ? @"\u2713  " : @"";
        cell.textField.stringValue = [prefix stringByAppendingString:cmd.title];
        cell.textField.font = [NSFont systemFontOfSize:13];
    }
    else
    {
        cell.textField.stringValue = cmd.shortcut ?: @"";
        cell.textField.font = [NSFont systemFontOfSize:11];
        cell.textField.textColor = [NSColor secondaryLabelColor];
        cell.textField.alignment = NSTextAlignmentRight;
    }

    return cell;
}

@end
