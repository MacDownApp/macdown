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


static NSString *const kMPToolbarDictKeyOrder = @"kMPToolbarDictKeyOrder";
static NSString *const kMPToolbarDictKeyIcon = @"kMPToolbarDictKeyIcon";
static NSString *const kMPToolbarDictKeyTitle = @"kMPToolbarDictKeyTitle";
static NSString *const kMPToolbarDictKeySubItems = @"kMPToolbarDictKeySubItems";
static NSString *const kMPToolbarDictKeySegmentStyleSeparated = @"kMPToolbarDictKeySegmentStyleSeparated";
static NSString *const kMPToolbarDictKeyAction = @"kMPToolbarDictKeyAction";


@implementation MPToolbarController
{
    NSDictionary *toolbarItems;
    NSArray *toolbarItemKeysOrder;
    
    NSMutableDictionary *toolbarGroupItemsDictionary;
    
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
    
    [self setupToolbarItems];
    self->toolbarItemIdentifierObjectDictionary = [NSMutableDictionary new];
    
    return self;
}

- (void)setupToolbarItems
{
    // NSToolbarItem identifier as key
    self->toolbarItems = @{
                           @"indent-group": @{
                                   kMPToolbarDictKeyOrder: @0,
                                   kMPToolbarDictKeySegmentStyleSeparated: @YES,
                                   kMPToolbarDictKeySubItems: @{
                                           @"shift-left": @{
                                                   kMPToolbarDictKeyOrder: @0,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconShiftLeft",
                                                   kMPToolbarDictKeyTitle: @"Shift left",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(unindent:)],
                                                   },
                                           @"shift-right": @{
                                                   kMPToolbarDictKeyOrder: @1,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconShiftRight",
                                                   kMPToolbarDictKeyTitle: @"Shift right",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(indent:)],
                                                   },
                                           }
                                   },
                           @"text-formatting-group": @{
                                   kMPToolbarDictKeyOrder: @1,
                                   kMPToolbarDictKeySegmentStyleSeparated: @NO,
                                   kMPToolbarDictKeySubItems: @{
                                           @"bold": @{
                                                   kMPToolbarDictKeyOrder: @0,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconBold",
                                                   kMPToolbarDictKeyTitle: @"Bold",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleStrong:)],
                                                   },
                                           @"italic": @{
                                                   kMPToolbarDictKeyOrder: @1,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconItalic",
                                                   kMPToolbarDictKeyTitle: @"Italic",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleEmphasis:)],
                                                   },
                                           @"underline": @{
                                                   kMPToolbarDictKeyOrder: @2,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconUnderlined",
                                                   kMPToolbarDictKeyTitle: @"Underline",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleUnderline:)],
                                                   },
                                           }
                                   },
                           @"heading-group": @{
                                   kMPToolbarDictKeyOrder: @2,
                                   kMPToolbarDictKeySegmentStyleSeparated: @YES,
                                   kMPToolbarDictKeySubItems: @{
                                           @"heading1": @{
                                                   kMPToolbarDictKeyOrder: @0,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconHeading1",
                                                   kMPToolbarDictKeyTitle: @"Heading 1",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(convertToH1:)],
                                                   },
                                           @"heading2": @{
                                                   kMPToolbarDictKeyOrder: @1,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconHeading2",
                                                   kMPToolbarDictKeyTitle: @"Heading 2",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(convertToH2:)],
                                                   },
                                           @"heading3": @{
                                                   kMPToolbarDictKeyOrder: @2,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconHeading3",
                                                   kMPToolbarDictKeyTitle: @"Heading 3",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(convertToH3:)],
                                                   },
                                           }
                                   },
                           @"list-group": @{
                                   kMPToolbarDictKeyOrder: @3,
                                   kMPToolbarDictKeySegmentStyleSeparated: @YES,
                                   kMPToolbarDictKeySubItems: @{
                                           @"unordered-list": @{
                                                   kMPToolbarDictKeyOrder: @0,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconUnorderedList",
                                                   kMPToolbarDictKeyTitle: @"Unordered list",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleUnorderedList:)],
                                                   },
                                           @"ordered-list": @{
                                                   kMPToolbarDictKeyOrder: @1,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconOrderedList",
                                                   kMPToolbarDictKeyTitle: @"Ordered list",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleOrderedList:)],
                                                   }
                                           }
                                   },
                           @"blockquote": @{
                                   kMPToolbarDictKeyOrder: @4,
                                   kMPToolbarDictKeyIcon: @"ToolbarIconBlockquote",
                                   kMPToolbarDictKeyTitle: @"Blockquote",
                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleBlockquote:)],
                                   },
                           @"code": @{
                                   kMPToolbarDictKeyOrder: @5,
                                   kMPToolbarDictKeyIcon: @"ToolbarIconInlineCode",
                                   kMPToolbarDictKeyTitle: @"Inline code",
                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleInlineCode:)],
                                   },
                           @"link": @{
                                   kMPToolbarDictKeyOrder: @6,
                                   kMPToolbarDictKeyIcon: @"ToolbarIconLink",
                                   kMPToolbarDictKeyTitle: @"Link",
                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleLink:)],
                                   },
                           @"image": @{
                                   kMPToolbarDictKeyOrder: @7,
                                   kMPToolbarDictKeyIcon: @"ToolbarIconImage",
                                   kMPToolbarDictKeyTitle: @"Inline code",
                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleImage:)],
                                   },
                           @"copy-html": @{
                                   kMPToolbarDictKeyOrder: @8,
                                   kMPToolbarDictKeyIcon: @"ToolbarIconCopyHTML",
                                   kMPToolbarDictKeyTitle: @"Copy HTML",
                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(copyHtml:)],
                                   },
                           @"toggle-panes-group": @{
                                   kMPToolbarDictKeyOrder: @9,
                                   kMPToolbarDictKeySegmentStyleSeparated: @NO,
                                   kMPToolbarDictKeySubItems: @{
                                           @"toggle-editor-pane": @{
                                                   kMPToolbarDictKeyOrder: @0,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconHideEditor",
                                                   kMPToolbarDictKeyTitle: @"Toggle editor pane",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(toggleEditorPane:)],
                                                   },
                                           @"toggle-preview-pane": @{
                                                   kMPToolbarDictKeyOrder: @1,
                                                   kMPToolbarDictKeyIcon: @"ToolbarIconHidePreview",
                                                   kMPToolbarDictKeyTitle: @"Toggle preview pane",
                                                   kMPToolbarDictKeyAction: [NSValue valueWithPointer:@selector(togglePreviewPane:)],
                                                   },
                                           }
                                   },
                           };
}

