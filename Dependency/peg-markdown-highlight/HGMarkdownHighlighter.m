/* PEG Markdown Highlight
 * Copyright 2011-2013 Ali Rantakari -- http://hasseg.org
 * Licensed under the GPL2+ and MIT licenses (see LICENSE for more info).
 * 
 * HGMarkdownHighlighter.m
 */

#import "HGMarkdownHighlighter.h"
#import "pmh_parser.h"
#import "pmh_styleparser.h"

#define kStyleParsingErrorInfoKey_ErrorMessage @"message"
#define kStyleParsingErrorInfoKey_LineNumber @"lineNumber"

void styleparsing_error_callback(char *error_message, int line_number, void *context_data)
{
	NSString *errMsg = @(error_message);
	if (errMsg == nil)
		NSLog(@"Cannot interpret error message as UTF-8: '%s'", error_message);
    
	[(__bridge HGMarkdownHighlighter *)context_data
     performSelector:@selector(handleStyleParsingError:)
     withObject:@{kStyleParsingErrorInfoKey_ErrorMessage: errMsg,
                  kStyleParsingErrorInfoKey_LineNumber: @(line_number)
                  }];
}


// 'private members' class extension
@interface HGMarkdownHighlighter ()
{
	NSFontTraitMask _clearFontTraitMask;
	pmh_element **_cachedElements;
	NSOperationQueue *_parseHighlightsQueue;
	BOOL _styleDependenciesPending;
	NSMutableArray *_styleParsingErrors;
	CGFloat _defaultTextSize;
}

@property(copy) NSColor *defaultTextColor;
@property(strong) NSDictionary *defaultTypingAttributes;

- (NSFontTraitMask) getClearFontTraitMask:(NSFontTraitMask)currentFontTraitMask;

@end


@implementation HGMarkdownHighlighter

- (id) init
{
	if (!(self = [super init]))
		return nil;
	
	_cachedElements = NULL;
	_styleDependenciesPending = NO;
	_styleParsingErrors = [NSMutableArray array];
	
	_resetTypingAttributes = YES;
	_parseAndHighlightAutomatically = YES;
	_waitInterval = 0.5;
	_extensions = pmh_EXT_NONE;
	
	_parseHighlightsQueue = [[NSOperationQueue alloc] init];
	_parseHighlightsQueue.maxConcurrentOperationCount = 1; // serial queue
    
	return self;
}

- (instancetype) initWithTextView:(NSTextView *)textView
{
	if (!(self = [self init]))
		return nil;
	self.targetTextView = textView;
	return self;
}

- (instancetype) initWithTextView:(NSTextView *)textView
		   waitInterval:(NSTimeInterval)interval
{
	if (!(self = [self initWithTextView:textView]))
		return nil;
	self.waitInterval = interval;
	return self;
}

- (instancetype) initWithTextView:(NSTextView *)textView
		   waitInterval:(NSTimeInterval)interval
				 styles:(NSArray *)inStyles
{
	if (!(self = [self initWithTextView:textView waitInterval:interval]))
		return nil;
	self.styles = inStyles;
	return self;
}



#pragma mark -


- (pmh_element **) parseText:(NSString *)markdown
{
	pmh_element **result = NULL;
    if (markdown)
    {
        pmh_markdown_to_elements((char *)[markdown UTF8String], self.extensions, &result);
        pmh_sort_elements_by_pos(result);
    }
	return result;
}


