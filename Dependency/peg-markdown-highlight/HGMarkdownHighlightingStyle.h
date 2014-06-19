/* PEG Markdown Highlight
 * Copyright 2011-2013 Ali Rantakari -- http://hasseg.org
 * Licensed under the GPL2+ and MIT licenses (see LICENSE for more info).
 * 
 * HGMarkdownHighlightingStyle.h
 */

#import <Cocoa/Cocoa.h>
#import "pmh_definitions.h"
#import "pmh_styleparser.h"


#define HG_MKSTYLE(elem, add, remove, traits)	[[HGMarkdownHighlightingStyle alloc] initWithType:(elem) attributesToAdd:(add) toRemove:(remove) fontTraitsToAdd:(traits)]
#define HG_D(...)	[NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__, nil]
#define HG_A(...)	[NSArray arrayWithObjects:__VA_ARGS__, nil]

#define HG_FORE			NSForegroundColorAttributeName
#define HG_BACK			NSBackgroundColorAttributeName

#define HG_COLOR_RGB(r,g,b)	[NSColor colorWithCalibratedRed:(r) green:(g) blue:(b) alpha:1.0]
#define HG_COLOR_HSB(h,s,b)	[NSColor colorWithCalibratedHue:(h) saturation:(s) brightness:(b) alpha:1.0]
#define HG_COLOR_HEX(hex)	HG_COLOR_RGB(((hex & 0xFF0000) >> 16)/255.0, ((hex & 0xFF00) >> 8)/255.0, (hex & 0xFF)/255.0)

// brightness/saturation
#define HG_VDARK(h)	HG_COLOR_HSB(h, 0.7, 0.1)
#define HG_DARK(h)	HG_COLOR_HSB(h, 1, 0.4)
#define HG_MED(h)	HG_COLOR_HSB(h, 1, 1)
#define HG_LIGHT(h)	HG_COLOR_HSB(h, 0.2, 1)
#define HG_DIM(h)	HG_COLOR_HSB(h, 0.2, 0.5)

// version of color 'c' with alpha 'a'
#define HG_ALPHA(c,a) [NSColor colorWithCalibratedHue:[c hueComponent] saturation:[c saturationComponent] brightness:[c brightnessComponent] alpha:(a)]

// hues
#define HG_GREEN	0.34
#define HG_YELLOW	0.15
#define HG_BLUE		0.67
#define HG_RED		0
#define HG_MAGENTA	0.87
#define HG_CYAN		0.5

#define HG_DARK_GRAY	HG_COLOR_HSB(0, 0, 0.2)
#define HG_MED_GRAY		HG_COLOR_HSB(0, 0, 0.5)
#define HG_LIGHT_GRAY	HG_COLOR_HSB(0, 0, 0.9)


extern NSString * const HGFontInformation;
extern NSString * const HGFontInformationNameKey;
extern NSString * const HGFontInformationSizeKey;


/**
 * \brief Highlighting style definition for a Markdown language element.
 *
 * Contains information on the styles to use to highlight occurrences
 * of a specific Markdown language element. You populate
 * HGMarkdownHighlighter::styles with instances of this class to set
 * the highlighting styles.
 */
@interface HGMarkdownHighlightingStyle : NSObject

+ (NSColor *) colorFromARGBColor:(pmh_attr_argb_color *)argb_color;

/** \brief Init a new instance. */
- (instancetype) initWithType:(pmh_element_type)elemType
              attributesToAdd:(NSDictionary *)toAdd
                     toRemove:(NSArray *)toRemove
              fontTraitsToAdd:(NSFontTraitMask)traits;

/** \brief Init a new instance based on styles from the stylesheet parser. */
- (instancetype) initWithStyleAttributes:(pmh_style_attribute *)attributes baseFont:(NSFont *)baseFont;

/** \brief The Markdown language element type these styles pertain to. */
@property pmh_element_type elementType;

/** \brief A bitmask of the font traits to add.
 * 
 * If you want to remove certain font traits in this
 * style, use the 'opposite' traits (e.g. NSUnboldFontMask
 * to remove the 'bold' trait).
 */
@property NSFontTraitMask fontTraitsToAdd;

/** \brief The string attributes to add.
 * 
 * This dictionary should be in the same format you would
 * use for manipulating styles in an NSMutableAttributedString
 * directly.
 */
@property(copy) NSDictionary *attributesToAdd;

/** \brief The names of attributes to remove.
 * 
 * Populate this array with attribute names (such as
 * NSForegroundColorAttributeName).
 */
@property(copy) NSArray *attributesToRemove;

@end
