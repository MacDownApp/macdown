#ifndef MPFileType_h
#define MPFileType_h

typedef NS_ENUM(NSUInteger, MPFileType) {
    MPFileTypeMarkdown,
    MPFileTypeRMarkdown,
    MPFileTypeLaTeX,
    MPFileTypeUnknown
};

@interface MPFileTypeHelper : NSObject
+ (MPFileType)fileTypeForExtension:(NSString *)extension;
+ (MPFileType)fileTypeForUTI:(NSString *)uti;
+ (NSString *)extensionForFileType:(MPFileType)fileType;
+ (NSString *)typeNameForFileType:(MPFileType)fileType;
+ (BOOL)supportsPreviewForFileType:(MPFileType)fileType;
@end

#endif
