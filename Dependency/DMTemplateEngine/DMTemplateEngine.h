
// DMTemplateEngine.h
// Dustin Mierau
// Cared for under the MIT license.

@interface DMTemplateEngine : NSObject

@property (nonatomic, retain) NSString* template;
@property (nonatomic, retain) NSString* beginProcessorMarker; // Default: {%
@property (nonatomic, retain) NSString* endProcessorMarker; // Default: %}

+ (id)engine;
+ (id)engineWithTemplate:(NSString*)string;

// Render
- (NSString*)renderAgainst:(id)object;

// Modifiers
- (void)addModifier:(unichar)modifier block:(NSString*(^)(NSString*))block;
- (void)removeModifier:(unichar)modifier;
- (void)removeAllModifiers;

@end