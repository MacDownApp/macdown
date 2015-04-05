//
//  MPOpenQuicklyWindowController.m
//  MacDown - Basically ripped from XCActionBar
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPOpenQuicklyWindowController.h"
#import "XCSearchResultCell.h"
#import "MPOpenQuicklyDataSource.h"

@interface MPOpenQuicklyWindowController () < NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate>

@property (weak) IBOutlet NSTextField *searchField;
@property (weak) IBOutlet NSTableView *searchResultsTable;
@property (weak) IBOutlet NSLayoutConstraint *searchFieldBottomConstraint;
@property (weak) IBOutlet NSLayoutConstraint *searchResultsTableHeightConstraint;
@property (weak) IBOutlet NSLayoutConstraint *searchResultsTableBottomConstraint;
@property (nonatomic) NSArray *searchResults;
@property (nonatomic) MPOpenQuicklyDataSource *dataSource;

@end

@implementation MPOpenQuicklyWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;


    self.searchField.focusRingType = NSFocusRingTypeNone;
    self.searchField.delegate      = self;
    self.searchField.nextResponder = self;

    self.searchResultsTable.rowSizeStyle            = NSTableViewRowSizeStyleCustom;
    self.searchResultsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    self.searchResultsTable.rowHeight               = 50.0;

    self.searchResultsTable.target       = self;
    self.searchResultsTable.doubleAction = @selector(processDoubleClickOnSearchResult:);

    [self updateSearchResults:@[@"one", @"two", @"three"]];

    NSWindow *window = self.window;
    CGFloat xPos = NSWidth([[window screen] frame])/2 - NSWidth([window frame])/2;
    CGFloat yPos = NSHeight([[window screen] frame])/2 - NSHeight([window frame])/2;
    [window setFrame:NSMakeRect(xPos, yPos, NSWidth([window frame]), NSHeight([window frame])) display:YES];

    [self.window setDelegate:self];
    [self.window makeFirstResponder:self.searchField];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    self.dataSource = [[MPOpenQuicklyDataSource alloc] initWithDirectoryPath:self.pathForSearching];
    [self.window makeFirstResponder:self.searchField];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self close];
}


#pragma mark - NSTextDelegate

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textField = notification.object;
    [self updateSearchResults:@[@"one", @"two", @"three"]];

    [self.dataSource searchForQuery:textField.stringValue :^(NSArray *results, NSError *error) {
        [self updateSearchResults:results];
    }];
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - NSTableViewDataSource

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return self.searchResults.count;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return self.searchResults[rowIndex];
}

#pragma mark - NSTableViewDelegate

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    XCSearchResultCell *cell = [tableView makeViewWithIdentifier:NSStringFromClass([XCSearchResultCell class]) owner:self];

    NSString *action = self.searchResults[row];
    cell.textField.allowsEditingTextAttributes = YES;

    cell.textField.stringValue = action;
    return cell;
}

#pragma mark - Public Methods


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)updateSearchResults:(NSArray *)results
{
    //    XCLog(@"<UpdatedSearchResults>, <results=%@>", results);

    self.searchResults = results;
    [self.searchResultsTable reloadData];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)clearSearchResults
{
    [self updateSearchResults:@[]];
}


@end
