//
//  MPWritingTools.h
//  Markly
//

#import <Foundation/Foundation.h>

// Word issue categories
typedef NS_ENUM(NSUInteger, MPWordIssueType) {
    MPWordIssueQualifier,      // unnecessary qualifiers: actually, really, very, basically
    MPWordIssueWeasel,         // weasel words: should, might, could, significant, better
    MPWordIssueIndirect,       // indirect language: believe, in general, would like to
    MPWordIssueAdverb,         // adverbs that weaken: quickly, slowly, extremely
    MPWordIssueRepeated,       // repeated consecutive words
};

// A single flagged word with its type and range
@interface MPWordIssue : NSObject
@property (nonatomic, strong) NSString *word;
@property (nonatomic) MPWordIssueType type;
@property (nonatomic) NSRange range;
@end

// WikiLink processing
@interface MPWikiLinkProcessor : NSObject
+ (NSString *)processWikiLinksInMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL;
@end

// Filler word highlighting in HTML
@interface MPFillerHighlighter : NSObject
+ (NSString *)highlightFillersInHTML:(NSString *)html;
@end

// Prose quality analysis
@interface MPProseAnalysis : NSObject
@property (nonatomic, strong) NSArray<MPWordIssue *> *issues;
@property (nonatomic) NSUInteger qualifierCount;
@property (nonatomic) NSUInteger weaselCount;
@property (nonatomic) NSUInteger indirectCount;
@property (nonatomic) NSUInteger adverbCount;
@property (nonatomic) NSUInteger repeatedCount;
+ (MPProseAnalysis *)analyzeText:(NSString *)text;
@end