// Convert unicode code point offsets (this is what we get from the parser) to
// NSString character offsets (NSString uses UTF-16 units as characters, so
// sometimes two characters (a "surrogate pair") are needed to represent one
// code point):
- (void) convertOffsets:(pmh_element **)elements text:(NSString *)markdown
{
    // Walk through the whole string only once, and gather all surrogate pair indexes
    // (technically, the indexes of the high characters (which come before the low
    // characters) in each pair):
    NSMutableArray *surrogatePairIndexes = [NSMutableArray arrayWithCapacity:(markdown.length / 4)];
    NSUInteger strLen = markdown.length;
    NSUInteger i = 0;
    while (i < strLen)
    {
        if (CFStringIsSurrogateHighCharacter([markdown characterAtIndex:i]))
            [surrogatePairIndexes addObject:@(i)];
        i++;
    }
    
    // If the text does not contain any surrogate pairs, we're done (the indexes
    // are already correct):
    if (surrogatePairIndexes.count == 0)
        return;
    
    // Use our list of surrogate pair indexes to shift the indexes of all
    // language elements:
    for (int langType = 0; langType < pmh_NUM_LANG_TYPES; langType++)
    {
        pmh_element *cursor = elements[langType];
        while (cursor != NULL)
        {
            NSUInteger posShift = 0;
            NSUInteger endShift = 0;
            NSUInteger passedPairs = 0;
            for (NSNumber *pairIndex in surrogatePairIndexes)
            {
                NSUInteger u = [pairIndex unsignedIntegerValue] - passedPairs;
                if (u < cursor->pos)
                {
                    posShift++;
                    endShift++;
                }
                else if (u < cursor->end)
                {
                    endShift++;
                }
                else
                    break;
                passedPairs++;
            }
            cursor->pos += posShift;
            cursor->end += endShift;
            cursor = cursor->next;
        }
    }
}

- (void) requestParsing
{
	[_parseHighlightsQueue cancelAllOperations];
	[_parseHighlightsQueue addOperationWithBlock:^{
		// Fetch the markdown (from the main thread)
		__block NSString *markdown = nil;
		dispatch_sync(dispatch_get_main_queue(), ^{
			markdown = [[self.targetTextView string] copy];
        });

        pmh_element **result = [self parseText:markdown];
		[self convertOffsets:result text:markdown];

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self cacheElementList:result];
			[self applyVisibleRangeHighlighting];
		});
	}];
}


#pragma mark -



- (NSFontTraitMask) getClearFontTraitMask:(NSFontTraitMask)currentFontTraitMask
{
	static NSDictionary *oppositeFontTraits = nil;	
	if (oppositeFontTraits == nil)
		oppositeFontTraits = @{@(NSUnitalicFontMask): @(NSItalicFontMask),
							   @(NSItalicFontMask): @(NSUnitalicFontMask),
							   @(NSBoldFontMask): @(NSUnboldFontMask),
							   @(NSUnboldFontMask): @(NSBoldFontMask),
							   @(NSExpandedFontMask): @(NSCondensedFontMask),
							   @(NSCondensedFontMask): @(NSExpandedFontMask)};
	NSFontTraitMask traitsToApply = 0;
	for (NSNumber *trait in oppositeFontTraits)
	{
		if ((currentFontTraitMask & [trait unsignedIntValue]) != 0)
			continue;
		traitsToApply |= [(NSNumber *)oppositeFontTraits[trait] unsignedIntValue];
	}
	return traitsToApply;
}

- (void) clearHighlightingForRange:(NSRange)range
{
	NSTextStorage *textStorage = [_targetTextView textStorage];
	
	[textStorage applyFontTraits:_clearFontTraitMask range:range];
	[textStorage removeAttribute:NSBackgroundColorAttributeName range:range];
	[textStorage removeAttribute:NSLinkAttributeName range:range];
    if (self.targetTextView.typingAttributes
        && self.resetTypingAttributes
        && self.defaultTypingAttributes[NSParagraphStyleAttributeName])
    {
        [textStorage addAttribute:NSParagraphStyleAttributeName
                            value:self.defaultTypingAttributes[NSParagraphStyleAttributeName]
                            range:range];
    }
	if (self.defaultTextColor != nil)
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.defaultTextColor range:range];
	else
		[textStorage removeAttribute:NSForegroundColorAttributeName range:range];

    NSAttributedStringEnumerationOptions options =
        NSAttributedStringEnumerationLongestEffectiveRangeNotRequired;
    [textStorage enumerateAttributesInRange:range
                                    options:options
                                 usingBlock:
     ^(NSDictionary *attributes, NSRange range, BOOL *stop) {
         NSFont *font = attributes[NSFontAttributeName];
         if (!font || font.pointSize == _defaultTextSize)
             return;
         font = [[NSFontManager sharedFontManager] convertFont:font
                                                        toSize:_defaultTextSize];
         [textStorage addAttribute:NSFontAttributeName value:font range:range];
     }];
}

