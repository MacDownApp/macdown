//
//  MPOpenQuicklyWindowController.m
//  MacDown - Basically ripped from XCActionBar
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPOpenQuicklyWindowController.h"
#import "MPOpenQuicklyDataSource.h"
#import "MPOpenQuicklyTableCellView.h"

NSString *MPMinimalStringForAbsoluteFilePathString(NSString *path) {
    NSString *currentUserHomeDirectory = NSHomeDirectory();
    return [path stringByReplacingOccurrencesOfString:currentUserHomeDirectory withString:@"~"];
}

@interface MPOpenQuicklyWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate>

@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSTableView *searchResultsTable;

@property (weak) IBOutlet NSTextField *overviewTextField;
@property (weak) IBOutlet NSTextField *resultsTextField;

@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSLayoutConstraint *resultsTrailingEdgeConstraint;

@property (nonatomic, copy) NSArray *searchResults;
@property (nonatomic, strong) MPOpenQuicklyDataSource *dataSource;

@end

@implementation MPOpenQuicklyWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;

    // Gives a Yosemite-style toolbar
    if ([self.window respondsToSelector:@selector(setTitleVisibility:)]) {
        self.window.titleVisibility = NSWindowTitleHidden;
    }

    self.searchField.focusRingType = NSFocusRingTypeNone;
    self.searchField.delegate      = self;
    self.searchField.nextResponder = self;

    self.searchResultsTable.rowSizeStyle            = NSTableViewRowSizeStyleCustom;
    self.searchResultsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    self.searchResultsTable.rowHeight               = 60;

    self.searchResultsTable.target       = self;
    self.searchResultsTable.doubleAction = @selector(processDoubleClickOnSearchResult:);

    [self updateSearchResults:@[@"one", @"two", @"three"]];
    [self updateOverviewForRecentFiles];

    [self centerWindow];
    [self.window setDelegate:self];
    [self.window makeFirstResponder:self.searchField];
}

- (void)centerWindow
{
    NSWindow *window = self.window;
    CGFloat xPos = NSWidth(window.screen.frame)/2 - NSWidth(window.frame)/2;
    CGFloat yPos = NSHeight(window.screen.frame)/2 - NSHeight(window.frame)/2;
    [window setFrame:NSMakeRect(xPos, yPos, NSWidth(window.frame), NSHeight(window.frame)) display:YES];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    self.resultsTextField.stringValue = @"Processing";
    [self showProcessing:YES];

    self.dataSource = [[MPOpenQuicklyDataSource alloc] initWithDirectoryPath:self.pathForSearching initialCompletion:^(NSArray *results) {
        [self showProcessing:NO];
        [self updateSearchResults:results];
        self.resultsTextField.stringValue = [NSString stringWithFormat:@"%@ documents", @(results.count)];
    }];
    [self.window makeFirstResponder:self.searchField];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self close];
}

#pragma mark - Visuals

- (void)updateOverviewForRecentFiles
{
    NSString *path = MPMinimalStringForAbsoluteFilePathString(self.pathForSearching);
    self.overviewTextField.stringValue = [NSString stringWithFormat:@"Recent files from %@", path];
}

- (void)showProcessing:(BOOL)show
{
    if (show) {
        [self.progressIndicator startAnimation:self];
    } else {
        [self.progressIndicator stopAnimation:self];
    }

    self.resultsTrailingEdgeConstraint.constant = 12 + (16 * show);
    [self.resultsTextField setNeedsUpdateConstraints:YES];
    [self.resultsTextField updateConstraints];
}

#pragma mark - NSTextDelegate

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textField = notification.object;

    if (textField.stringValue.length == 0) {
        [self updateOverviewForRecentFiles];
        return;
    }

    [self showProcessing:YES];

    [self.dataSource searchForQuery:textField.stringValue :^(NSArray *results) {
        [self updateSearchResults:results];
        [self showProcessing:NO];
        self.resultsTextField.stringValue = [NSString stringWithFormat:@"found %@ documents", @(results.count)];
    }];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(moveUp:)) {
        [self.searchResultsTable keyDown:[NSApp currentEvent]];
        return YES;

    } else if(commandSelector == @selector(moveDown:)){
        [self.searchResultsTable keyDown:[NSApp currentEvent]];
        return YES;

    } else if(commandSelector == @selector(insertNewline:)){
        [self openCurrentlySelectedRow];
        return YES;
    }

    return NO;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return self.searchResults.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return self.searchResults[rowIndex];
}

#pragma mark - NSTableViewDelegates

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    MPOpenQuicklyTableCellView *cell = [tableView makeViewWithIdentifier:NSStringFromClass([MPOpenQuicklyTableCellView class]) owner:self];

    NSString *action = self.searchResults[row];
    cell.textField.allowsEditingTextAttributes = YES;

    cell.textField.stringValue = action.lastPathComponent;
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
    NSTableView *tableView = notification.object;
    MPOpenQuicklyTableCellView *cell = [tableView viewAtColumn:0 row:tableView.selectedRow makeIfNecessary:NO];
    if (cell) {
        NSURL *selectedURL = self.searchResults[tableView.selectedRow];
        NSIndexSet *indexes = [self.dataSource queryResultsIndexesOnQuery:self.searchField.stringValue fileURL:selectedURL];
        [cell highlightTitleWithIndexes:indexes];

    }
}

- (void)processDoubleClickOnSearchResult:(NSTableView *)tableView
{
    [self openCurrentlySelectedRow];
}

- (void)openCurrentlySelectedRow
{
    NSUInteger index = self.searchResultsTable.selectedRowIndexes.firstIndex;
    NSURL *url = self.searchResults[index];
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {

    }];
}

#pragma mark - Public Methods

- (void)updateSearchResults:(NSArray *)results
{
    self.searchResults = results;
    [self.searchResultsTable reloadData];
}

- (void)clearSearchResults
{
    [self updateSearchResults:@[]];
}


@end
