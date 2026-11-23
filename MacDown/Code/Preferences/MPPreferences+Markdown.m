//
//  MPPreferences+Markdown.m
//  MacDown
//

#import "MPPreferences+Markdown.h"
#import "MPRenderer.h"

@implementation MPPreferences (Markdown)

- (MPMarkdownRenderOptions *)markdownRenderOptions
{
    MPMarkdownRenderOptions *o = [[MPMarkdownRenderOptions alloc] init];
    o.tables = self.extensionTables;
    o.fencedCode = self.extensionFencedCode;
    o.footnotes = self.extensionFootnotes;
    o.autolink = self.extensionAutolink;
    o.strikethrough = self.extensionStrikethough;
    o.underline = self.extensionUnderline;
    o.highlight = self.extensionHighlight;
    o.quote = self.extensionQuote;
    o.superscript = self.extensionSuperscript;
    o.intraEmphasis = self.extensionIntraEmphasis;
    o.math = self.htmlMathJax;
    o.mathInlineDollar = self.htmlMathJaxInlineDollar;
    o.taskList = self.htmlTaskList;
    o.lineNumbers = self.htmlLineNumbers;
    o.hardWrap = self.htmlHardWrap;
    o.codeBlockInformation =
        (self.htmlCodeBlockAccessory == MPCodeBlockAccessoryCustom);
    o.smartyPants = self.extensionSmartyPants;
    o.rendersTOC = self.htmlRendersTOC;
    o.detectsFrontMatter = self.htmlDetectFrontMatter;
    return o;
}

@end
