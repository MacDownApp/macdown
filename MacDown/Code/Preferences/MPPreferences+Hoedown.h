//
//  MPPreferences+Hoedown.h
//  MacDown
//

#import "MPPreferences.h"

/// Maps preferences to Hoedown flag values. Removed with Hoedown in Phase 2.
@interface MPPreferences (Hoedown)

- (int)extensionFlags;
- (int)rendererFlags;

@end
