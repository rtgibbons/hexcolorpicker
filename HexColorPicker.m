/*
 
 BSD License
 
 Copyright (c) 2006-2010, Jesper (waffle software) <wootest@gmail.com>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 * Neither the name of Hex Color Picker or waffle software, nor the names of Hex Color Picker's
 contributors may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
 BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 For more information, see http://wafflesoftware.net/hexpicker/ .
 
 */

//
//  HexColorPicker.m
//  hexcolorpicker
//
//  Created by Jesper on 2006-02-18.
//  Copyright 2006-2010 waffle software. All rights reserved.
//

#import "HexColorPicker.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#import "WSAsyncURL.h"
#include <mach/machine.h>
#include <libkern/OSAtomic.h>

#define HexColorPickerWebsite					@"http://wafflesoftware.net/hexpicker/visit/"

#define HexColorPickerPrefCheckForUpdatesKey	@"HexColorPickerPrefCheckForUpdates"
#define HexColorPickerPrefCheckForUpdatesVal	NO

#define HexColorPickerPrefAskedAboutUpdatesKey	@"HexColorPickerPrefAskedAboutUpdates"
#define HexColorPickerPrefAskedAboutUpdatesVal	NO

#define HexColorPickerPrefLastUpdateCheckKey	@"HexColorPickerPrefLastUpdateCheck"

#define HexColorPickerPrefUppercaseHexKey	@"UppercaseHex"
#define HexColorPickerPrefUppercaseHexVal	YES

#define HexColorPickerPrefEnableShorthandKey	@"HexColorPickerPrefEnableShorthand"
#define HexColorPickerPrefEnableShorthandVal	YES

#define HexColorPickerPrefGenerateDeviceKey		@"HexColorPickerPrefGenerateDevice"
#define HexColorPickerPrefGenerateDeviceVal		NO

#define HexColorPickerPrefOptionColorStyleKey	@"HexColorPickerOptionColorStyle"
#define HexColorPickerPrefOptionColorStyleVal	@"Hex"


#define HexColorPickerUpdateServer			"wafflesoftware.net"
// yes, that above is a char *, not an NSString
#define HexColorPickerUpdateURL				@"http://wafflesoftware.net/hexpicker/updatechecker/?requestversion=2&"

#define HexColorPickerUpdateVerdict			@"Verdict"
#define HexColorPickerUpdateNewerAvailable	@"Newer version available"
#define HexColorPickerUpdateUpToDate		@"No newer version available"

#define HexColorPickerUpdateNewerURL		@"Info URL"

#define HexColorPickerUpdateNewVersion		@"New version"

#define HexColorPickerAskUpdatesMessage		HCPLocalizedString(@"Should Hex Color Picker check for updates automatically?", @"HexColorPickerAskUpdatesMessage")
#define HexColorPickerAskUpdatesInfo		HCPLocalizedString(@"Hex Color Picker can automatically check for updates periodically. You won't need to update whenever a new version appears, and no personal information will be sent in order to check for updates.", @"HexColorPickerAskUpdatesInfo")
#define HexColorPickerAskUpdatesYes			HCPLocalizedString(@"Check automatically", @"HexColorPickerAskUpdatesYes")
#define HexColorPickerAskUpdatesNo			HCPLocalizedString(@"Don't check", @"HexColorPickerAskUpdatesNo")

/* Big ups to CocoaDev! http://cocoadev.com/index.pl?NSBezierPathCategory */

@interface NSBezierPath (CocoaDevCategory)
+ (NSBezierPath*)hcp_bezierPathWithRoundRectInRect:(NSRect)aRect radius:(CGFloat)radius;
@end

@implementation NSBezierPath (CocoaDevCategory)

+ (NSBezierPath*)hcp_bezierPathWithRoundRectInRect:(NSRect)aRect radius:(CGFloat)radius
{
	NSBezierPath* path = [self bezierPath];
	radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
	NSRect rect = NSInsetRect(aRect, radius, radius);
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) 
									 radius:radius startAngle:180.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) 
									 radius:radius startAngle:270.0 endAngle:360.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) 
									 radius:radius startAngle:  0.0 endAngle: 90.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) 
									 radius:radius startAngle: 90.0 endAngle:180.0];
	[path closePath];
	return path;
}

@end

@interface HexColorPicker (Private)

- (void)hcp_syncColorAndField;
- (void)hcp_syncFieldAndColor;
- (NSString *)hcp_syncFieldAndColorWithoutChangingString;
- (void)hcp_updateColorStyles:(NSColor *)color;

- (void)hcp_updateColorStyleMenu;
- (void)hcp_readPrefs;
- (BOOL)hcp_boolPrefWithKey:(NSString *)pkey defaultValue:(BOOL)def;
- (void)hcp_setBoolPref:(BOOL)pref forKey:(NSString *)pkey;
- (NSString *)hcp_stringPrefWithKey:(NSString *)pkey;
- (void)hcp_setStringPref:(NSString *)pref forKey:(NSString *)pkey;

- (void)hcp_checkForUpdate;
- (void)hcp_checkForUpdatePrepare;
- (void)hcp_checkForUpdateGoFetch:(NSURL *)url;
- (void)hcp_checkForUpdateUIFinish:(NSDictionary *)updateDict;

