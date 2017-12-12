//
//  NSColor+HTML.m
//  MacDown
//
//  Created by Tzu-ping Chung on 13/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSColor+HTML.h"

@implementation NSColor (HTML)

+ (NSColor *)colorWithHexString:(NSString *)string
{
    if (string.length != 6 && string.length != 3)
        return nil;

    NSUInteger digits = string.length / 3;
    unsigned int max = (digits == 1) ? 15 : 255;

    unsigned int result = 0;
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner scanHexInt:&result];

    // BGR (because we work from the end).
    CGFloat components[3] = {0.0, 0.0, 0.0};
    for (int i = 0; i < 3; i++)
    {
        components[i] = (result % (max + 1)) / (max * 1.0);
        result /= (max + 1);
    }

    return [NSColor colorWithRed:components[2] green:components[1]
                            blue:components[0] alpha:1.0];
}

// Implementation based on DTCoreText.
+ (NSColor *)colorWithHTMLName:(NSString *)name
{
    static NSCharacterSet *rgba = nil;
    static NSCharacterSet *rgb = nil;
    static NSDictionary *colorNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rgba = [NSCharacterSet characterSetWithCharactersInString:@"rgba() "];
        rgb = [NSCharacterSet characterSetWithCharactersInString:@"rgb() "];
        colorNames = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"F0F8FF", @"aliceblue",
                       @"FAEBD7", @"antiquewhite",
                       @"00FFFF", @"aqua",
                       @"7FFFD4", @"aquamarine",
                       @"F0FFFF", @"azure",
                       @"F5F5DC", @"beige",
                       @"FFE4C4", @"bisque",
                       @"000000", @"black",
                       @"FFEBCD", @"blanchedalmond",
                       @"0000FF", @"blue",
                       @"8A2BE2", @"blueviolet",
                       @"A52A2A", @"brown",
                       @"DEB887", @"burlywood",
                       @"5F9EA0", @"cadetblue",
                       @"7FFF00", @"chartreuse",
                       @"D2691E", @"chocolate",
                       @"FF7F50", @"coral",
                       @"6495ED", @"cornflowerblue",
                       @"FFF8DC", @"cornsilk",
                       @"DC143C", @"crimson",
                       @"00FFFF", @"cyan",
                       @"00008B", @"darkblue",
                       @"008B8B", @"darkcyan",
                       @"B8860B", @"darkgoldenrod",
                       @"A9A9A9", @"darkgray",
                       @"A9A9A9", @"darkgrey",
                       @"006400", @"darkgreen",
                       @"BDB76B", @"darkkhaki",
                       @"8B008B", @"darkmagenta",
                       @"556B2F", @"darkolivegreen",
                       @"FF8C00", @"darkorange",
                       @"9932CC", @"darkorchid",
                       @"8B0000", @"darkred",
                       @"E9967A", @"darksalmon",
                       @"8FBC8F", @"darkseagreen",
                       @"483D8B", @"darkslateblue",
                       @"2F4F4F", @"darkslategray",
                       @"2F4F4F", @"darkslategrey",
                       @"00CED1", @"darkturquoise",
                       @"9400D3", @"darkviolet",
                       @"FF1493", @"deeppink",
                       @"00BFFF", @"deepskyblue",
                       @"696969", @"dimgray",
                       @"696969", @"dimgrey",
                       @"1E90FF", @"dodgerblue",
                       @"B22222", @"firebrick",
                       @"FFFAF0", @"floralwhite",
                       @"228B22", @"forestgreen",
                       @"FF00FF", @"fuchsia",
                       @"DCDCDC", @"gainsboro",
                       @"F8F8FF", @"ghostwhite",
                       @"FFD700", @"gold",
                       @"DAA520", @"goldenrod",
                       @"808080", @"gray",
                       @"808080", @"grey",
                       @"008000", @"green",
                       @"ADFF2F", @"greenyellow",
                       @"F0FFF0", @"honeydew",
                       @"FF69B4", @"hotpink",
                       @"CD5C5C", @"indianred",
                       @"4B0082", @"indigo",
                       @"FFFFF0", @"ivory",
                       @"F0E68C", @"khaki",
                       @"E6E6FA", @"lavender",
                       @"FFF0F5", @"lavenderblush",
                       @"7CFC00", @"lawngreen",
                       @"FFFACD", @"lemonchiffon",
                       @"ADD8E6", @"lightblue",
                       @"F08080", @"lightcoral",
                       @"E0FFFF", @"lightcyan",
                       @"FAFAD2", @"lightgoldenrodyellow",
                       @"D3D3D3", @"lightgray",
                       @"D3D3D3", @"lightgrey",
                       @"90EE90", @"lightgreen",
                       @"FFB6C1", @"lightpink",
                       @"FFA07A", @"lightsalmon",
                       @"20B2AA", @"lightseagreen",
                       @"87CEFA", @"lightskyblue",
                       @"778899", @"lightslategray",
                       @"778899", @"lightslategrey",
                       @"B0C4DE", @"lightsteelblue",
                       @"FFFFE0", @"lightyellow",
                       @"00FF00", @"lime",
                       @"32CD32", @"limegreen",
                       @"FAF0E6", @"linen",
                       @"FF00FF", @"magenta",
                       @"800000", @"maroon",
                       @"66CDAA", @"mediumaquamarine",
                       @"0000CD", @"mediumblue",
                       @"BA55D3", @"mediumorchid",
                       @"9370D8", @"mediumpurple",
                       @"3CB371", @"mediumseagreen",
                       @"7B68EE", @"mediumslateblue",
                       @"00FA9A", @"mediumspringgreen",
                       @"48D1CC", @"mediumturquoise",
                       @"C71585", @"mediumvioletred",
                       @"191970", @"midnightblue",
                       @"F5FFFA", @"mintcream",
                       @"FFE4E1", @"mistyrose",
                       @"FFE4B5", @"moccasin",
                       @"FFDEAD", @"navajowhite",
                       @"000080", @"navy",
                       @"FDF5E6", @"oldlace",
                       @"808000", @"olive",
                       @"6B8E23", @"olivedrab",
                       @"FFA500", @"orange",
                       @"FF4500", @"orangered",
                       @"DA70D6", @"orchid",
                       @"EEE8AA", @"palegoldenrod",
                       @"98FB98", @"palegreen",
                       @"AFEEEE", @"paleturquoise",
                       @"D87093", @"palevioletred",
                       @"FFEFD5", @"papayawhip",
                       @"FFDAB9", @"peachpuff",
                       @"CD853F", @"peru",
                       @"FFC0CB", @"pink",
                       @"DDA0DD", @"plum",
                       @"B0E0E6", @"powderblue",
                       @"800080", @"purple",
                       @"FF0000", @"red",
                       @"BC8F8F", @"rosybrown",
                       @"4169E1", @"royalblue",
                       @"8B4513", @"saddlebrown",
                       @"FA8072", @"salmon",
                       @"F4A460", @"sandybrown",
                       @"2E8B57", @"seagreen",
                       @"FFF5EE", @"seashell",
                       @"A0522D", @"sienna",
                       @"C0C0C0", @"silver",
                       @"87CEEB", @"skyblue",
                       @"6A5ACD", @"slateblue",
                       @"708090", @"slategray",
                       @"708090", @"slategrey",
                       @"FFFAFA", @"snow",
                       @"00FF7F", @"springgreen",
                       @"4682B4", @"steelblue",
                       @"D2B48C", @"tan",
                       @"008080", @"teal",
                       @"D8BFD8", @"thistle",
                       @"FF6347", @"tomato",
                       @"40E0D0", @"turquoise",
                       @"EE82EE", @"violet",
                       @"F5DEB3", @"wheat",
                       @"FFFFFF", @"white",
                       @"F5F5F5", @"whitesmoke",
                       @"FFFF00", @"yellow",
                       @"9ACD32", @"yellowgreen",
                       nil];
    });

    if ([name hasPrefix:@"#"])
        return [NSColor colorWithHexString:[name substringFromIndex:1]];

    if ([name hasPrefix:@"rgba"])
    {
        name = [name stringByTrimmingCharactersInSet:rgba];
        NSArray *components = [name componentsSeparatedByString:@","];
        if (components.count != 4)
            return nil;

        return [NSColor colorWithRed:[components[0] doubleValue] / 255.0
                               green:[components[1] doubleValue] / 255.0
                                blue:[components[2] doubleValue] / 255.0
                               alpha:[components[3] doubleValue]];
    }
    if ([name hasPrefix:@"rgb"])
    {
        name = [name stringByTrimmingCharactersInSet:rgb];
        NSArray *components = [name componentsSeparatedByString:@","];
        if (components.count != 3)
            return nil;

        return [NSColor colorWithRed:[components[0] doubleValue] / 255.0
                               green:[components[1] doubleValue] / 255.0
                                blue:[components[2] doubleValue] / 255.0
                               alpha:1.0];
    }
    return [NSColor colorWithHexString:colorNames[name.lowercaseString]];
}

@end
