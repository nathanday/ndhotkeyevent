#import "AddController.h"
#import "NDHotKeyEvent.h"
#import "NDHotKeyControl.h"

@implementation AddController

- (IBAction)acceptHotKey:(id)aSender
{
	[[NSApplication sharedApplication] stopModal];
}

- (IBAction)cancelHotKey:(id)aSender
{
	gotKey = NO;
	[[NSApplication sharedApplication] stopModal];
}

- (IBAction)hotKeyChanged:(id)aSender
{
	gotKey = YES;
}

- (void)setModifierKeysRequired:(BOOL)aFlag
{
	modifierKeysRequired = aFlag;
}

- (BOOL)getKeyCombo
{
	int					theResponse;
	NSPanel				* thePanel;
	NSModalSession		theSession;

	gotKey = NO;
	thePanel = (NSPanel*)[self window];
	NSAssert( thePanel, @"No Panel" );

	[hotKeyControl setStringValue:@""];
	[hotKeyControl setRequiresModifierKeys:modifierKeysRequired];
	[thePanel orderFront:self];

	[hotKeyControl setReadyForHotKeyEvent:YES];
	[hotKeyControl setStayReadyForEvent:YES];
	theSession = [[NSApplication sharedApplication] beginModalSessionForWindow:thePanel];
	do
	{
		theResponse = [[NSApplication sharedApplication] runModalSession:theSession];
	}
	while( theResponse == NSRunContinuesResponse);

	[hotKeyControl setReadyForHotKeyEvent:NO];

	[[NSApplication sharedApplication] endModalSession:theSession];
	[thePanel orderOut:self];

	keyCode = [hotKeyControl keyCode];
	character = [hotKeyControl character];
	modifierFlags = [hotKeyControl modifierFlags];

	return gotKey;
}

- (unsigned short)keyCode
{
	return keyCode;
}

- (unichar)character
{
	return character;
}

- (unsigned long)modifierFlags
{
	return modifierFlags;
}

- (NDHotKeyEvent*)getHotKeyFromUser
{
	NDHotKeyEvent		* theHotKey = nil;
	if( [self getKeyCombo] )
	{
		theHotKey = [NDHotKeyEvent getHotKeyForKeyCode:[self keyCode] character:[self character] modifierFlags:[self modifierFlags]];
		NSLog(@"GOT KEYS { %u, %c, %u  }", [self keyCode], [self character], [self modifierFlags] );
	}

	return theHotKey;
}

- (NDHotKeyEvent*)findHotKeyFromUser
{
	NDHotKeyEvent		* theHotKey = nil;
	if( [self getKeyCombo] )
	{
		theHotKey = [NDHotKeyEvent findHotKeyForKeyCode:[self keyCode] modifierFlags:[self modifierFlags]];
		NSLog(@"GOT KEYS { %u, %u, }", [self keyCode], [self modifierFlags] );
	}

	return theHotKey;
}

@end
