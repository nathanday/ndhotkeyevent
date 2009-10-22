/* AddController */

#import <Cocoa/Cocoa.h>

@class		NDHotKeyEvent,
				NDHotKeyControl;

@interface AddController : NSWindowController
{
	IBOutlet NDHotKeyControl	* hotKeyControl;

@private
	unsigned short		keyCode;
	unichar				character;
	unsigned long		modifierFlags;
	BOOL					gotKey;
	BOOL					modifierKeysRequired;
}

- (IBAction)acceptHotKey:(id)sender;
- (IBAction)cancelHotKey:(id)sender;
- (IBAction)hotKeyChanged:(id)sender;
- (void)setModifierKeysRequired:(BOOL)flag;

- (unsigned short)keyCode;
- (unichar)character;
- (unsigned long)modifierFlags;

- (BOOL)getKeyCombo;
- (NDHotKeyEvent*)getHotKeyFromUser;
- (NDHotKeyEvent*)findHotKeyFromUser;

@end
