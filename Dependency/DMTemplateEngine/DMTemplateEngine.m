
// DMTemplateEngine.m
// Dustin Mierau
// Cared for under the MIT license.

#import "DMTemplateEngine.h"

typedef enum {
	DMTemplateValueTagType = 1,
	DMTemplateLogTagType,
	DMTemplateIfTagType,
	DMTemplateElseIfTagType,
	DMTemplateElseTagType,
	DMTemplateEndIfTagType,
	DMTemplateForEachTagType,
	DMTemplateEndForEachTagType
}
DMTemplateTagType;

typedef enum {
	DMTemplateIfBlockType = 1,
	DMTemplateForEachBlockType
}
DMTemplateBlockType;

#pragma mark -

@interface DMTemplateCondition : NSObject
@property (nonatomic, readonly) BOOL isSolved;
@property (nonatomic, assign) BOOL result;
+ (id)condition;
@end

#pragma mark -

@interface DMTemplateTagInfo : NSObject
@property (nonatomic, assign) DMTemplateTagType type;
@property (nonatomic, retain) NSMutableArray* modifiers;
@property (nonatomic, retain) NSString* content;
+ (id)tagInfo;
@end

#pragma mark -

@interface DMTemplateContext : NSObject
@property (nonatomic, assign) id object;
@property (nonatomic, retain) NSMutableDictionary* dictionary;
+ (id)context;
@end

#pragma mark -

@interface DMTemplateEngine ()
@property (nonatomic, assign) id object;
@property (nonatomic, assign) NSMutableArray* conditionStack;
@property (nonatomic, retain) NSMutableDictionary* modifiers;
@property (nonatomic, retain) NSMutableDictionary* regexStorage;
@property (nonatomic, assign) NSScanner* scanner;
@property (nonatomic, assign) NSMutableString* renderedTemplate;
@property (nonatomic, readonly) DMTemplateCondition* currentCondition;
@property (nonatomic, readonly) BOOL hasCondition;
@property (nonatomic, readonly) BOOL overallCondition;
- (void)_build;
- (NSArray*)_evaluateForeachStatement:(NSString*)tag variable:(NSString**)variableName;
- (BOOL)_evaluateConditionStatement:(NSString*)tag;
- (NSString*)_parseStatementContent:(NSString*)tag;
- (NSString*)_scanBlockOfType:(DMTemplateBlockType)inType returnContent:(BOOL)inReturnContent;
- (BOOL)_scanSingleNewline;
- (void)_pushCondition:(DMTemplateCondition*)inCondition;
- (void)_popCondition;
- (DMTemplateTagInfo*)_analyzeTagContent:(NSString*)content;
- (BOOL)_tag:(NSString*)tag isTagType:(DMTemplateTagType)tagType;
- (NSRegularExpression*)_regexForTagType:(DMTemplateTagType)tagType;
- (DMTemplateTagType)_determineTemplateTagType:(NSString*)tag;
@end

#pragma mark -

@interface DMTemplateEngine (Strings)
+ (NSString*)_stringByEscapingXMLEntities:(NSString*)string;
+ (NSString*)_stringWithReadableByteSize:(unsigned long long)bytes;
+ (NSString*)_stringByAddingPercentEscapes:(NSString*)string;
+ (NSString*)_stringByRemovingCharactersFromSet:(NSCharacterSet*)set string:(NSString*)string;
+ (NSString*)_stringByTrimmingWhitespace:(NSString*)string;
+ (void)_removeCharactersInSet:(NSCharacterSet*)set string:(NSMutableString*)string;
@end

#pragma mark -

@implementation DMTemplateEngine

@synthesize template;
@synthesize object;
@synthesize conditionStack;
@synthesize regexStorage;
@synthesize scanner;
@synthesize renderedTemplate;
@synthesize modifiers;
@synthesize beginProcessorMarker;
@synthesize endProcessorMarker;

#pragma mark -

