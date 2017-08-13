//
//  MPToolbarController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-02-12.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPToolbarController.h"

// Because we're creating selectors for methods which aren't in this class
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wundeclared-selector"


static CGFloat itemWidth = 42.5;


@implementation MPToolbarController
{
    NSArray *toolbarItems;
    NSArray *toolbarItemIdentifiers;
    
    /**
     * Map toolbar item identifier to it's NSToolbarItem or NSToolbarItemGroup object
     */
    NSMutableDictionary *toolbarItemIdentifierObjectDictionary;
}

- (id)init
{
    self = [super init];
    
    if (!self)
    {
        return nil;
    }
    
    self->toolbarItemIdentifierObjectDictionary = [NSMutableDictionary new];
    [self setupToolbarItems];
    
    return self;
}


#pragma mark - Private

- (void)setupToolbarItems
{
    // Set up layout drop down alternatives. title will be set in validateUserInterfaceItem:
    NSMenuItem *toggleEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleEditorPane:) keyEquivalent:@"e"];
    NSMenuItem *togglePreviewMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(togglePreviewPane:) keyEquivalent:@"p"];
    
    // Set up all available toolbar items
    self->toolbarItems = @[
        [self toolbarItemGroupWithIdentifier:@"indent-group" separated:YES items:@[
            [self toolbarItemWithIdentifier:@"shift-left" label:NSLocalizedString(@"Shift left", @"Shift text to the left toolbar button") icon:@"ToolbarIconShiftLeft" action:@selector(unindent:)],
            [self toolbarItemWithIdentifier:@"shift-right" label:NSLocalizedString(@"Shift right", @"Shift text to the right toolbar button") icon:@"ToolbarIconShiftRight" action:@selector(indent:)]
            ]
        ],
        [self toolbarItemGroupWithIdentifier:@"text-formatting-group" separated:NO items:@[
            [self toolbarItemWithIdentifier:@"bold" label:NSLocalizedString(@"Strong", @"Strong toolbar button") icon:@"ToolbarIconBold" action:@selector(toggleStrong:)],
            [self toolbarItemWithIdentifier:@"italic" label:NSLocalizedString(@"Emphasize", @"Emphasize toolbar button") icon:@"ToolbarIconItalic" action:@selector(toggleEmphasis:)],
            [self toolbarItemWithIdentifier:@"underline" label:NSLocalizedString(@"Underline", @"Underline toolbar button") icon:@"ToolbarIconUnderlined" action:@selector(toggleUnderline:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"heading-group" separated:NO items:@[
            [self toolbarItemWithIdentifier:@"heading1" label:NSLocalizedString(@"Heading 1", @"Heading 1 toolbar button") icon:@"ToolbarIconHeading1" action:@selector(convertToH1:)],
            [self toolbarItemWithIdentifier:@"heading2" label:NSLocalizedString(@"Heading 2", @"Heading 2 toolbar button") icon:@"ToolbarIconHeading2" action:@selector(convertToH2:)],
            [self toolbarItemWithIdentifier:@"heading3" label:NSLocalizedString(@"Heading 3", @"Heading 3 toolbar button") icon:@"ToolbarIconHeading3" action:@selector(convertToH3:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"list-group" separated:YES items:@[
            [self toolbarItemWithIdentifier:@"unordered-list" label:NSLocalizedString(@"Unordered list", @"Unordered list toolbar button") icon:@"ToolbarIconUnorderedList" action:@selector(toggleUnorderedList:)],
            [self toolbarItemWithIdentifier:@"ordered-list" label:NSLocalizedString(@"Ordered list", @"Ordered list toolbar button") icon:@"ToolbarIconOrderedList" action:@selector(toggleOrderedList:)]
            ]
         ],
        [self toolbarItemWithIdentifier:@"blockquote" label:NSLocalizedString(@"Blockquote", @"Blockquote toolbar button") icon:@"ToolbarIconBlockquote" action:@selector(toggleBlockquote:)],
        [self toolbarItemWithIdentifier:@"code" label:NSLocalizedString(@"Inline code", @"Inline code toolbar button") icon:@"ToolbarIconInlineCode" action:@selector(toggleInlineCode:)],
        [self toolbarItemWithIdentifier:@"link" label:NSLocalizedString(@"Link", @"Link toolbar button") icon:@"ToolbarIconLink" action:@selector(toggleLink:)],
        [self toolbarItemWithIdentifier:@"image" label:NSLocalizedString(@"Image", @"Image toolbar button") icon:@"ToolbarIconImage" action:@selector(toggleImage:)],
        [self toolbarItemWithIdentifier:@"copy-html" label:NSLocalizedString(@"Copy HTML", @"Copy HTML toolbar button") icon:@"ToolbarIconCopyHTML" action:@selector(copyHTML:)],
        [self toolbarItemWithIdentifier:@"comment" label:NSLocalizedString(@"Comment", @"Comment toolbar button") icon:@"ToolbarIconComment" action:@selector(toggleComment:)],
        [self toolbarItemWithIdentifier:@"highlight" label:NSLocalizedString(@"Highlight", @"Highlight toolbar button") icon:@"ToolbarIconHighlight" action:@selector(toggleHighlight:)],
        [self toolbarItemWithIdentifier:@"strikethrough" label:NSLocalizedString(@"Strikethrough", @"Strikethrough toolbar button") icon:@"ToolbarIconStrikethrough" action:@selector(toggleStrikethrough:)],
        [self toolbarItemDropDownWithIdentifier:@"layout" label:NSLocalizedString(@"Layout", @"Layout toolbar button") icon:@"ToolbarIconHidePreview" menuItems:
            @[
              toggleEditorMenuItem, togglePreviewMenuItem
            ]
        ]
    ];
    
    self->toolbarItemIdentifiers = [self toolbarItemIdentifiersFromItemsArray:self->toolbarItems];
}

/**
 * Returns an array with all item identifiers for the toolbar items in the passed in _toolbarItemsArray_.
 */
- (NSArray *)toolbarItemIdentifiersFromItemsArray:(NSArray *)toolbarItemsArray {
    NSMutableArray *orderedIdentifiers = [NSMutableArray new];
    
    for (NSToolbarItem *item in self->toolbarItems) {
        [orderedIdentifiers addObject:item.itemIdentifier];
    }
    
    return [orderedIdentifiers copy];
}

- (void)selectedToolbarItemGroupItem:(NSSegmentedControl *)sender
{
    NSInteger selectedIndex = sender.selectedSegment;
    
    NSToolbarItemGroup *selectedGroup = self->toolbarItemIdentifierObjectDictionary[sender.identifier];
    NSToolbarItem *selectedItem = selectedGroup.subitems[selectedIndex];
    
    // Invoke the toolbar item's action
    // Must convert to IMP to let the compiler know about the method definition
    MPDocument *document = self.document;
    IMP imp = [document methodForSelector:selectedItem.action];
    void (*impFunc)(id) = (void *)imp;
    impFunc(document);
}


#pragma mark - NSToolbarDelegate
- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    // From toolbar item dictionary(setupToolbarItems)
    //NSArray *orderedToolbarItemIdentifiers = [self orderedToolbarDefaultItemKeysForDictionary:self->toolbarItems];
    NSArray *orderedToolbarItemIdentifiers = [self toolbarItemIdentifiersFromItemsArray:self->toolbarItems];
    
    // Mixed identifiers from dictionary and space at below specified indices
    NSMutableArray *defaultItemIdentifiers = [NSMutableArray new];
    
    // Add space after the specified toolbar item indices
    int spaceAfterIndices[] = {}; // No space in the default set
    int flexibleSpaceAfterIndices[] = {2, 3, 5, 7, 11};
    int i = 0;
    int j = 0;
    int k = 0;
    
    for (NSString *itemIdentifier in orderedToolbarItemIdentifiers)
    {
        [defaultItemIdentifiers addObject:itemIdentifier];
        
        if (i == spaceAfterIndices[j])
        {
            [defaultItemIdentifiers addObject:NSToolbarSpaceItemIdentifier];
            j++;
        }
        
        if (i == flexibleSpaceAfterIndices[k])
        {
            [defaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
            k++;
        }
        
        i++;
    }
    
    return [defaultItemIdentifiers copy];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return self->toolbarItemIdentifiers;
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item;
    
    for (NSToolbarItem *currentItem in self->toolbarItems) {
        if ([currentItem.itemIdentifier isEqualToString:itemIdentifier]) {
            item = currentItem;
            break;
        }
    }
    
    return item;
}


#pragma mark - Toolbar item factory methods

/**
 * Factory method for creating and configuring a NSToolbarItemGroup object.
 */
- (NSToolbarItemGroup *)toolbarItemGroupWithIdentifier:(NSString *)itemIdentifier separated:(BOOL)separated items:(NSArray <NSToolbarItem *>*)items {
    NSToolbarItemGroup *itemGroup = [[NSToolbarItemGroup alloc] initWithItemIdentifier:itemIdentifier];
    itemGroup.subitems = items;
    
    CGFloat itemGroupWidth = itemWidth * items.count;
    
    NSSegmentedControl *segmentedControl = [[NSSegmentedControl alloc] init];
    segmentedControl.identifier = itemIdentifier;
    segmentedControl.segmentStyle = separated ? NSSegmentStyleSeparated : NSSegmentStyleTexturedRounded;
    segmentedControl.trackingMode = NSSegmentSwitchTrackingMomentary;
    segmentedControl.segmentCount = items.count;
    segmentedControl.target = self;
    segmentedControl.action = @selector(selectedToolbarItemGroupItem:);
    
    int segmentIndex = 0;
    
    for (NSToolbarItem *subItem in items)
    {
        [segmentedControl setImage:subItem.image forSegment:segmentIndex];
        [segmentedControl setWidth:40.0 forSegment:segmentIndex];
        
        segmentIndex++;
    }
    
    itemGroup.maxSize = NSMakeSize(itemGroupWidth, 25);
    itemGroup.view = segmentedControl;
    
    [self->toolbarItemIdentifierObjectDictionary setObject:itemGroup forKey:itemIdentifier];
    
    return itemGroup;
}

/**
 * Factory method for creating and configuring a NSToolbarItem object.
 */
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)itemIdentifier label:(NSString *)label icon:(NSString *)iconImageName action:(SEL)action {
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    toolbarItem.label = label;
    
    NSImage *itemImage = [NSImage imageNamed:iconImageName];
    [itemImage setTemplate:YES];
    NSButton *itemButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, itemWidth, 40)];
    itemButton.image = itemImage;
    itemButton.bezelStyle = NSBezelStyleTexturedRounded;
    itemButton.focusRingType = NSFocusRingTypeDefault;
    itemButton.target = self.document;
    itemButton.action = action;
    
    toolbarItem.view = itemButton;
    
    [self->toolbarItemIdentifierObjectDictionary setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}

/**
 * Factory method for creating and configuring a NSToolbarItem object with a NSPopupButton holding menu options as passed in the menuItems parameter.
 */
- (NSToolbarItem *)toolbarItemDropDownWithIdentifier:(NSString *)itemIdentifier label:(NSString *)label icon:(NSString *)iconImageName menuItems:(NSArray <NSMenuItem *>*)menuItems {
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    toolbarItem.label = label;
    
    NSImage *itemImage = [NSImage imageNamed:iconImageName];
    [itemImage setTemplate:YES];
    
    NSPopUpButton *popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, itemWidth, 40) pullsDown:YES];
    popupButton.bezelStyle = NSBezelStyleTexturedRounded;
    popupButton.focusRingType = NSFocusRingTypeDefault;
    
    // First item's image is displayed as button image, therefor we need a dummy with the icon
    [popupButton addItemWithTitle:@""];
    [[popupButton lastItem] setImage:itemImage];
    
    for (NSMenuItem *menuItem in menuItems) {
        [popupButton addItemWithTitle:menuItem.title];
        [[popupButton lastItem] setTarget:self.document];
        [[popupButton lastItem] setAction:menuItem.action];
    }
    
    toolbarItem.view = popupButton;
    
    [self->toolbarItemIdentifierObjectDictionary setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}


@end
