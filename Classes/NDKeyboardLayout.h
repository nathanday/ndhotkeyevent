/*
	NDKeyboardLayout.h

	Created by Nathan Day on 01.18.10 under a MIT-style license. 
	Copyright (c) 2010 Nathan Day

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
 */

/*!
	@header NDKeyboardLayout.h
	@abstract Header file for 
	@discussion <#discussion#>
	@author 
 */

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>
#import <Carbon/Carbon.h>

struct ReverseMappingEntry;

/*!
	@function NDCocoaModifierFlagsForCarbonModifierFlags
	@abstract ￼<#abstract#>
	@discussion ￼<#discussion#>
	@param ￼ ￼<#name#> ￼<#discussion#>
	@result ￼￼<#discussion#>
 */
NSUInteger NDCocoaModifierFlagsForCarbonModifierFlags( NSUInteger modifierFlags );
/*!
	@function NDCarbonModifierFlagsForCocoaModifierFlags
	@abstract ￼<#abstract#>
	@discussion ￼<#discussion#>
	@param ￼ ￼<#name#> ￼<#discussion#>
	@result ￼￼<#discussion#>
 */
NSUInteger NDCarbonModifierFlagsForCocoaModifierFlags( NSUInteger modifierFlags );

/*!
	@class NDKeyboardLayout
	@abstract Class for translating between key codes and key characters.
	@discussion The key code for each key character can change between hardware and with localisation, <tt>NDKeyboardLayout</tt> handles translation between key codes and key characters as well as for generating strings for display purposes.
	@helps Used by <tt>NDHotKeyEvent</tt>.
 */
@interface NDKeyboardLayout : NSObject
{
@private
	CFDataRef					keyboardLayoutData;
	struct ReverseMappingEntry	* mappings;
	NSUInteger					numberOfMappings;
}

/*!
	@method keyboardLayout
	@abstract Get a keyboard layout for the current keyboard
	@discussion <#discussion#>
	@result <#result#>
 */
+ (id)keyboardLayout;
/*!
	@method init
	 @abstract initialise a keyboard layout for the current keyboard
	@discussion <#discussion#>
	@result <#result#>
 */
- (id)init;
/*!
	@method initWithInputSource:
	@abstract initialise a keyboard layout.
	@discussion <#discussion#>
	@param sounce <#description#>
	@result <#result#>
 */
- (id)initWithInputSource:(TISInputSourceRef)sounce;

/*!
	@method stringForKeyCode:modifierFlags:
	@abstract Get a string for display purposes. 
	@discussion <#discussion#>
	@param keyCode <#description#>
	@param modifierFlags <#description#>
	@result <#result#>
 */
- (NSString*)stringForKeyCode:(UInt16)keyCode modifierFlags:(UInt32)modifierFlags;
/*!
	@method characterForKeyCode:
	@abstract Get the key character for a given key code.
	@discussion <#discussion#>
	@param keyCode <#description#>
	@result <#result#>
 */
- (unichar)characterForKeyCode:(UInt16)keyCode;
/*!
	@method keyCodeForCharacter:keyPad:
	@abstract Get the key code for a given key character.
	@discussion <#discussion#>
	@param character <#description#>
	@param keyPad <#description#>
	@result <#result#>
 */
- (UInt16)keyCodeForCharacter:(unichar)character keyPad:(BOOL)keyPad;
/*!
	@method keyCodeForCharacter:
	@abstract Get the key code for a given key character.
	@discussion <#discussion#>
	@param character <#description#>
	@result <#result#>
 */
- (UInt16)keyCodeForCharacter:(unichar)character;

@end