+ (id)engine {
	return [[[self alloc] init] autorelease];
}

+ (id)engineWithTemplate:(NSString*)template {
	DMTemplateEngine* engine = [self engine];
	engine.template = template;
	return engine;
}

#pragma mark -

- (id)init {
	self = [super init];
	if(self == nil) {
		return nil;
	}
	
	// Set default processor markers.
	self.beginProcessorMarker = @"{%";
	self.endProcessorMarker = @"%}";
	
	// Create modifier storage.
	self.modifiers = [NSMutableDictionary dictionary];
	
	// Create storage for regular expressions.
	self.regexStorage = [NSMutableDictionary dictionary];
	
	// Register URL encode modifier.
	[self addModifier:'u' block:^(NSString* value) {
		return [DMTemplateEngine _stringByAddingPercentEscapes:value];
	}];
	
	// Reguster readable byte size modifier.
	[self addModifier:'b' block:^(NSString* value) {
		return [DMTemplateEngine _stringWithReadableByteSize:[value longLongValue]];
	}];
	
	// Register XML/HTML escape modifier.
	[self addModifier:'e' block:^(NSString* value) {
		return [DMTemplateEngine _stringByEscapingXMLEntities:value];
	}];
	
	return self;
}

- (void)dealloc {
	self.template = nil;
	self.object = nil;
	self.conditionStack = nil;
	self.scanner = nil;
	self.renderedTemplate = nil;
	self.modifiers = nil;
	self.beginProcessorMarker = nil;
	self.endProcessorMarker = nil;
	self.regexStorage = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Properties

- (BOOL)hasCondition {
	return ([self.conditionStack count] > 0);
}

- (BOOL)overallCondition {
	// The overall condition is false if a single condition on the stack is false.
	for(DMTemplateCondition* condition in self.conditionStack) {
		if(!condition.result) {
			return NO;
		}
	}
	
	return YES;
}

- (DMTemplateCondition*)currentCondition {
	if(self.hasCondition) {
		return [self.conditionStack lastObject];
	}
	
	return nil;
}

#pragma mark -
#pragma mark Modifiers

- (void)addModifier:(unichar)modifier block:(NSString*(^)(NSString*))block {
	[self.modifiers setObject:[[block copy] autorelease] forKey:[NSString stringWithCharacters:&modifier length:1]];
}

- (void)removeModifier:(unichar)modifier {
	[self.modifiers removeObjectForKey:[NSString stringWithCharacters:&modifier length:1]];
}

- (void)removeAllModifiers {
	[self.modifiers removeAllObjects];
}

#pragma mark -
#pragma mark Render

- (NSString*)renderAgainst:(id)obj {
	if(self.template == nil) {
		return nil;
	}
	
	self.object = obj;
	self.conditionStack = [NSMutableArray array];
	self.renderedTemplate = [NSMutableString string];
	
	// Setup string scanner. Make sure we 
	// skip no characters.
	self.scanner = [NSScanner scannerWithString:self.template];
	[self.scanner setCharactersToBeSkipped:nil];
	
	@try {
		[self _build];
	}
	@catch(id exception) {
		self.renderedTemplate = nil;
	}
	@finally {
		self.object = nil;
		self.conditionStack = nil;
		self.scanner = nil;
	}
	
	return self.renderedTemplate;
}

- (void)_build {
	NSString* startDelimeter = self.beginProcessorMarker;
	NSString* endDelimeter = self.endProcessorMarker;

	while(![self.scanner isAtEnd]) {
		NSAutoreleasePool* memoryPool = nil;
		
		@try {
			// Start a new autorelease pool
			memoryPool = [[NSAutoreleasePool alloc] init];
			
			NSString* tagContent = nil;
			NSString* scannedText = nil;
			BOOL skipContent = !self.overallCondition;

			// Scan contents up to the first start delimeter we can find
			if([self.scanner scanUpToString:startDelimeter intoString:(skipContent ? nil : &scannedText)]) {
				// Append scanned content to result if we are not skipping this content
				if(!skipContent) {
					[self.renderedTemplate appendString:scannedText];
				}
			}

			// Scan past start delimeter if possible
			if(![self.scanner scanString:startDelimeter intoString:nil]) {
				continue;
			}

			// Scan past end delimiter if possible (a sanity check really, for totally empty tags)
			if([self.scanner scanString:endDelimeter intoString:nil]) {
				continue;
			}

			// Scan tag content up to end delimeter and scan past end delimeter too if possible
			if([self.scanner scanUpToString:endDelimeter intoString:&tagContent] && [self.scanner scanString:endDelimeter intoString:nil]) {
				// We have some tag content to play with at this point, prepare this content by trimming surrounding whitespace
				DMTemplateTagInfo* tagInfo = [self _analyzeTagContent:tagContent];
				tagContent = tagInfo.content;
				
				@try {
					// Determine tag content type and handle it
					switch(tagInfo.type) {
						case DMTemplateIfTagType: {
								DMTemplateCondition* condition = [DMTemplateCondition condition];
								
								// If we are current skipping this content, mark this new condition as solved. This way other 
								// conditions will naturally skip processing. Otherwise, let us evaluate the tag content.
								if(skipContent) {
									condition.result = YES;
								}
								else {
									condition.result = [self _evaluateConditionStatement:tagContent];
								}

								// Throw new condition object onto the stack
								[self _pushCondition:condition];
							
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							}
							break;
						
						case DMTemplateElseIfTagType: {
								DMTemplateCondition* condition = self.currentCondition;
								
								// If the current condition has already been solved, avoid evaluation by simply ignoring 
								// this condition completely.
								if(condition.isSolved) {
									condition.result = NO;
								}
								else {
									condition.result = [self _evaluateConditionStatement:tagContent];
								}
							
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							}
							break;
						
						case DMTemplateElseTagType: {
								DMTemplateCondition* condition = self.currentCondition;
								
								// If the current condition has already been solved, simply ignore.
								condition.result = (condition.isSolved ? NO : !condition.result);
							
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							}
							break;
						
						case DMTemplateEndIfTagType: {
								// End current condition by popping it off the stack.
								[self _popCondition];
							
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							}
							break;
						
						case DMTemplateForEachTagType: {
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							
								// Read foreach block content, only store if we are not currently skipping over content.
								NSString* blockContent = [self _scanBlockOfType:DMTemplateForEachBlockType returnContent:!skipContent];
								
								if(skipContent) {
									continue;
								}
								
								// Evaluate foreach statement
								NSString* variableName = nil;
								NSArray* array = [self _evaluateForeachStatement:tagContent variable:&variableName];
								if(array == nil || variableName == nil) {
									continue;
								}
							
								// Retain our context for the foreach block.
								DMTemplateContext* context = [DMTemplateContext context];
								context.object = self.object;
							
								// Content within a foreach block is rendered as a template itself.
								DMTemplateEngine* engine = [DMTemplateEngine engineWithTemplate:blockContent];
								engine.modifiers = self.modifiers;
								for(NSUInteger i = 0; i < array.count; i++) {
									id obj = [array objectAtIndex:i];
									// Add the desired variable to the foreach block's 
									// context. Also add a few automatic variables for
									// enumeration information.
									[context setValue:obj forKey:variableName];
									[context setValue:[NSNumber numberWithUnsignedInteger:i] forKey:[variableName stringByAppendingString:@"Index"]];
									
									// Render foreach content against the current context.
									NSString* builtContent = [engine renderAgainst:context];
									if(builtContent != nil) {
										[self.renderedTemplate appendString:builtContent];
									}
								}
							}
							break;
							
						case DMTemplateEndForEachTagType:
							break;
						
						case DMTemplateLogTagType: {
								// If we are currently skipping content, don't log.
								if(skipContent) {
									continue;
								}
								
								NSString* statementContent = [self _parseStatementContent:tagContent];
								if(([statementContent hasPrefix:@"\""] && [statementContent hasSuffix:@"\""]) || ([statementContent hasPrefix:@"'"] && [statementContent hasSuffix:@"'"])) {
									// Statement is a string, so remove quotes and log what was typed.
									statementContent = [statementContent substringWithRange:NSMakeRange(1, [statementContent length]-2)];
									NSLog(@"%@", statementContent);
								}
								else {
									// Statement (we assume) is a key-value path, find value and log that.
									NSPredicate* predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"(%@) == 0", statementContent]];
									NSExpression* expression = [(NSComparisonPredicate*)predicate leftExpression];
									NSLog(@"%@", [expression expressionValueWithObject:self.object context:nil]);
								}
							
								// Skip over a newline, if necessary.
								[self _scanSingleNewline];
							}
							break;
							
						case DMTemplateValueTagType: {
								// If we are currently skipping content, simply skip this value.
								if(skipContent) {
									continue;
								}

								// Get key value for the specified key path. If a value is found, 
								// append it to the result. We're also tricking NSPredicate into 
								// using its built-in math expression parser so we can write math
								// inline in our template.
								NSPredicate* predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"(%@) == 0", tagContent]];
								NSExpression* expression = [(NSComparisonPredicate*)predicate leftExpression];
								id keyValue = [expression expressionValueWithObject:self.object context:nil];
								if(keyValue != nil) {
									NSString* keyString = [keyValue description];
									
									// Run through modifiers and apply.
									for(NSString* modifier in tagInfo.modifiers) {
										NSString*(^modifierBlock)(NSString*) = [self.modifiers objectForKey:modifier];
										if(modifierBlock != nil) {
											keyString = modifierBlock(keyString);
										}
									}
									
									// Append modified value to rendering.
									[self.renderedTemplate appendString:keyString];
								}
							}
							break;
					}
				}
				@catch(id exception) {
					NSLog(@"DMTemplateEngine: Build error %@", exception);
				}
			}
		}
		@finally {
			[memoryPool release];
		}
	}
}