- (BOOL)hcp_mayBeginCheckingForUpdate;
- (void)hcp_updateCheckingHasFinished;

- (BOOL)hcp_runsOnGC;
- (BOOL)hcp_runsOn64;
- (cpu_type_t)hcp_architecture;
- (NSString *)hcp_bundleVersion;
- (NSString *)hcp_systemVersion;
@end
@implementation HexColorPicker (Private)

static NSDictionary *htmlKeywordsToColors;

+ (void)initialize {
	/** Source of these: http://www.w3.org/TR/css3-color/#svg-color (SVG colors, actually, but the HTML colors are all in there.) **/
	htmlKeywordsToColors = [[NSDictionary dictionaryWithObjectsAndKeys:
							 @"#F0F8FF", @"aliceblue",
							 @"#FAEBD7", @"antiquewhite",
							 @"#00FFFF", @"aqua",
							 @"#7FFFD4", @"aquamarine",
							 @"#F0FFFF", @"azure",
							 @"#F5F5DC", @"beige",
							 @"#FFE4C4", @"bisque",
							 @"#000000", @"black",
							 @"#FFEBCD", @"blanchedalmond",
							 @"#0000FF", @"blue",
							 @"#8A2BE2", @"blueviolet",
							 @"#A52A2A", @"brown",
							 @"#DEB887", @"burlywood",
							 @"#5F9EA0", @"cadetblue",
							 @"#7FFF00", @"chartreuse",
							 @"#D2691E", @"chocolate",
							 @"#FF7F50", @"coral",
							 @"#6495ED", @"cornflowerblue",
							 @"#FFF8DC", @"cornsilk",
							 @"#DC143C", @"crimson",
							 @"#00FFFF", @"cyan",
							 @"#00008B", @"darkblue",
							 @"#008B8B", @"darkcyan",
							 @"#B8860B", @"darkgoldenrod",
							 @"#A9A9A9", @"darkgray",
							 @"#006400", @"darkgreen",
							 @"#A9A9A9", @"darkgrey",
							 @"#BDB76B", @"darkkhaki",
							 @"#8B008B", @"darkmagenta",
							 @"#556B2F", @"darkolivegreen",
							 @"#FF8C00", @"darkorange",
							 @"#9932CC", @"darkorchid",
							 @"#8B0000", @"darkred",
							 @"#E9967A", @"darksalmon",
							 @"#8FBC8F", @"darkseagreen",
							 @"#483D8B", @"darkslateblue",
							 @"#2F4F4F", @"darkslategray",
							 @"#2F4F4F", @"darkslategrey",
							 @"#00CED1", @"darkturquoise",
							 @"#9400D3", @"darkviolet",
							 @"#FF1493", @"deeppink",
							 @"#00BFFF", @"deepskyblue",
							 @"#696969", @"dimgray",
							 @"#696969", @"dimgrey",
							 @"#1E90FF", @"dodgerblue",
							 @"#B22222", @"firebrick",
							 @"#FFFAF0", @"floralwhite",
							 @"#228B22", @"forestgreen",
							 @"#FF00FF", @"fuchsia",
							 @"#DCDCDC", @"gainsboro",
							 @"#F8F8FF", @"ghostwhite",
							 @"#FFD700", @"gold",
							 @"#DAA520", @"goldenrod",
							 @"#808080", @"gray",
							 @"#008000", @"green",
							 @"#ADFF2F", @"greenyellow",
							 @"#808080", @"grey",
							 @"#F0FFF0", @"honeydew",
							 @"#FF69B4", @"hotpink",
							 @"#CD5C5C", @"indianred",
							 @"#4B0082", @"indigo",
							 @"#FFFFF0", @"ivory",
							 @"#F0E68C", @"khaki",
							 @"#E6E6FA", @"lavender",
							 @"#FFF0F5", @"lavenderblush",
							 @"#7CFC00", @"lawngreen",
							 @"#FFFACD", @"lemonchiffon",
							 @"#ADD8E6", @"lightblue",
							 @"#F08080", @"lightcoral",
							 @"#E0FFFF", @"lightcyan",
							 @"#FAFAD2", @"lightgoldenrodyellow",
							 @"#D3D3D3", @"lightgray",
							 @"#90EE90", @"lightgreen",
							 @"#D3D3D3", @"lightgrey",
							 @"#FFB6C1", @"lightpink",
							 @"#FFA07A", @"lightsalmon",
							 @"#20B2AA", @"lightseagreen",
							 @"#87CEFA", @"lightskyblue",
							 @"#778899", @"lightslategray",
							 @"#778899", @"lightslategrey",
							 @"#B0C4DE", @"lightsteelblue",
							 @"#FFFFE0", @"lightyellow",
							 @"#00FF00", @"lime",
							 @"#32CD32", @"limegreen",
							 @"#FAF0E6", @"linen",
							 @"#FF00FF", @"magenta",
							 @"#800000", @"maroon",
							 @"#66CDAA", @"mediumaquamarine",
							 @"#0000CD", @"mediumblue",
							 @"#BA55D3", @"mediumorchid",
							 @"#9370DB", @"mediumpurple",
							 @"#3CB371", @"mediumseagreen",
							 @"#7B68EE", @"mediumslateblue",
							 @"#00FA9A", @"mediumspringgreen",
							 @"#48D1CC", @"mediumturquoise",
							 @"#C71585", @"mediumvioletred",
							 @"#191970", @"midnightblue",
							 @"#F5FFFA", @"mintcream",
							 @"#FFE4E1", @"mistyrose",
							 @"#FFE4B5", @"moccasin",
							 @"#FFDEAD", @"navajowhite",
							 @"#000080", @"navy",
							 @"#FDF5E6", @"oldlace",
							 @"#808000", @"olive",
							 @"#6B8E23", @"olivedrab",
							 @"#FFA500", @"orange",
							 @"#FF4500", @"orangered",
							 @"#DA70D6", @"orchid",
							 @"#EEE8AA", @"palegoldenrod",
							 @"#98FB98", @"palegreen",
							 @"#AFEEEE", @"paleturquoise",
							 @"#DB7093", @"palevioletred",
							 @"#FFEFD5", @"papayawhip",
							 @"#FFDAB9", @"peachpuff",
							 @"#CD853F", @"peru",
							 @"#FFC0CB", @"pink",
							 @"#DDA0DD", @"plum",
							 @"#B0E0E6", @"powderblue",
							 @"#800080", @"purple",
							 @"#FF0000", @"red",
							 @"#BC8F8F", @"rosybrown",
							 @"#4169E1", @"royalblue",
							 @"#8B4513", @"saddlebrown",
							 @"#FA8072", @"salmon",
							 @"#F4A460", @"sandybrown",
							 @"#2E8B57", @"seagreen",
							 @"#FFF5EE", @"seashell",
							 @"#A0522D", @"sienna",
							 @"#C0C0C0", @"silver",
							 @"#87CEEB", @"skyblue",
							 @"#6A5ACD", @"slateblue",
							 @"#708090", @"slategray",
							 @"#708090", @"slategrey",
							 @"#FFFAFA", @"snow",
							 @"#00FF7F", @"springgreen",
							 @"#4682B4", @"steelblue",
							 @"#D2B48C", @"tan",
							 @"#008080", @"teal",
							 @"#D8BFD8", @"thistle",
							 @"#FF6347", @"tomato",
							 @"#40E0D0", @"turquoise",
							 @"#EE82EE", @"violet",
							 @"#F5DEB3", @"wheat",
							 @"#FFFFFF", @"white",
							 @"#F5F5F5", @"whitesmoke",
							 @"#FFFF00", @"yellow",
							 @"#9ACD32", @"yellowgreen",
							 
							 // Easter eggs!
							 @"#4B5259", @"gruber",
							 @"#F0FA3B", @"wall",
							 @"#F0FA3B", @"larry",
							 
							 // In-joke.
							 @"#0167FF", @"blew",
							 nil] retain];
}