- (void) readClearTextStylesFromTextView
{
	_clearFontTraitMask = [self getClearFontTraitMask:
	 				 	  [[NSFontManager sharedFontManager]
	  					   traitsOfFont:[self.targetTextView font]]];
    _defaultTextSize = self.targetTextView.font.pointSize;
	
	self.defaultTextColor = [self.targetTextView textColor];
	
	NSMutableDictionary *typingAttrs = [NSMutableDictionary dictionary];
	if ([self.targetTextView backgroundColor] != nil)
		typingAttrs[NSBackgroundColorAttributeName] = [self.targetTextView backgroundColor];
	if ([self.targetTextView textColor] != nil)
		typingAttrs[NSForegroundColorAttributeName] = [self.targetTextView textColor];
	if ([self.targetTextView font] != nil)
		typingAttrs[NSFontAttributeName] = [self.targetTextView font];
	if ([self.targetTextView defaultParagraphStyle] != nil)
		typingAttrs[NSParagraphStyleAttributeName] = [self.targetTextView defaultParagraphStyle];
	self.defaultTypingAttributes = typingAttrs;
}

- (void) applyHighlighting:(pmh_element **)elements withRange:(NSRange)range
{
	NSUInteger rangeEnd = NSMaxRange(range);
	[[self.targetTextView textStorage] beginEditing];
	[self clearHighlightingForRange:range];
	
	NSMutableAttributedString *attrStr = [self.targetTextView textStorage];
	unsigned long sourceLength = [attrStr length];
	
	for (HGMarkdownHighlightingStyle *style in self.styles)
	{
		pmh_element *cursor = elements[style.elementType];
		
		while (cursor != NULL)
		{
			// Ignore (length <= 0) elements (just in case) and
			// ones that end before our range begins
			if (cursor->end <= cursor->pos
				|| cursor->end <= range.location)
			{
				cursor = cursor->next;
				continue;
			}
			
			// HGMarkdownParser orders elements by pos so we can stop
			// at the first one that goes over our range
			if (cursor->pos >= rangeEnd)
				break;
			
			unsigned long rangePosLowLimited = MAX(cursor->pos, (unsigned long)0);
			unsigned long rangePos = MIN(rangePosLowLimited, sourceLength);
			unsigned long len = cursor->end - cursor->pos;
			if (rangePos+len > sourceLength)
				len = sourceLength-rangePos;
			NSRange hlRange = NSMakeRange(rangePos, len);
			
			if (self.makeLinksClickable
				&& (style.elementType == pmh_LINK
					|| style.elementType == pmh_AUTO_LINK_URL
					|| style.elementType == pmh_AUTO_LINK_EMAIL)
				&& cursor->address != NULL)
			{
				NSString *linkAddress = @(cursor->address);
				if (linkAddress != nil)
				{
					if (style.elementType == pmh_AUTO_LINK_EMAIL && ![linkAddress hasPrefix:@"mailto:"])
						linkAddress = [@"mailto:" stringByAppendingString:linkAddress];
					[attrStr addAttribute:NSLinkAttributeName
									value:linkAddress
									range:hlRange];
				}
			}
			
			for (NSString *attrName in style.attributesToRemove)
				[attrStr removeAttribute:attrName range:hlRange];

            NSMutableDictionary *toAdd = [style.attributesToAdd mutableCopy];
            NSDictionary *fontInfo = toAdd[HGFontInformation];
            if (fontInfo)
            {
                NSFontManager *manager = [NSFontManager sharedFontManager];
                [toAdd removeObjectForKey:HGFontInformation];
                [attrStr enumerateAttribute:NSFontAttributeName
                                    inRange:hlRange
                                    options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                 usingBlock:
                 ^(NSFont *font, NSRange range, BOOL *stop) {
                     CGFloat pointSize = [fontInfo[HGFontInformationSizeKey] doubleValue];
                     if (pointSize && pointSize != font.pointSize)
                         font = [manager convertFont:font toSize:pointSize];
                     NSString *fontName = fontInfo[HGFontInformationNameKey];
                     if (fontName && ![fontName isEqualToString:font.fontName])
                         font = [manager convertFont:font toFace:fontName];
                     if (pointSize || fontName)
                     {
                         [attrStr addAttribute:NSFontAttributeName
                                         value:font range:range];
                     }
                 }];
            }
			[attrStr addAttributes:toAdd range:hlRange];

			if (style.fontTraitsToAdd != 0)
				[attrStr applyFontTraits:style.fontTraitsToAdd range:hlRange];
			
			cursor = cursor->next;
		}
	}
	[[self.targetTextView textStorage] endEditing];
}