- (NSString*)_parseStatementContent:(NSString*)tag {
	// Find open and close brackets surrounding content
	NSRange openBracketRange = [tag rangeOfString:@"("];
	NSRange closeBracketRange = [tag rangeOfString:@")" options:NSBackwardsSearch];
	
	// Make sure open and close brackets were found
	if(openBracketRange.length == 0 || closeBracketRange.length == 0 || closeBracketRange.location <= NSMaxRange(openBracketRange)) {
		return nil;
	}
	
	// Determine content range
	NSRange conditionContentRange = NSMakeRange(NSMaxRange(openBracketRange), closeBracketRange.location - NSMaxRange(openBracketRange));
	if(conditionContentRange.length == 0) {
		return nil;
	}
	
	// Extract content
	NSString* content = [tag substringWithRange:conditionContentRange];
	
	// Prepare content
	content = [DMTemplateEngine _stringByTrimmingWhitespace:content];
	
	// Return null if the content is empty
	if([content length] == 0) {
		return nil;
	}
	
	return content;
}

- (NSString*)_scanBlockOfType:(DMTemplateBlockType)inType returnContent:(BOOL)returnContent {
	NSMutableString* content = [NSMutableString string];
	unsigned nestLevel = 0;
	
	while(![self.scanner isAtEnd]) {
		NSString* tagContent = nil;
		NSString* scannedText = nil;

		// Scan contents up to the first start delimeter we can find
		if([self.scanner scanUpToString:self.beginProcessorMarker intoString:(returnContent ? &scannedText : nil)]) {
			// Append scanned content to result if we are not skipping this content
			if(returnContent) {
				[content appendString:scannedText];
			}
		}

		// Scan past start delimeter if possible
		if(![self.scanner scanString:self.beginProcessorMarker intoString:nil]) {
			continue;
		}

		// Scan past end delimiter if possible (a sanity check really, for totally empty tags
		if([self.scanner scanString:self.endProcessorMarker intoString:nil]) {
			continue;
		}

		// Scan tag content up to end delimeter and scan past end delimeter too if possible
		if([self.scanner scanUpToString:self.endProcessorMarker intoString:&tagContent] && [self.scanner scanString:self.endProcessorMarker intoString:nil]) {
			// We have some tag content to play with at this point, prepare this content by trimming surrounding whitespace
			tagContent = [DMTemplateEngine _stringByTrimmingWhitespace:tagContent];
			
			DMTemplateTagType tagType = [self _determineTemplateTagType:tagContent];
			
			if((inType == DMTemplateIfBlockType && tagType == DMTemplateIfTagType) || (inType == DMTemplateForEachBlockType && tagType == DMTemplateForEachTagType)) {
				nestLevel++;
			}
			else
			if((inType == DMTemplateIfBlockType && tagType == DMTemplateEndIfTagType) || (inType == DMTemplateForEachBlockType && tagType == DMTemplateEndForEachTagType)) {
				if(nestLevel == 0) {
					[self _scanSingleNewline];
					break;
				}
				else {
					nestLevel--;
				}
			}
			
			if(returnContent) {
				[content appendFormat:@"%@ %@ %@", self.beginProcessorMarker, tagContent, self.endProcessorMarker];
			}
		}
	}
	
	return content;
}

