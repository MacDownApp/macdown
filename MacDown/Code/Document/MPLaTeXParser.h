#ifndef MPLaTeXParser_h
#define MPLaTeXParser_h

#import <Foundation/Foundation.h>

@interface MPLaTeXParser : NSObject

- (NSDictionary *)parseDocumentMetadata:(NSString *)texContent;
- (NSString *)extractPreamble:(NSString *)texContent;
- (BOOL)isStandaloneDocument:(NSString *)texContent;
- (NSString *)wrapContentAsStandalone:(NSString *)content preamble:(NSString *)preamble;
- (NSArray *)extractPackages:(NSString *)texContent;
- (NSArray *)extractDocumentclassOptions:(NSString *)texContent;

@end

#endif
