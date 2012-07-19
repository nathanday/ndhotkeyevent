/* AddController */

#import <Cocoa/Cocoa.h>

@class		NDHotKeyEvent,
				NDHotKeyControl;

@interface AddController : NSWindowController
{
	IBOutlet NSTextField	* hotKeyControl;
	IBOutlet NSButtonCell	* shiftCheckBoxButton;
	IBOutlet NSButtonCell	* optionCheckBoxButton;
	IBOutlet NSButtonCell	* controlCheckBoxButton;
	IBOutlet NSButtonCell	* commandCheckBoxButton;
	IBOutlet NSButton		* numberPadCheckBoxButton;

@private
	unichar				keyCharacter;
	unsigned long		modifierFlags;
	BOOL				gotKey;
	BOOL				modifierKeysRequired;
}

- (IBAction)acceptHotKey:(id)sender;
- (IBAction)cancelHotKey:(id)sender;
- (IBAction)modifierChanged:(NSButtonCell *)sender;

- (void)setModifierKeysRequired:(BOOL)flag;

- (unichar)keyCharacter;
- (unsigned long)modifierFlags;

- (BOOL)getKeyCombo;
- (NDHotKeyEvent*)getHotKeyFromUser;
- (NDHotKeyEvent*)findHotKeyFromUser;

@end