- (BOOL)_scanSingleNewline {
	// Pass on this scan if the scanner is done.
	if([self.scanner isAtEnd]) {
		return NO;
	}
	
	NSUInteger loc = [self.scanner scanLocation];
	unichar character = [[self.scanner string] characterAtIndex:[self.scanner scanLocation]];
	
	// If this character is not part of the newline
	// character set, then we're not going to skip it.
	if(![[NSCharacterSet newlineCharacterSet] characterIsMember:character]) {
		return NO;
	}
	
	// If this character is part of the newline set
	// then let's skip over it.
	[self.scanner setScanLocation:loc+1];
	
	return YES;
}

- (NSArray*)_evaluateForeachStatement:(NSString*)tag variable:(NSString**)variableName {
	// Tag content must be at least 10 characters in length.
	if([tag length] < [@"foreach( )" length]) {
		return nil;
	}
	
	// Parse statement content
	NSString* statementContent = [self _parseStatementContent:tag];
	if(statementContent == nil) {
		return nil;
	}
	
	// Parse out the variable name and key from 
	// the specified foreach statement content.
	NSRange statementInRange = [statementContent rangeOfString:@" in " options:NSCaseInsensitiveSearch];
	NSString* statementKey = [statementContent substringFromIndex:NSMaxRange(statementInRange)];
	NSString* statementVariable = [statementContent substringToIndex:statementInRange.location];
	
	statementKey = [DMTemplateEngine _stringByTrimmingWhitespace:statementKey];
	*variableName = [DMTemplateEngine _stringByTrimmingWhitespace:statementVariable];
	
	NSArray* array = nil;
	
	@try {
		if([statementKey hasPrefix:@"{"] && [statementKey hasSuffix:@"}"]) {
			// Statement is an inline property list array definition.
			statementKey = [statementKey substringWithRange:NSMakeRange(1, [statementKey length]-2)];
			if([statementKey length] == 0) {
				return nil;
			}
			
			// Quickly convert the defined property list to a
			// format Apple's parser will recognize.
			NSData* propertyListContent = [[NSString stringWithFormat:@"(%@)", statementKey] dataUsingEncoding:NSUTF8StringEncoding];
			NSError* propertyListError;
		
			// Deserialize inline array and return.
			id propertyList = [NSPropertyListSerialization propertyListWithData:propertyListContent options:0 format:NULL error:&propertyListError];
			if(propertyList && [propertyList isKindOfClass:[NSArray class]]) {
				array = (NSArray*)propertyList;
			}
		}
		else {
			// Statement is (we assume) a key-value path, so try to get the value and make sure it is an array.
			id keyValue = [self.object valueForKeyPath:statementKey];
			if(keyValue != nil && [keyValue isKindOfClass:[NSArray class]]) {
				array = (NSArray*)keyValue;
			}
		}
	}
	@catch(id exception) {
		array = nil;
	}
	
	return array;
}

