#import "AddController.h"
#import "NDHotKeyEvent.h"
#import "NDKeyboardLayout.h"

@implementation AddController

- (IBAction)acceptHotKey:(id)aSender { [[NSApplication sharedApplication] stopModal]; }

- (IBAction)cancelHotKey:(id)aSender
{
	gotKey = NO;
	[[NSApplication sharedApplication] stopModal];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSString		* theString = hotKeyControl.stringValue;
	if( theString.length > 0 )
	{
		keyCharacter = [theString characterAtIndex:theString.length-1];
		if( islower(keyCharacter) )
			keyCharacter -= 'a' - 'A';
		[hotKeyControl setStringValue:[NSString stringWithFormat:@"%c", keyCharacter]];
		gotKey = YES;
	}
}

- (IBAction)modifierChanged:(NSButtonCell *)aSender
{
	modifierFlags = 0;
	if( shiftCheckBoxButton.state == NSOnState )
		modifierFlags |= NSShiftKeyMask;
	if( optionCheckBoxButton.state == NSOnState )
		modifierFlags |= NSAlternateKeyMask;
	if( controlCheckBoxButton.state == NSOnState )
		modifierFlags |= NSControlKeyMask;
	if( commandCheckBoxButton.state == NSOnState )
		modifierFlags |= NSCommandKeyMask;
	if( numberPadCheckBoxButton.state == NSOnState )
		modifierFlags |= NSNumericPadKeyMask;
}

- (void)setModifierKeysRequired:(BOOL)aFlag { modifierKeysRequired = aFlag; }

- (BOOL)getKeyCombo
{
	NSInteger			theResponse;
	NSPanel				* thePanel = nil;
	NSModalSession		theSession;

	gotKey = NO;
	modifierFlags = 0;
	shiftCheckBoxButton.state = NSOffState;
	optionCheckBoxButton.state = NSOffState;
	controlCheckBoxButton.state = NSOffState;
	commandCheckBoxButton.state = NSOffState;
	numberPadCheckBoxButton.state = NSOffState;

	thePanel = (NSPanel*)self.window;
	NSAssert( thePanel, @"No Panel" );

	[hotKeyControl setStringValue:@""];
	[thePanel orderFront:self];

	theSession = [[NSApplication sharedApplication] beginModalSessionForWindow:thePanel];
	do
		theResponse = [[NSApplication sharedApplication] runModalSession:theSession];
	while( theResponse == NSRunContinuesResponse);

	[[NSApplication sharedApplication] endModalSession:theSession];
	[thePanel orderOut:self];

	return gotKey;
}

- (unichar)keyCharacter { return keyCharacter; }
- (unsigned long)modifierFlags { return modifierFlags; }

- (NDHotKeyEvent*)getHotKeyFromUser
{
	NDHotKeyEvent		* theHotKey = nil;

	if( [self getKeyCombo] )
		theHotKey = [NDHotKeyEvent getHotKeyForKeyCharacter:[self keyCharacter] modifierFlags:[self modifierFlags]];

	return theHotKey;
}

- (NDHotKeyEvent*)findHotKeyFromUser
{
	NDHotKeyEvent		* theHotKey = nil;

	if( [self getKeyCombo] )
		theHotKey = [NDHotKeyEvent findHotKeyForKeyCharacter:[self keyCharacter] modifierFlags:[self modifierFlags]];

	return theHotKey;
}

@end
