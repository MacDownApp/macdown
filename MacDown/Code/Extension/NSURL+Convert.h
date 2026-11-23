//
//  NSURL+Convert.h
//  MacDown
//

#import <Foundation/Foundation.h>

@interface NSURL (Convert)

/// The absolute URL string without query string and fragment.
- (NSString *)absoluteBaseURLString;

@end