- (BOOL)_evaluateConditionStatement:(NSString*)tag {
	// Tag content must be at least 5 characters in length.
	if([tag length] < [@"if( )" length]) {
		return NO;
	}
	
	// Parse condition content
	NSString* conditionContent = [self _parseStatementContent:tag];
	if(conditionContent == nil) {
		return NO;
	}
	
	BOOL result = NO;
	
	@try {
		// Compile and evaluate predicate
		result = [[NSPredicate predicateWithFormat:conditionContent] evaluateWithObject:self.object];
	}
	@catch(id exception) {
		// Predicate failed to compile, probably a syntax error.
		result = NO;
	}

	return result;
}

- (DMTemplateTagInfo*)_analyzeTagContent:(NSString*)content {
	DMTemplateTagInfo* tagInfo = [DMTemplateTagInfo tagInfo];
	
	content = [DMTemplateEngine _stringByTrimmingWhitespace:content];

	if([content hasPrefix:@"["]) {
		NSRange optionsRange;
		
		optionsRange = [content rangeOfString:@"]"];
		optionsRange.length = optionsRange.location-1;
		optionsRange.location = 1;
		
		NSString* optionsContent = [content substringWithRange:optionsRange];
		optionsContent = [DMTemplateEngine _stringByRemovingCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] string:optionsContent];
		optionsContent = [optionsContent lowercaseString];
		
		for(NSUInteger i = 0; i < [optionsContent length]; i++) {
			unichar modifierChar = [optionsContent characterAtIndex:i];
			NSString* modifierString = [NSString stringWithCharacters:&modifierChar length:1];
			[tagInfo.modifiers addObject:modifierString];
		}
		
		content = [content substringFromIndex:NSMaxRange(optionsRange)+1];
		content = [DMTemplateEngine _stringByTrimmingWhitespace:content];
	}
	
	tagInfo.type = [self _determineTemplateTagType:content];
	tagInfo.content = content;
	
	return tagInfo;
}