#pragma mark System and HCP introspection

- (BOOL)hcp_runsOnGC {
	BOOL gcage = NO;
	Class gcclass = NSClassFromString(@"NSGarbageCollector");
	if (gcclass != Nil) {
		if ([gcclass performSelector:@selector(defaultCollector)]) {
			gcage = YES;
		}
	}
	return gcage;
}

- (BOOL)hcp_runsOn64 {
	return
#ifdef __LP64__
	YES
#else
	NO
#endif
	;	
}

- (cpu_type_t)hcp_architecture {
	int value = 0;
	unsigned long length = sizeof(value);
	int error = sysctlbyname("hw.cputype", &value, &length, NULL, 0);
	if (error == 0) {
		return (cpu_type_t)value;
	} else {
		return CPU_TYPE_ANY;
	}
}

- (NSString *)hcp_bundleVersion {
	NSString *bundleVersion = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleVersion"];	
	return [[bundleVersion copy] autorelease];
}

- (NSString *)hcp_systemVersion {
	return [[[[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"] copy] autorelease];
}

#pragma mark Color handling

- (void)hcp_syncColorAndField {
	NSColor *color = currColor;
	
	//NSLog(@"synccolor: %@ (class: %@)", color, [color className]);
	
	NSColor *colorInCorrectColorSpace = [color colorUsingColorSpaceName:(shouldGenerateDevice ? NSDeviceRGBColorSpace : NSCalibratedRGBColorSpace)];
	NSString *hslStr = @"?"; NSString *rgbStr = @"?"; NSString *hexStr = @"?"; BOOL rgb = NO;
	
	if (nil != colorInCorrectColorSpace) { 
		color = colorInCorrectColorSpace; 
		//		NSLog(@"color 2: %@ (class: %@)", c, [c className]);
		
		[self hcp_updateColorStyles:color];
		
		hexStr = [NSString stringWithFormat:@"#%@", [colorHex stringValue]];
		rgbStr = [NSString stringWithFormat:@"%@,%@,%@", [colorR stringValue], [colorB stringValue], [colorG stringValue]];
		hslStr = [NSString stringWithFormat:@"%@,%@%%,%@%%", [colorH stringValue], [colorS stringValue], [colorL stringValue]];
		
		rgb = YES;
	}
	
	//NSLog(@"Style %@", optionColorStyle);
	[colorDisplay setEnabled:rgb];
	if ( [optionColorStyle isEqualToString:@"RGB"]) {
		[colorDisplay setStringValue:rgbStr];
	} else if ([optionColorStyle isEqualToString:@"HSL"]) {
		[colorDisplay setStringValue:hslStr];
	} else {
		[colorDisplay setStringValue:hexStr];
	}
}

- (NSString *)hcp_syncFieldAndColorWithoutChangingString {
	NSString *baseString = [colorDisplay stringValue];
	NSString *f = [baseString uppercaseString];
	//	NSLog(@"string: %@", f);
	NSString *keywordColor = nil;
	NSScanner *sc;
	if ((keywordColor = [htmlKeywordsToColors objectForKey:[baseString lowercaseString]])) {
		sc = [NSScanner scannerWithString:[keywordColor uppercaseString]];
	} else { 
		sc = [NSScanner scannerWithString:f];
	}
	NSString *s = @"nil";
	NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
	NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	[sc scanCharactersFromSet:ws intoString:nil];
	if ([sc scanUpToCharactersFromSet:hex intoString:&s]) {
		//		NSLog(@"ate '%@'", s);
	}
	s = @"000000";
	[sc scanCharactersFromSet:ws intoString:nil];
	[sc scanCharactersFromSet:hex intoString:&s];
	NSUInteger l = [s length];
	NSString *r = @"00"; NSString *g = @"00"; NSString *b = @"00";
	if (l == 1) {
		r = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(0,1)], [s substringWithRange:NSMakeRange(0,1)]];
		g = r;
		b = r;
	} else if (l == 2) {
		r = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(0,1)], [s substringWithRange:NSMakeRange(1,1)]];
		g = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(0,1)], [s substringWithRange:NSMakeRange(1,1)]];
		b = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(0,1)], [s substringWithRange:NSMakeRange(1,1)]];	
	} else if (l == 3) {
		r = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(0,1)], [s substringWithRange:NSMakeRange(0,1)]];
		g = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(1,1)], [s substringWithRange:NSMakeRange(1,1)]];
		b = [NSString stringWithFormat:@"%@%@", [s substringWithRange:NSMakeRange(2,1)], [s substringWithRange:NSMakeRange(2,1)]];	
	} else if (l > 5) { // 6 or longer (ignore following chars)
		r = [NSString stringWithFormat:@"%@", [s substringWithRange:NSMakeRange(0,2)]];
		g = [NSString stringWithFormat:@"%@", [s substringWithRange:NSMakeRange(2,2)]];
		b = [NSString stringWithFormat:@"%@", [s substringWithRange:NSMakeRange(4,2)]];		
	}
	
	unsigned ri; unsigned gi; unsigned bi;
	sc = [NSScanner scannerWithString:r];
	[sc scanHexInt:&ri];
	sc = [NSScanner scannerWithString:g];
	[sc scanHexInt:&gi];
	sc = [NSScanner scannerWithString:b];
	[sc scanHexInt:&bi];
	
	double rc = (double)(ri/255.0);
	double gc = (double)(gi/255.0);
	double bc = (double)(bi/255.0);
	
	
	NSColor *c = (shouldGenerateDevice ? [NSColor colorWithDeviceRed:rc green:gc blue:bc alpha:1.0] : [NSColor colorWithCalibratedRed:rc green:gc blue:bc alpha:1.0]);
	//	NSLog(@"color: %@", c);
	
	[self hcp_updateColorStyles:c];
	
	holdTheFormat = YES;
	[[self colorPanel] setColor:c];	
	holdTheFormat = NO;
	
	s = [NSString stringWithFormat:@"#%02X%02X%02X",
		 (unsigned int)ri,
		 (unsigned int)gi,
		 (unsigned int)bi];
	if (!uppercasesHex) s = [s lowercaseString];
	
	return s;
	
}

