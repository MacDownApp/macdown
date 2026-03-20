//
//  MPCommandPalette.h
//  Markly
//

#import <Cocoa/Cocoa.h>

@interface MPCommandItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *shortcut;
@property (nonatomic) SEL action;
@property (nonatomic, weak) id target;
@property (nonatomic) BOOL isOn;
+ (MPCommandItem *)itemWithTitle:(NSString *)title shortcut:(NSString *)shortcut action:(SEL)action target:(id)target;
+ (MPCommandItem *)toggleWithTitle:(NSString *)title shortcut:(NSString *)shortcut action:(SEL)action target:(id)target isOn:(BOOL)isOn;
@end

@interface MPCommandPalette : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

+ (void)showForWindow:(NSWindow *)parentWindow withCommands:(NSArray<MPCommandItem *> *)commands;

@end