- (BOOL)_tag:(NSString*)tag isTagType:(DMTemplateTagType)tagType {
	NSRegularExpression* regex = [self _regexForTagType:tagType];
	if(regex == nil) {
		return NO;
	}
	
	NSRange tagRange = [regex rangeOfFirstMatchInString:tag options:NSMatchingAnchored range:NSMakeRange(0, [tag length])];
	return (tagRange.location != NSNotFound);
}

- (NSRegularExpression*)_regexForTagType:(DMTemplateTagType)tagType {
	NSNumber* tagTypeNumber = [[NSNumber alloc] initWithUnsignedInteger:tagType];
	NSRegularExpression* regex = nil;
	
	regex = [self.regexStorage objectForKey:tagTypeNumber];
	if(regex == nil) {
		NSString* pattern = nil;
		
		switch(tagType) {
			case DMTemplateIfTagType:
				pattern = @"if\\s*\\(\\s*";
				break;
				
			case DMTemplateElseIfTagType:
				pattern = @"elseif\\s*\\(\\s*";
				break;
				
			case DMTemplateElseTagType:
				pattern = @"else";
				break;
				
			case DMTemplateEndIfTagType:
				pattern = @"endif";
				break;
				
			case DMTemplateForEachTagType:
				pattern = @"foreach\\s*\\(\\s*";
				break;
				
			case DMTemplateEndForEachTagType:
				pattern = @"endforeach";
				break;
				
			case DMTemplateLogTagType:
				pattern = @"log\\s*\\(\\s*";
				break;
				
			case DMTemplateValueTagType:
				pattern = nil;
				break;
		}
		
		if(pattern != nil) {
			regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
			[self.regexStorage setObject:regex forKey:tagTypeNumber];
		}
	}
	
	[tagTypeNumber release];
	
	return regex;
}