- (void)hcp_syncFieldAndColor {
	
	NSString *s = [self hcp_syncFieldAndColorWithoutChangingString];
	
	if ([optionColorStyle isEqualToString:@"RGB"]) {
		s = [NSString stringWithFormat:@"%@,%@,%@", [colorR stringValue], [colorG stringValue], [colorB stringValue]];
	} else if ([optionColorStyle isEqualToString:@"HSL"]) {
		s = [NSString stringWithFormat:@"%@,%@%%,%@%%", [colorH stringValue], [colorS stringValue], [colorL stringValue]];
	}
	
	[colorDisplay setStringValue:s];
	
}

- (void)hcp_updateColorStyles:(NSColor *)color {
	NSString *r = @"?"; NSString *g = @"?"; NSString *b = @"?";
	NSString *h = @"?"; NSString *s = @"?"; NSString *l = @"?";
	NSString *hex = @"?";
	
	CGFloat hi = 0.0; CGFloat li = 0.0; CGFloat si = 0.0;
	//Gathered formula below from http://ariya.blogspot.com/2008/07/converting-between-hsl-and-hsv.html
	hi = [color hueComponent];
	li = (2 - [color saturationComponent]) * [color brightnessComponent];
	si = [color saturationComponent] * [color brightnessComponent];
	si = (li == 0) ? 0 : (si /= (li <= 1) ? (li) : 2 - (li));
	li /= 2;
	
	//NSLog(@"hsl float: %f %f %f", (360*hi), (100*si), (100*li));
	//NSLog(@"hsl values: %d %d %d", (unsigned int)(hi*360+0.5), (unsigned int)(si*100+0.5), (unsigned int)(li*100+0.5));
	h = [NSString stringWithFormat:@"%d", (unsigned int)(hi*360+0.5)];
	s = [NSString stringWithFormat:@"%d", (unsigned int)(si*100+0.5)];
	l = [NSString stringWithFormat:@"%d", (unsigned int)(li*100+0.5)];
	
	r = [NSString stringWithFormat:@"%d", (unsigned int)(255*[color redComponent])];
	g = [NSString stringWithFormat:@"%d", (unsigned int)(255*[color greenComponent])];
	b = [NSString stringWithFormat:@"%d", (unsigned int)(255*[color blueComponent])];
	
	hex = [NSString stringWithFormat:@"%02X%02X%02X",
		   (unsigned int)(255*[color redComponent]),
		   (unsigned int)(255*[color greenComponent]),
		   (unsigned int)(255*[color blueComponent])];
	if (!uppercasesHex) hex = [hex lowercaseString];
	
	
	[colorR setStringValue:r];
	[colorG setStringValue:g];
	[colorB setStringValue:b];
	
	[colorH setStringValue:h];
	[colorS setStringValue:s];
	[colorL setStringValue:l];
	
	[colorHex setStringValue:hex];
	
}