- (void) applyVisibleRangeHighlighting
{
	NSRect visibleRect = [[[self.targetTextView enclosingScrollView] contentView] documentVisibleRect];
    NSLayoutManager *layoutManager = [self.targetTextView layoutManager];
	NSRange visibleGlyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[self.targetTextView textContainer]];
	NSRange visibleCharRange = [layoutManager characterRangeForGlyphRange:visibleGlyphRange actualGlyphRange:NULL];
    
	if (_cachedElements == NULL)
		return;
    
    @try {
        [self applyHighlighting:_cachedElements withRange:visibleCharRange];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception in -applyHighlighting:withRange: %@", exception);
    }
    
    if (self.resetTypingAttributes)
        [self.targetTextView setTypingAttributes:self.defaultTypingAttributes];
}

- (void) clearHighlighting
{
	[self clearHighlightingForRange:NSMakeRange(0, [[self.targetTextView textStorage] length])];
}


- (void) cacheElementList:(pmh_element **)list
{
	if (_cachedElements != NULL) {
		pmh_free_elements(_cachedElements);
		_cachedElements = NULL;
	}
	_cachedElements = list;
}

- (void) clearElementsCache
{
	[self cacheElementList:NULL];
}

- (void)textViewTextDidChange:(NSNotification *)notification
{
	if (!self.waitInterval) {
		[self requestParsing];
	}
	else {
		// Use GCD timers to prevent delays from UI interactions
		dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, self.waitInterval * NSEC_PER_SEC);
		dispatch_after(delayTime, dispatch_get_main_queue(), ^{
			[self requestParsing];
		});
	}
}

- (void) textViewDidScroll:(NSNotification *)notification
{
	if (_cachedElements == NULL)
		return;
    
	[_parseHighlightsQueue cancelAllOperations];
	[_parseHighlightsQueue addOperationWithBlock:^{
		// No need to over render, set a delay
		usleep(1000000 * 0.1);

		dispatch_async(dispatch_get_main_queue(), ^{
			[self applyVisibleRangeHighlighting];
		});
	}];
}