- (DMTemplateTagType)_determineTemplateTagType:(NSString*)tag {
	DMTemplateTagType tagType;
	
	if([self _tag:tag isTagType:DMTemplateIfTagType]) {
		// Tag is an if statement
		// e.g. if(condition)
		tagType = DMTemplateIfTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateElseTagType]) {
		// Tag is a simple else statement
		// e.g. else
		tagType = DMTemplateElseTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateElseIfTagType]) {
		// Tag is an alternative if statement
		// e.g. elseif(condition)
		tagType = DMTemplateElseIfTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateEndIfTagType]) {
		// Tag is a closing if statement
		// e.g. endif
		tagType = DMTemplateEndIfTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateForEachTagType]) {
		// Tag is a foreach statement
		// e.g. foreach(array)
		tagType = DMTemplateForEachTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateEndForEachTagType]) {
		// Tag is a closing foreach statement
		// e.g. endforeach
		tagType = DMTemplateEndForEachTagType;
	}
	else
	if([self _tag:tag isTagType:DMTemplateLogTagType]) {
		// Tag is a log statement
		// e.g. log
		tagType = DMTemplateLogTagType;
	}
	else {
		// Tag is a value to be substituted
		tagType = DMTemplateValueTagType;
	}
	
	return tagType;
}

#pragma mark -
#pragma mark Conditions

- (void)_pushCondition:(DMTemplateCondition*)condition {
	[self.conditionStack addObject:condition];
}

- (void)_popCondition {
	[self.conditionStack removeLastObject];
}

@end

#pragma mark -

@implementation DMTemplateCondition

@synthesize isSolved;
@synthesize result;

#pragma mark -

+ (id)condition {
	return [[[DMTemplateCondition alloc] init] autorelease];
}

- (id)init {
	self = [super init];
	if(self == nil) {
		return nil;
	}
	
	isSolved = NO;
	result = NO;
	
	return self;
}

- (void)setConditionResult:(BOOL)flag {
	result = flag;
	if(flag) {
		isSolved = YES;
	}
}

@end

#pragma mark -

@implementation DMTemplateTagInfo

@synthesize type;
@synthesize modifiers;
@synthesize content;

#pragma mark -

+ (id)tagInfo {
	return [[[DMTemplateTagInfo alloc] init] autorelease];
}

- (id)init {
	self = [super init];
	if(self == nil) {
		return nil;
	}
	
	self.modifiers = [NSMutableArray array];
	
	return self;
}

- (void)dealloc {
	self.modifiers = nil;
	self.content = nil;
	[super dealloc];
}

@end

#pragma mark -

@implementation DMTemplateContext

@synthesize object;
@synthesize dictionary;

#pragma mark -

+ (id)context {
	return [[[self alloc] init] autorelease];
}

- (id)init {
	self = [super init];
	if(self == nil) {
		return nil;
	}

	self.dictionary = [NSMutableDictionary dictionary];
	
	return self;
}

- (void)dealloc {
	self.object = nil;
	self.dictionary = nil;
	[super dealloc];
}

#pragma mark -

- (id)valueForUndefinedKey:(NSString*)key {
	// Attempt to get the desired value from our
	// dictionary first.
	id value = [self.dictionary objectForKey:key];
	
	// And if our dictionary doesn't resolve the 
	// desired key, we go ahead and ask our 
	// proxied object.
	if(value == nil) {
		value = [self.object valueForKey:key];
	}
	
	return value;
}

- (void)setValue:(id)value forUndefinedKey:(NSString*)key {
	// All values set here are stored on our dictionary.
	[self.dictionary setObject:value forKey:key];
}

- (void)setNilValueForKey:(NSString*)key {
	// Remove values when set to nil.
	[self.dictionary removeObjectForKey:key];
}