#pragma mark Preferences

- (BOOL)hcp_boolPrefWithKey:(NSString *)pkey defaultValue:(BOOL)def {
	//	NSLog(@"bool pref %@?", pkey);
	CFPreferencesSynchronize(kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	CFPropertyListRef lr = CFPreferencesCopyValue((CFStringRef)pkey,kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	if (lr == NULL) {
		//		NSLog(@"- saved pref is null; pref %@ is %@", pkey, def ? @"Y" : @"N");
		return def;
	}
	BOOL retVal = def;
	if (CFGetTypeID(lr) == CFBooleanGetTypeID()) {
		retVal = (lr == kCFBooleanTrue);
		//		NSLog(@"- pref %@ is %@", pkey, retVal ? @"Y" : @"N");
	} else {
		//		NSLog(@"- pref is not boolean; pref %@ is %@", pkey, def ? @"Y" : @"N");
	}
	CFRelease(lr);
	return retVal;
}

- (void)hcp_setBoolPref:(BOOL)pref forKey:(NSString *)pkey {
	//	NSLog(@"set bool pref %@ to %@", pkey, (pref ? @"Y" : @"N"));
	CFPreferencesSetValue((CFStringRef)pkey, (pref ? kCFBooleanTrue : kCFBooleanFalse), kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	CFPreferencesSynchronize(kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
}

- (NSString *)hcp_stringPrefWithKey:(NSString *)pkey {
	CFPreferencesSynchronize(kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	CFPropertyListRef lr = CFPreferencesCopyValue((CFStringRef)pkey,kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	if (lr == NULL) return @"";
	// make it work with GC (otherwise we'd return a CF object with a +1 retain count)
	NSString *returnValue = [((NSString *)lr) copy];
	CFRelease(lr);
	return [returnValue autorelease];
}

- (void)hcp_setStringPref:(NSString *)pref forKey:(NSString *)pkey {
	CFPreferencesSetValue((CFStringRef)pkey, ((CFStringRef)pref), kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
	CFPreferencesSynchronize(kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesCurrentHost);
}

- (void)hcp_readPrefs {
	hasAskedAboutUpdates = [self hcp_boolPrefWithKey:HexColorPickerPrefAskedAboutUpdatesKey defaultValue:HexColorPickerPrefAskedAboutUpdatesVal];
	shouldCheckForUpdates = [self hcp_boolPrefWithKey:HexColorPickerPrefCheckForUpdatesKey defaultValue:HexColorPickerPrefCheckForUpdatesVal];
	uppercasesHex = [self hcp_boolPrefWithKey:HexColorPickerPrefUppercaseHexKey defaultValue:HexColorPickerPrefUppercaseHexVal];
	shouldEnableShorthand = [self hcp_boolPrefWithKey:HexColorPickerPrefEnableShorthandKey defaultValue:HexColorPickerPrefEnableShorthandVal];
	shouldGenerateDevice = [self hcp_boolPrefWithKey:HexColorPickerPrefGenerateDeviceKey defaultValue:HexColorPickerPrefGenerateDeviceVal];
	optionColorStyle = [self hcp_stringPrefWithKey:HexColorPickerPrefOptionColorStyleKey];
	if ([optionColorStyle isEqualToString:@""]) {
		optionColorStyle = HexColorPickerPrefOptionColorStyleVal;
	}
	
	[self hcp_updateColorStyleMenu];
	[self hcp_checkForUpdate];
}

- (void)hcp_updateColorStyleMenu {
	[colorStyleHex setState:NSOffState];
	[colorStyleRGB setState:NSOffState];
	[colorStyleHSL setState:NSOffState];
	if ([optionColorStyle isEqualToString:@"Hex"]) {
		[colorStyleHex setState:NSOnState];
	} else if ([optionColorStyle isEqualToString:@"RGB"]) {
		[colorStyleRGB setState:NSOnState];
	} else if ([optionColorStyle isEqualToString:@"HSL"]) {
		[colorStyleHSL setState:NSOnState];
	}
}

- (void)hcp_askAboutUpdatesAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo {
	//	NSLog(@"alert did end: %i", returnCode);
	[self hcp_setBoolPref:YES forKey:HexColorPickerPrefAskedAboutUpdatesKey];
	hasAskedAboutUpdates = YES;
	[self hcp_setBoolPref:(returnCode == NSAlertDefaultReturn) forKey:HexColorPickerPrefCheckForUpdatesKey];
	shouldCheckForUpdates = (returnCode == NSAlertDefaultReturn);
	//	NSLog(@"hex color picker: should check? %i", returnCode);
	if (returnCode == NSAlertDefaultReturn) [self hcp_checkForUpdate];
}

- (BOOL)hcp_mayBeginCheckingForUpdate {
	// Check, atomically, whether an update is already in progress, and don't do anything if it is.
	// This flag is int32_t because that's the smallest type for which Apple provides this function.
	// The flag is unset on every error condition, or when the update is complete, in hcp_updateCheckingHasFinished.
	if (OSAtomicCompareAndSwap32Barrier((int32_t)NO, (int32_t)YES, &isCheckingForUpdatesRightNow)) {
		return YES;
	} else {
		return NO;
	}
}

- (void)hcp_updateCheckingHasFinished {
	OSAtomicCompareAndSwap32Barrier((int32_t)YES, (int32_t)NO, &isCheckingForUpdatesRightNow);
}

- (void)hcp_checkForUpdatePrepare {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// First, check for 'reachability' (can we reach the update server without establishing a new connection?
	SCNetworkReachabilityRef target;
	SCNetworkConnectionFlags flags = 0;
	Boolean success;
	target = SCNetworkReachabilityCreateWithName(NULL, HexColorPickerUpdateServer);
	success = SCNetworkReachabilityGetFlags(target, &flags);
	CFRelease(target);
	
	//	NSLog(@"reachable?");
	if(!success || (!((flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired)))) {
		[self hcp_updateCheckingHasFinished];
		goto bail; // Instead of return; have to drain the autorelease pool.
	}
	//	NSLog(@"apparently");
	
	NSString *systemVersion = [[self hcp_systemVersion] retain];
	if (!systemVersion) systemVersion = @"?";
	cpu_type_t cpuArch = [self hcp_architecture];
	NSString *cpu = @"?";
	switch (cpuArch) {
		case CPU_TYPE_X86:
			cpu = @"x86";
			break;
		case CPU_TYPE_X86_64:
			cpu = @"x86-64";
			break;
			
			// not defined in 10.4 SDK
#ifndef CPU_TYPE_ARM
#define CPU_TYPE_ARM		((cpu_type_t) 12)
#endif
		case CPU_TYPE_ARM:
			cpu = @"arm";
			break;
		case CPU_TYPE_POWERPC:
			cpu = @"ppc";
			break;
		case CPU_TYPE_POWERPC64:
			cpu = @"ppc-64";
			break;
	}
	
	NSString *bundleVersion = [[self hcp_bundleVersion] retain];
	
	// Now, do the actual check.
	// Suck down dictionary that results in a call to the update server.
	// (We supply our version number, which saves version comparison heuristics in this class.)
	NSString *upURLString = [NSString stringWithFormat:@"%@v=%@&osxversion=%@&arch=%@", 
							 HexColorPickerUpdateURL, 
							 bundleVersion,
							 systemVersion,
							 cpu
							 ];
	
	[systemVersion release];
	[bundleVersion release];
	
	[self hcp_setStringPref:[[NSDate date] description] forKey:HexColorPickerPrefLastUpdateCheckKey];
	
	NSURL *upURL = [NSURL URLWithString:upURLString];
	
	// If I don't run this on the main thread, it just dies.
	// Either something goes away with autorelease (and I retain everything!)
	// or it just doesn't like continuing to load when the thread it was started on
	// was stopped (which is bogus, it should isolate this coordination elsewhere).
	[self performSelectorOnMainThread:@selector(hcp_checkForUpdateGoFetch:) withObject:[upURL retain] waitUntilDone:YES];
	//	[self hcp_checkForUpdateGoFetch:[upURL retain]];
	//	NSLog(@"hex color picker: updateurl: %@", upURL);
	
bail:
	[pool drain];
}

- (void)hcp_checkForUpdateGoFetch:(NSURL *)url {
	// Cross the network in the background, please.
	[WSAsyncURL fetchURL:[url autorelease]
			loadDelegate:self
		 successSelector:@selector(hcp_receivedUpdateDictData:)
			failSelector:@selector(hcp_failedUpdateCheck:)];
}

- (void)hcp_receivedUpdateDictData:(NSData *)data {
	NSPropertyListFormat plistFormat;
	NSString *errString;
	NSDictionary *updateDict = [[NSPropertyListSerialization 
								 propertyListFromData:data
								 mutabilityOption:NSPropertyListImmutable 
								 format:&plistFormat 
								 errorDescription:&errString] retain];
	if (errString) [errString release];
	
	if (![updateDict isKindOfClass:[NSDictionary class]]) {
		[updateDict release];
		updateDict = nil;
	}
	
	//	NSLog(@"hex color picker: updatedict: %@", updateDict);
	
	if (!updateDict || [updateDict count]<1) {
		[updateDict release];
		[self hcp_updateCheckingHasFinished];
		return;
	}
	
	[self performSelectorOnMainThread:@selector(hcp_checkForUpdateUIFinish:) withObject:[updateDict copy] waitUntilDone:NO];
	[updateDict release];
}

- (void)hcp_failedUpdateCheck:(NSError *)err {
	[self hcp_updateCheckingHasFinished];
	//	NSLog(@"hex color picker: update check failed (%@)", err);
}

- (void)hcp_checkForUpdateUIFinish:(NSDictionary *)updateDict {
	NSString *verdict = [[updateDict objectForKey:HexColorPickerUpdateVerdict] copy];
	
	[self hcp_updateCheckingHasFinished];
	
	if (!verdict) {
		[updateDict release];
		return;
	}
	if ([verdict isEqualToString:HexColorPickerUpdateNewerAvailable]) {
		NSString *infourl = [updateDict objectForKey:HexColorPickerUpdateNewerURL];
		if (updateInfoURL) [updateInfoURL release];
		updateInfoURL = [[NSURL alloc] initWithString:infourl];
		NSString *v = [updateDict objectForKey:HexColorPickerUpdateNewVersion];
		[goUpgrade setHidden:NO];
		[goUpgrade setTitle:[NSString stringWithFormat:HCPLocalizedString(@"Upgrade to v%@", @"HexColorPickerGetVersionFormat"), v]];
	}
	[verdict release];		
	[updateDict release];
}

- (void)hcp_checkForUpdate {
	
	[self hcp_mayBeginCheckingForUpdate];
	
	//	NSLog(@"hcp_checkForUpdate: should? %@ has? %@", (shouldCheckForUpdates ? @"YES" : @"NO"), (hasAskedAboutUpdates ? @"YES" : @"NO"));
	
	if (!shouldCheckForUpdates) {
		if (!hasAskedAboutUpdates) {
			if (!alertIsUp) {
				NSAlert *askingAboutUpdates = [NSAlert alertWithMessageText:HexColorPickerAskUpdatesMessage defaultButton:HexColorPickerAskUpdatesYes alternateButton:HexColorPickerAskUpdatesNo otherButton:nil informativeTextWithFormat:HexColorPickerAskUpdatesInfo];
				[askingAboutUpdates beginSheetModalForWindow:[colorPickerView window] modalDelegate:self didEndSelector:@selector(hcp_askAboutUpdatesAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
				alertIsUp = YES;
			}
		}
		[self hcp_updateCheckingHasFinished];
		return;
	}
	
	// In a perfect world, this would be a date setting, but it's more confusing to change it now.
	NSString *lastDateString = [self hcp_stringPrefWithKey:HexColorPickerPrefLastUpdateCheckKey];
	if (lastDateString && ![@"" isEqualToString:[lastDateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]) {
		NSDate *lastDate = [NSDate dateWithString:lastDateString];
		NSDate *now = [NSDate date];
		//		NSLog(@"lastDate: <%@> %@, now: %@", lastDateString, lastDate, now);
		if ([(NSDate *)[now addTimeInterval:(NSTimeInterval)(-(60.0*60.0*12.0))] compare:lastDate] != NSOrderedDescending) {
			// Never check more than twice a day.
			//			NSLog(@"don't check...");
			[self hcp_updateCheckingHasFinished];
			return;
		}
	}
	
	// Under some odd conditions, even the reachability check can block.
 	// For that reason, if we're to check updates *really* synchronously, detach to a new thread.
	[NSThread detachNewThreadSelector:@selector(hcp_checkForUpdatePrepare) toTarget:self withObject:nil];
	
}

@end

@implementation HexColorPicker

- (void)dealloc {
	[currColor release];
	[updateInfoURL release];
	
	[super dealloc];
}

- (NSSize)minContentSize {
	return NSMakeSize(210.0, 180.0);
}

- (IBAction)copyToClipboard:(id)sender {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSColorPboardType, nil] owner:nil];
	
	NSString *copying = [colorHex stringValue];
	
	NSText *fe = [[colorHex window] fieldEditor:NO forObject:colorHex];
	if (fe != nil) {
		NSRange r = [fe selectedRange];
		if (!(r.location == NSNotFound || r.length == 0)) {
			copying = [copying substringWithRange:r];
		}
	}
	
	[pb setString:copying forType:NSStringPboardType];
	[[[self colorPanel] color] writeToPasteboard:pb];
}

- (IBAction)updateColorStyle:(id)sender {
	//NSLog(@"Current Title %@", [sender title]);
	
	NSString *ocs = [sender title];
	
	if (optionColorStyle != ocs) {
		[self hcp_setStringPref:ocs forKey:HexColorPickerPrefOptionColorStyleKey];
		optionColorStyle = ocs;
		
		[self hcp_updateColorStyleMenu];
		
		[self hcp_syncColorAndField];
	}
}

- (NSView *)provideNewView:(BOOL)initialRequest {
	if (initialRequest) {
		BOOL loaded = [NSBundle loadNibNamed:@"HexPicker" owner:self];
		NSAssert((loaded == YES), @"NIB did not load");
		
#ifdef HCP_BUILD_TIGER
		[[cogButton cell] setArrowPosition:NSPopUpNoArrow];
		[[cogMenu itemAtIndex:0] setImage:[[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"cog-tiger" ofType:@"tiff"]] autorelease]];
#endif
		[cogButton setMenu:cogMenu];
		
		
	}
	NSAssert((nil != colorPickerView), @"colorPickerView is nil!");
	
	//	NSLog(@"provide new view");
	[self hcp_readPrefs];
	
	return colorPickerView;
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
	//	NSLog(@"color hex text did change: %@", [colorHex stringValue]);
	[self hcp_syncFieldAndColorWithoutChangingString];
}

- (void)setColor:(NSColor *)color {
	//	NSLog(@"setcolor: %@ (hold the format? %@)", color, (holdTheFormat ? @"yep" : @"nope"));
	
	[currColor release];
	currColor = [color retain];
	
	if (!holdTheFormat)
		[self hcp_syncColorAndField];
}

- (BOOL)supportsMode:(NSInteger)mode {
	switch (mode) {
		case NSColorPanelAllModesMask:
			return YES;
	}
	return NO;
}
- (NSInteger)currentMode {
	return NSColorPanelAllModesMask;
}

- (IBAction)colorChanged:(id)sender {
	//	NSLog(@"color changed: %@", sender);
	//	NSLog(@"field editor object: %@", [[colorHex window] fieldEditor:YES forObject:colorHex]);
	
	[self hcp_syncFieldAndColor];
}

- (NSImage *)provideNewButtonImage {
	NSImage *im;
	
	im = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"icon" ofType:@"icns"]];
	[im setScalesWhenResized:YES];
	[im setSize:NSMakeSize(32.0,32.0)];
	
	return [im autorelease];
}

- (IBAction)visitWebsite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:HexColorPickerWebsite]];
}

- (IBAction)goUpgrade:(id)sender {
	if (updateInfoURL)
		[[NSWorkspace sharedWorkspace] openURL:updateInfoURL];
}

- (IBAction)showAboutPanel:(id)sender {
	NSString *bundleVersion = [self hcp_bundleVersion];
	if (bundleVersion == nil || [bundleVersion isEqualToString:@""]) {
		bundleVersion = @"?";
	}
	NSString *bittage = ([self hcp_runsOn64] ? @"64" : @"32");
	NSString *gcage = ([self hcp_runsOnGC] ? @", GC" : @"");
	
	[aboutVersionField setStringValue:[NSString stringWithFormat:@"%@ (%@-bit%@)", bundleVersion, bittage, gcage]];
	[NSApp beginSheet:aboutPanel modalForWindow:[colorPickerView window] modalDelegate:self didEndSelector:@selector(aboutSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)closeAboutPanel:(id)sender {
	[NSApp endSheet:aboutPanel];
}

- (IBAction)showPrefs:(id)sender {
	[useUpperHex setState:(uppercasesHex ? NSOnState : NSOffState)];
	[checkForUpdates setState:(shouldCheckForUpdates ? NSOnState : NSOffState)];
	[enableShorthand setState:(shouldEnableShorthand ? NSOnState : NSOffState)];
	[useDeviceColors setState:(shouldGenerateDevice ? NSOnState : NSOffState)];
	[NSApp beginSheet:colorPickerPrefs modalForWindow:[colorPickerView window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)aboutSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	[sheet orderOut:self];	
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	
	[sheet orderOut:self];
	
	//	NSLog(@"sheet did end");
	[self hcp_readPrefs];
}

- (IBAction)savePrefs:(id)sender {
	BOOL cfu = ([checkForUpdates state] == NSOnState);
	BOOL uch = ([useUpperHex state] == NSOnState);
	BOOL usk = ([enableShorthand state] == NSOnState);
	BOOL gdv = ([useDeviceColors state] == NSOnState);
	[self hcp_setBoolPref:cfu forKey:HexColorPickerPrefCheckForUpdatesKey];
	shouldCheckForUpdates = cfu;
	[self hcp_setBoolPref:uch forKey:HexColorPickerPrefUppercaseHexKey];
	uppercasesHex = uch;
	[self hcp_setBoolPref:usk forKey:HexColorPickerPrefEnableShorthandKey];
	shouldEnableShorthand = usk;
	[self hcp_setBoolPref:gdv forKey:HexColorPickerPrefGenerateDeviceKey];
	shouldGenerateDevice = gdv;
	
	NSString *hex = [[colorHex stringValue] lowercaseString];
	if (uch) hex = [hex uppercaseString];
	[colorHex setStringValue:hex];
	[colorHex display];
	
	[self hcp_syncColorAndField];
	
    [NSApp endSheet:colorPickerPrefs];	
}

#define HexColorPickerAppName		HCPLocalizedString(@"Hex Color Picker", @"HexColorPickerAppName")

// private API pre-10.5; the only way you could customize the tool tip.
- (NSString *)_buttonToolTip {
	return HexColorPickerAppName;
}

// new, official API in 10.5
- (NSString *)buttonToolTip {
	return HexColorPickerAppName;
}

- (NSString *)description {
	return HexColorPickerAppName;
}


@end