/**
 * Creates an array with ordered keys from the passed argument dictionary which should be from the hierarchical dictionary produced by setupToolbarItems.
 *
 * @returns Ordered keys(identifiers)
 */
- (NSArray *)orderedToolbarItemKeysForDictionary:(NSDictionary *)dictionary
{
    NSMutableArray *orderedKeys = [NSMutableArray new];
    
    // Fill with required capacity
    for (int i = 0; i < dictionary.count; i++)
    {
        orderedKeys[i] = [NSNull null];
    }
    
    for (NSDictionary *itemKey in dictionary)
    {
        NSDictionary *itemDictionary = dictionary[itemKey];
        NSInteger index = [itemDictionary[kMPToolbarDictKeyOrder] integerValue];
        orderedKeys[index] = itemKey;
    }
    
    return [orderedKeys copy];
}


#pragma mark - NSToolbarDelegate
- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    // From toolbar item dictionary(setupToolbarItems)
    NSArray *orderedToolbarItemIdentifiers = [self orderedToolbarItemKeysForDictionary:self->toolbarItems];
    
    // Mixed identifiers from dictionary and spacing at below specified indices
    NSMutableArray *defaultItemIdentifiers = [NSMutableArray new];
    
    // Add spacing after the specified toolbar item indices
    int spacingAfterIndices[] = {2,3,5,7};
    int i = 0;
    int j = 0;
    
    for (NSString *itemIdentifier in orderedToolbarItemIdentifiers)
    {
        [defaultItemIdentifiers addObject:itemIdentifier];
        if (i == spacingAfterIndices[j])
        {
            [defaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
            
            j++;
        }
        
        i++;
    }
    
    return [defaultItemIdentifiers copy];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    static CGFloat itemWidth = 42.5;
    
    NSDictionary *itemDict = self->toolbarItems[itemIdentifier];
    
    if (itemDict)
    {
        NSDictionary *subItemDicts = itemDict[kMPToolbarDictKeySubItems];
        
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        
        if (subItemDicts == nil) // It's a regular toolbar item
        {
            NSString *title = itemDict[kMPToolbarDictKeyTitle];
            NSString *iconName = itemDict[kMPToolbarDictKeyIcon];
            SEL itemSelector = [itemDict[kMPToolbarDictKeyAction] pointerValue];
            
            item.label = title;
            
            NSImage *itemImage = [NSImage imageNamed:iconName];
            [itemImage setTemplate:YES];
            NSButton *itemButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, itemWidth, 40)];
            [itemButton setButtonType:NSToggleButton];
            itemButton.image = itemImage;
            itemButton.bezelStyle = NSBezelStyleTexturedRounded;
            itemButton.focusRingType = NSFocusRingTypeDefault;
            itemButton.target = self.document;
            itemButton.action = itemSelector;
            itemButton.state = NSOffState;
            
            item.view = itemButton;
            
            [self->toolbarItemIdentifierObjectDictionary setObject:item forKey:itemIdentifier];
            
            return item;
        }
        else // It's a segment control
        {
            NSToolbarItemGroup *itemGroup = [[NSToolbarItemGroup alloc] initWithItemIdentifier:itemIdentifier];
            
            BOOL segmentStyleSeparated = [itemDict[kMPToolbarDictKeySegmentStyleSeparated] boolValue];
            
            NSSegmentedControl *segmentedControl = [[NSSegmentedControl alloc] init];
            segmentedControl.identifier = itemIdentifier;
            segmentedControl.target = self;
            segmentedControl.segmentStyle = segmentStyleSeparated ?
                                            NSSegmentStyleSeparated : NSSegmentStyleTexturedRounded;
            segmentedControl.trackingMode = NSSegmentSwitchTrackingSelectAny;
            segmentedControl.segmentCount = subItemDicts.count;
            
            NSMutableArray *itemGroupItems = [NSMutableArray new];
            
            NSArray *orderedSubItemIdentifers = [self orderedToolbarItemKeysForDictionary:subItemDicts];
            int segmentIndex = 0;
            
            for (NSString *subItemIdentifier in orderedSubItemIdentifers)
            {
                NSDictionary *subItemDict = subItemDicts[subItemIdentifier];
                NSString *subItemTitle = subItemDict[kMPToolbarDictKeyTitle];
                NSString *subItemIcon = subItemDict[kMPToolbarDictKeyIcon];
                SEL subItemSelector = [subItemDicts[kMPToolbarDictKeyAction] pointerValue];
                
                NSToolbarItem *subItem = [[NSToolbarItem alloc] initWithItemIdentifier:subItemIdentifier];
                
                subItem.label = subItemTitle;
                subItem.target = self.document;
                subItem.action = subItemSelector;
                
                NSImage *subItemImage = [NSImage imageNamed:subItemIcon];
                [subItemImage setTemplate:YES];
                
                [segmentedControl setImage:subItemImage forSegment:segmentIndex];
                [segmentedControl setWidth:40.0 forSegment:segmentIndex];
                
                [itemGroupItems addObject:subItem];
                segmentIndex++;
            }
            
            CGFloat itemGroupWidth = itemWidth * itemGroupItems.count;
            
            itemGroup.subitems = [itemGroupItems copy];
            itemGroup.view = segmentedControl;
            itemGroup.maxSize = NSMakeSize(itemGroupWidth, 25);
            itemGroup.target = self;
            itemGroup.action = @selector(selectedToolbarItemGroupItem:);
            
            [self->toolbarItemIdentifierObjectDictionary setObject:itemGroup forKey:itemIdentifier];
            
            return itemGroup;
        }
    }
    
    return nil;
}

- (void)selectedToolbarItemGroupItem:(NSSegmentedControl *)sender
{
    NSInteger selectedIndex = sender.selectedSegment;
    
    NSDictionary *groupDictionary = self->toolbarItems[sender.identifier];
    NSDictionary *groupSubItemsDictionary = groupDictionary[kMPToolbarDictKeySubItems];
    NSDictionary *selectedItemDictionary = [groupSubItemsDictionary allValues][selectedIndex];
    
    // Invoke the toolbar item's action
    // Must convert to IMP to let the compiler know about the method definition
    SEL selectedItemAction = [selectedItemDictionary[kMPToolbarDictKeyAction] pointerValue];
    MPDocument *document = self.document;
    IMP imp = [document methodForSelector:selectedItemAction];
    void (*impFunc)(id) = (void *)imp;
    impFunc(document);
}


@end