@end

#pragma mark -

@implementation DMTemplateEngine (Strings)

+ (NSString*)_stringWithReadableByteSize:(unsigned long long)bytes {
	double kb, mb, gb, tb, pb;
	
	// Handle bytes
	if(bytes < 1000) {
		return [NSString stringWithFormat:@"%d B", (int)bytes];
	}
	
	// Handle kilobytes
	kb = bytes / 1024.0;
	if(kb < 1000.0) {
		return [NSString stringWithFormat:@"%0.1f KB", kb];
	}
	
	// Handle megabytes
	mb = kb / 1024.0;
	if(mb < 1000.0) {
		return [NSString stringWithFormat:@"%0.1f MB", mb];
	}
	
	// Handle gigabytes
	gb = mb / 1024.0;
	if(gb < 1000.0) {
		return [NSString stringWithFormat:@"%0.1f GB", gb];
	}
	
	// Handle terabytes
	tb = gb / 1024.0;
	if(tb < 1000.0) {
		return [NSString stringWithFormat:@"%0.1f TB", tb];
	}
	
	// Handle petabytes
	pb = tb / 1024.0;
	return [NSString stringWithFormat:@"%0.1f PB", pb];
}

+ (NSString*)_stringByEscapingXMLEntities:(NSString*)string {
	static const unichar nbsp = 0xA0;
	NSArray* entities = @[
		@"&amp;", @"&",
		@"&lt;", @"<",
		@"&gt;", @">",
		@"&quot;", @"\"",
		@"&apos;", @"'",
		@"&nbsp;", [NSString stringWithCharacters:&nbsp length:1],
		@"&#x09;", @"\t",
		@"&#x0A;", @"\n",
		@"&#x0B;", @"\v",
		@"&#x0C;", @"\f",
		@"&#x0D;", @"\r"
	];
	
	for(NSUInteger i = 0; i < [entities count]; i += 2) {
		NSString* entity = [entities objectAtIndex:i];
		NSString* entityChar = [entities objectAtIndex:i+1];
		string = [string stringByReplacingOccurrencesOfString:entityChar withString:entity options:NSCaseInsensitiveSearch range:NSMakeRange(0, [string length])];
	}
	
	return string;
}

+ (NSString*)_stringByAddingPercentEscapes:(NSString*)string {
	return [(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, CFSTR(""), CFSTR("/"), kCFStringEncodingUTF8) autorelease];
}

+ (NSString*)_stringByRemovingCharactersFromSet:(NSCharacterSet*)set string:(NSString*)string {
	NSMutableString* result;
	
	if([string rangeOfCharacterFromSet:set options:NSLiteralSearch].length == 0) {
		return string;
	}
	
	result = [[string mutableCopyWithZone:[string zone]] autorelease];
	[self _removeCharactersInSet:set string:result];
	
	return result;
}

+ (NSString*)_stringByTrimmingWhitespace:(NSString*)string {
	return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (void)_removeCharactersInSet:(NSCharacterSet*)set string:(NSMutableString*)string {
	NSRange matchRange, searchRange, replaceRange;
	NSUInteger length = [string length];
	
	matchRange = [string rangeOfCharacterFromSet:set options:NSLiteralSearch range:NSMakeRange(0, length)];
	while(matchRange.length > 0) {
		replaceRange = matchRange;
		searchRange.location = NSMaxRange(replaceRange);
		searchRange.length = length - searchRange.location;
		
		while(YES) {
			matchRange = [string rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange];
			if((matchRange.length == 0) || (matchRange.location != searchRange.location)) {
				break;
			}
			
			replaceRange.length += matchRange.length;
			searchRange.length -= matchRange.length;
			searchRange.location += matchRange.length;
		}
		
		[string deleteCharactersInRange:replaceRange];
		matchRange.location -= replaceRange.length;
		length -= replaceRange.length;
	}
}

@end