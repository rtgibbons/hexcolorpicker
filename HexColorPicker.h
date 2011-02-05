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
//  HexColorPicker.h
//  hexcolorpicker
//
//  Created by Jesper on 2006-02-18.
//  Copyright 2006-2010 waffle software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HexColorPicker : NSColorPicker <NSColorPickingCustom> {
	IBOutlet NSView *colorPickerView;
	
	IBOutlet NSTextField *colorDisplay;
	
	IBOutlet NSTextField *colorR;
	IBOutlet NSTextField *colorG;
	IBOutlet NSTextField *colorB;
	
	IBOutlet NSTextField *colorH;
	IBOutlet NSTextField *colorS;
	IBOutlet NSTextField *colorL;
	
	IBOutlet NSTextField *colorHex;

	IBOutlet NSButton *goUpgrade;
	
	IBOutlet NSMenu *cogMenu;
	IBOutlet NSPopUpButton *cogButton;
	
	IBOutlet NSPanel *colorPickerPrefs;
	IBOutlet NSButton *useUpperHex;
	IBOutlet NSButton *checkForUpdates;
	IBOutlet NSButton *enableShorthand;
	IBOutlet NSButton *useDeviceColors;
	
	IBOutlet NSPanel *aboutPanel;
	IBOutlet NSTextField *aboutVersionField;
	
	NSColor *currColor;
	
	NSURL *updateInfoURL;
	
	BOOL alertIsUp;
	
	BOOL holdTheFormat;
	
	BOOL hasAskedAboutUpdates;
	BOOL shouldCheckForUpdates;
	BOOL uppercasesHex;
	BOOL shouldEnableShorthand;
	BOOL shouldGenerateDevice;
	
	int32_t isCheckingForUpdatesRightNow; // really fat BOOL for atomicity (no BOOL CompareAndSwap)
}

- (IBAction)colorChanged:(id)sender;
- (IBAction)copyToClipboard:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)goUpgrade:(id)sender;

- (IBAction)showPrefs:(id)sender;
- (IBAction)savePrefs:(id)sender;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)closeAboutPanel:(id)sender;

- (NSView *)provideNewView:(BOOL)initialRequest;

- (void)setColor:(NSColor *)color;

- (BOOL)supportsMode:(NSInteger)mode;
- (NSInteger)currentMode;

@end
