//
//  MPJavaScriptHandler.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol MPJavaScriptHandlerDelegate;

@interface MPJavaScriptHandler : NSObject

@property (weak) id<MPJavaScriptHandlerDelegate> delegate;

- (void)checkboxWithId:(NSUInteger)boxId didChangeValue:(BOOL)checked;

@end


@protocol MPJavaScriptHandlerDelegate
- (void)checkboxWithId:(NSUInteger)boxId didChangeValue:(BOOL)checked;;
@end