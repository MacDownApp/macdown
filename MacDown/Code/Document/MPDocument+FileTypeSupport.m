#import "MPDocument+FileTypeSupport.h"
#import "MPFileType.h"
#import "MPRMarkdownRenderer.h"
#import "MPLaTeXRenderer.h"
#import "MPRenderer.h"

@implementation MPDocument (FileTypeSupport)

- (MPDocumentFileType)documentFileType {
    return [self detectFileTypeFromURL:self.fileURL];
}

- (MPDocumentFileType)detectFileTypeFromURL:(NSURL *)url {
    if (!url) {
        return MPDocumentFileTypeMarkdown;
    }

    NSString *extension = url.pathExtension.lowercaseString;
    MPFileType fileType = [MPFileTypeHelper fileTypeForExtension:extension];

    switch (fileType) {
        case MPFileTypeMarkdown:
            return MPDocumentFileTypeMarkdown;
        case MPFileTypeRMarkdown:
            return MPDocumentFileTypeRMarkdown;
        case MPFileTypeLaTeX:
            return MPDocumentFileTypeLaTeX;
        default:
            return MPDocumentFileTypeMarkdown;
    }
}

- (BOOL)supportsPreviewForFileType:(MPDocumentFileType)fileType {
    return fileType == MPDocumentFileTypeMarkdown ||
           fileType == MPDocumentFileTypeRMarkdown ||
           fileType == MPDocumentFileTypeLaTeX;
}

- (void)updateRendererForFileType:(MPDocumentFileType)fileType {
    switch (fileType) {
        case MPDocumentFileTypeMarkdown:
            if (![self.renderer isKindOfClass:[MPRenderer class]]) {
                self.renderer = [[MPRenderer alloc] init];
            }
            break;

        case MPDocumentFileTypeRMarkdown:
            if (![self.renderer isKindOfClass:[MPRMarkdownRenderer class]]) {
                self.renderer = [[MPRMarkdownRenderer alloc] init];
            }
            break;

        case MPDocumentFileTypeLaTeX:
            if (![self.renderer isKindOfClass:[MPLaTeXRenderer class]]) {
                self.renderer = [[MPLaTeXRenderer alloc] init];
            }
            break;

        default:
            if (![self.renderer isKindOfClass:[MPRenderer class]]) {
                self.renderer = [[MPRenderer alloc] init];
            }
            break;
    }
}

@end
