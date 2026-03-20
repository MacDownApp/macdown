//
//  MPDocument.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;


@interface MPDocument : NSDocument

@property (nonatomic, readonly) MPPreferences *preferences;
@property (readonly) BOOL previewVisible;
@property (readonly) BOOL editorVisible;

@property (nonatomic, readwrite) NSString *markdown;
@property (nonatomic, readonly) NSString *html;

- (IBAction)showEditorOnly:(id)sender;
- (IBAction)showPreviewOnly:(id)sender;
- (IBAction)showBothPanes:(id)sender;
- (IBAction)toggleSidebar:(id)sender;
- (IBAction)toggleFocusMode:(id)sender;
- (IBAction)toggleTypewriterMode:(id)sender;
- (IBAction)exportToDOCX:(id)sender;
- (IBAction)showCommandPalette:(id)sender;
- (IBAction)toggleProseAnalysis:(id)sender;

@end
