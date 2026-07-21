#ifndef MPDocument_FileTypeSupport_h
#define MPDocument_FileTypeSupport_h

#import "MPDocument.h"

typedef NS_ENUM(NSUInteger, MPDocumentFileType) {
    MPDocumentFileTypeMarkdown,
    MPDocumentFileTypeRMarkdown,
    MPDocumentFileTypeLaTeX,
    MPDocumentFileTypeUnknown
};

@interface MPDocument (FileTypeSupport)

@property (nonatomic, readonly) MPDocumentFileType documentFileType;

- (MPDocumentFileType)detectFileTypeFromURL:(NSURL *)url;
- (BOOL)supportsPreviewForFileType:(MPDocumentFileType)fileType;
- (void)updateRendererForFileType:(MPDocumentFileType)fileType;

@end

#endif
