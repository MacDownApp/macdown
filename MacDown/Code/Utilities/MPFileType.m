#import "MPFileType.h"

@implementation MPFileTypeHelper

+ (MPFileType)fileTypeForExtension:(NSString *)extension {
    if (!extension) return MPFileTypeUnknown;

    NSString *lowerExtension = [extension lowercaseString];

    if ([lowerExtension isEqualToString:@"md"] || [lowerExtension isEqualToString:@"markdown"]) {
        return MPFileTypeMarkdown;
    } else if ([lowerExtension isEqualToString:@"rmd"] || [lowerExtension isEqualToString:@"Rmd"]) {
        return MPFileTypeRMarkdown;
    } else if ([lowerExtension isEqualToString:@"tex"] || [lowerExtension isEqualToString:@"latex"]) {
        return MPFileTypeLaTeX;
    }

    return MPFileTypeUnknown;
}

+ (MPFileType)fileTypeForUTI:(NSString *)uti {
    if (!uti) return MPFileTypeUnknown;

    if ([uti isEqualToString:@"net.daringfireball.markdown"]) {
        return MPFileTypeMarkdown;
    } else if ([uti isEqualToString:@"com.macdown.rmarkdown"]) {
        return MPFileTypeRMarkdown;
    } else if ([uti isEqualToString:@"com.macdown.latex"]) {
        return MPFileTypeLaTeX;
    } else if ([uti isEqualToString:@"public.plain-text"]) {
        return MPFileTypeMarkdown;
    }

    return MPFileTypeUnknown;
}

+ (NSString *)extensionForFileType:(MPFileType)fileType {
    switch (fileType) {
        case MPFileTypeMarkdown:
            return @"md";
        case MPFileTypeRMarkdown:
            return @"rmd";
        case MPFileTypeLaTeX:
            return @"tex";
        default:
            return @"txt";
    }
}

+ (NSString *)typeNameForFileType:(MPFileType)fileType {
    switch (fileType) {
        case MPFileTypeMarkdown:
            return @"Markdown";
        case MPFileTypeRMarkdown:
            return @"RMarkdown";
        case MPFileTypeLaTeX:
            return @"LaTeX";
        default:
            return @"Text";
    }
}

+ (BOOL)supportsPreviewForFileType:(MPFileType)fileType {
    return fileType == MPFileTypeMarkdown ||
           fileType == MPFileTypeRMarkdown ||
           fileType == MPFileTypeLaTeX;
}

@end