- (NSArray *) getDefaultStyles
{
	static NSArray *defaultStyles = nil;
	if (defaultStyles != nil)
		return defaultStyles;
	
	defaultStyles = @[HG_MKSTYLE(pmh_H1, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_H2, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_H3, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_H4, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_H5, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_H6, HG_D(HG_DARK(HG_BLUE),HG_FORE, HG_LIGHT(HG_BLUE),HG_BACK), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_HRULE, HG_D(HG_DARK_GRAY,HG_FORE, HG_LIGHT_GRAY,HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_LIST_BULLET, HG_D(HG_DARK(HG_MAGENTA),HG_FORE), nil, 0),
		HG_MKSTYLE(pmh_LIST_ENUMERATOR, HG_D(HG_DARK(HG_MAGENTA),HG_FORE), nil, 0),
		HG_MKSTYLE(pmh_LINK, HG_D(HG_DARK(HG_CYAN),HG_FORE, HG_LIGHT(HG_CYAN),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_AUTO_LINK_URL, HG_D(HG_DARK(HG_CYAN),HG_FORE, HG_LIGHT(HG_CYAN),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_AUTO_LINK_EMAIL, HG_D(HG_DARK(HG_CYAN),HG_FORE, HG_LIGHT(HG_CYAN),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_IMAGE, HG_D(HG_DARK(HG_MAGENTA),HG_FORE, HG_LIGHT(HG_MAGENTA),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_REFERENCE, HG_D(HG_DIM(HG_RED),HG_FORE), nil, 0),
		HG_MKSTYLE(pmh_CODE, HG_D(HG_DARK(HG_GREEN),HG_FORE, HG_LIGHT(HG_GREEN),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_EMPH, HG_D(HG_DARK(HG_YELLOW),HG_FORE), nil, NSItalicFontMask),
		HG_MKSTYLE(pmh_STRONG, HG_D(HG_DARK(HG_MAGENTA),HG_FORE), nil, NSBoldFontMask),
		HG_MKSTYLE(pmh_HTML_ENTITY, HG_D(HG_MED_GRAY,HG_FORE), nil, 0),
		HG_MKSTYLE(pmh_COMMENT, HG_D(HG_MED_GRAY,HG_FORE), nil, 0),
		HG_MKSTYLE(pmh_VERBATIM, HG_D(HG_DARK(HG_GREEN),HG_FORE, HG_LIGHT(HG_GREEN),HG_BACK), nil, 0),
		HG_MKSTYLE(pmh_BLOCKQUOTE, HG_D(HG_DARK(HG_MAGENTA),HG_FORE), HG_A(HG_BACK), NSUnboldFontMask)];
	
	return defaultStyles;
}

- (void) applyStyleDependenciesToTargetTextView
{
	if (self.targetTextView == nil)
		return;
	
	// Set NSTextView link styles to match the styles set for
	// LINK elements, with the "pointing hand cursor" style added:
	for (HGMarkdownHighlightingStyle *style in self.styles)
	{
		if (style.elementType != pmh_LINK)
			continue;
		NSMutableDictionary *linkAttrs = [style.attributesToAdd mutableCopy];
		linkAttrs[NSCursorAttributeName] = [NSCursor pointingHandCursor];
		[self.targetTextView setLinkTextAttributes:linkAttrs];
		break;
	}
	_styleDependenciesPending = NO;
}

- (void) setStyles:(NSArray *)newStyles
{
	NSArray *stylesToApply = (newStyles != nil) ? newStyles : [self getDefaultStyles];
	
	_styles = [stylesToApply copy];
	
	if (self.targetTextView != nil)
		[self applyStyleDependenciesToTargetTextView];
	else
		_styleDependenciesPending = YES;
}

- (NSDictionary *) getDefaultSelectedTextAttributes
{
	static NSDictionary *cachedValue = nil;
	if (cachedValue == nil)
		cachedValue = [[[NSTextView alloc] initWithFrame:NSMakeRect(1,1,1,1)]
						selectedTextAttributes];
	return cachedValue;
}

- (void) handleStyleParsingError:(NSDictionary *)errorInfo
{
	NSString *errorMessage = (NSString *)errorInfo[kStyleParsingErrorInfoKey_ErrorMessage];
	NSString *messageToAdd = nil;
	if (errorMessage == nil)
		messageToAdd = @"<broken error message>";
	else
	{
		int lineNumber = [(NSNumber *)errorInfo[kStyleParsingErrorInfoKey_LineNumber] intValue];
		messageToAdd = [NSString stringWithFormat:@"(Line %i): %@", lineNumber, errorMessage];
	}
	[_styleParsingErrors addObject:messageToAdd];
}

- (void) applyStylesFromStylesheet:(NSString *)stylesheet
                  withErrorHandler:(HGStyleParsingErrorCallback)errorHandler
{
	if (stylesheet == nil)
		return;
	
	char *c_stylesheet = (char *)[stylesheet UTF8String];
	pmh_style_collection *style_coll = NULL;
	
	if (errorHandler == nil)
		style_coll = pmh_parse_styles(c_stylesheet, NULL, NULL);
	else
	{
		[_styleParsingErrors removeAllObjects];
		style_coll = pmh_parse_styles(c_stylesheet, &styleparsing_error_callback, (__bridge void *)(self));
		if ([_styleParsingErrors count] > 0)
            errorHandler(_styleParsingErrors);
	}
	
	NSFont *baseFont = (self.defaultTypingAttributes)[NSFontAttributeName];
	if (baseFont == nil)
		baseFont = [self.targetTextView font];
	
	NSMutableArray *stylesArr = [NSMutableArray array];
	
	// Set language element styles
	int i;
	for (i = 0; i < pmh_NUM_LANG_TYPES; i++)
	{
		pmh_style_attribute *cur = style_coll->element_styles[i];
		if (cur == NULL)
			continue;
		HGMarkdownHighlightingStyle *style = [[HGMarkdownHighlightingStyle alloc]
											   initWithStyleAttributes:cur
											   baseFont:baseFont];
		[stylesArr addObject:style];
	}
	
	self.styles = stylesArr;
	
	// Set editor styles
	if (self.targetTextView != nil)
	{
		[self clearHighlighting];
		
		// General editor styles
		if (style_coll->editor_styles != NULL)
		{
			pmh_style_attribute *cur = style_coll->editor_styles;
			while (cur != NULL)
			{
				if (cur->type == pmh_attr_type_background_color)
					[self.targetTextView setBackgroundColor:[HGMarkdownHighlightingStyle
															 colorFromARGBColor:cur->value->argb_color]];
				else if (cur->type == pmh_attr_type_foreground_color)
					[self.targetTextView setTextColor:[HGMarkdownHighlightingStyle
													   colorFromARGBColor:cur->value->argb_color]];
				else if (cur->type == pmh_attr_type_caret_color)
					[self.targetTextView setInsertionPointColor:[HGMarkdownHighlightingStyle
																 colorFromARGBColor:cur->value->argb_color]];
				cur = cur->next;
			}
		}
		
		// Selection styles
		if (style_coll->editor_selection_styles != NULL)
		{
			NSMutableDictionary *selAttrs = [[self getDefaultSelectedTextAttributes] mutableCopy];
			
			pmh_style_attribute *cur = style_coll->editor_selection_styles;
			while (cur != NULL)
			{
				// Cocoa (as of Mac OS 10.6.6) supports only foreground color,
				// background color and underlining attributes for selections:
				if (cur->type == pmh_attr_type_background_color)
					selAttrs[NSBackgroundColorAttributeName] = [HGMarkdownHighlightingStyle
										 colorFromARGBColor:cur->value->argb_color];
				else if (cur->type == pmh_attr_type_foreground_color)
					selAttrs[NSForegroundColorAttributeName] = [HGMarkdownHighlightingStyle
										 colorFromARGBColor:cur->value->argb_color];
				else if (cur->type == pmh_attr_type_font_style)
				{
					if (cur->value->font_styles->underlined)
						selAttrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
				}
				cur = cur->next;
			}
			
			[self.targetTextView setSelectedTextAttributes:selAttrs];
		}
		else
			[self.targetTextView setSelectedTextAttributes:[self getDefaultSelectedTextAttributes]];
		
		// Current line styles
		if (style_coll->editor_current_line_styles != NULL)
		{
			self.currentLineStyle = [[HGMarkdownHighlightingStyle alloc]
									  initWithStyleAttributes:style_coll->editor_current_line_styles
									  baseFont:baseFont];
		}
		else
			self.currentLineStyle = nil;
			
		[self readClearTextStylesFromTextView];
	}
	
	pmh_free_style_collection(style_coll);
	[self highlightNow];
}


- (void) setTargetTextView:(NSTextView *)newTextView
{
	if (_targetTextView == newTextView)
		return;
	
	_targetTextView = newTextView;
	
	if (_targetTextView != nil)
		[self readClearTextStylesFromTextView];
}


- (void) parseAndHighlightNow
{
	[self requestParsing];
}

- (void) highlightNow
{
	[self applyVisibleRangeHighlighting];
}

- (void) activate
{
	// todo: throw exception if targetTextView is nil?
	
	if (self.styles == nil)
		self.styles = [self getDefaultStyles];
	if (_styleDependenciesPending)
		[self applyStyleDependenciesToTargetTextView];
	
	[self requestParsing];
	
	if (self.parseAndHighlightAutomatically)
		[[NSNotificationCenter defaultCenter]
		 addObserver:self
		 selector:@selector(textViewTextDidChange:)
		 name:NSTextDidChangeNotification
		 object:self.targetTextView];
	
	NSScrollView *scrollView = [self.targetTextView enclosingScrollView];
	if (scrollView != nil)
	{
		[[scrollView contentView] setPostsBoundsChangedNotifications: YES];
		[[NSNotificationCenter defaultCenter]
		 addObserver:self
		 selector:@selector(textViewDidScroll:)
		 name:NSViewBoundsDidChangeNotification
		 object:[scrollView contentView]
		 ];
	}
	
	self.isActive = YES;
}

- (void) deactivate
{
	if (!self.isActive)
		return;
	
	[[NSNotificationCenter defaultCenter]
	 removeObserver:self
	 name:NSTextDidChangeNotification
	 object:self.targetTextView];
	
	NSScrollView *scrollView = [self.targetTextView enclosingScrollView];
	if (scrollView != nil)
	{
		// let's not change this here... the user may wish to control it
		//[[scrollView contentView] setPostsBoundsChangedNotifications: NO];
		
		[[NSNotificationCenter defaultCenter]
		 removeObserver:self
		 name:NSViewBoundsDidChangeNotification
		 object:[scrollView contentView]
		 ];
	}
	
	[self clearElementsCache];
	self.isActive = NO;
}



@end
