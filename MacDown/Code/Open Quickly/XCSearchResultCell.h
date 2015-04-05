//
//  XCSearchResultCell.h
//  XCActionBar
//
//  Created by Pedro Gomes on 12/03/2015.
//  Copyright (c) 2015 Pedro Gomes. All rights reserved.
//

#import <Cocoa/Cocoa.h>

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface XCSearchResultCell : NSTableCellView

@property (strong) IBOutlet NSTextField *hintTextField;
@property (strong) IBOutlet NSTextField *subtitleTextField;

@end
