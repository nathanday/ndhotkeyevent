#import "WindowController.h"
#import "NDHotKeyEvent.h"
#import "AddController.h"

@interface HotKeyReponder : NSObject <NDHotKeyEventTarget>
{
	WindowController		* controller;
	NDHotKeyEvent			* hotKey;
	unsigned long int		count;
}

+ (id)hotKeyReponderWithController:(WindowController *)aController hotKey:(NDHotKeyEvent *)aHotKey;
- (id)initWithController:(WindowController *)aController hotKey:(NDHotKeyEvent *)aHotKey;
- (NDHotKeyEvent *)hotKeyEvent;
- (void)enable;
- (void)disable;
- (void)hotKeyPressed:(NDHotKeyEvent *)aHotKey;
- (void)hotKeyReleased:(NDHotKeyEvent *)aHotKey;
@end

@implementation WindowController
@synthesize		useBlocks;

- (IBAction)clear:(id)aSender
{
	[textView setString:@""];
}

- (IBAction)start:(id)aSender
{
	start = YES;

	for( HotKeyReponder * theHotKeyEvent in allHotKeyReponder )
		[theHotKeyEvent enable];
}

- (IBAction)stop:(id)aSender
{
	start = NO;

	for( HotKeyReponder * theHotKeyEvent in allHotKeyReponder )
		[theHotKeyEvent disable];
}

- (IBAction)allHotKey:(id)aSender
{
	NSLog( @"All Hot Key\n%@", [NDHotKeyEvent description] );
	[self appendText:[NDHotKeyEvent description]];
}

- (IBAction)addHotKey:(id)aSender
{
	NDHotKeyEvent		* theHotKey;

	theHotKey = [addController getHotKeyFromUser];

	if( theHotKey )
	{
		HotKeyReponder		* theResponder;
		[self appendText:[NSString stringWithFormat:@"Added Key: %@", [theHotKey stringValue]]];

		if( !allHotKeyReponder )
		{
			[NDHotKeyEvent setSignature:'NDhk'];
			allHotKeyReponder = [[NSMutableArray alloc] initWithCapacity:1];
		}

		theResponder = [HotKeyReponder hotKeyReponderWithController:self hotKey:theHotKey];
		[allHotKeyReponder addObject:theResponder];
	}
	else
		NSLog(@"No hot key returned");
}

- (IBAction)newHotKey:(id)aSender
{
	NDHotKeyEvent		* theHotKey;
	
	theHotKey = [aSender hotKeyEvent];
	
	if( theHotKey )
	{
		HotKeyReponder		* theResponder;
		[self appendText:[NSString stringWithFormat:@"Added Key: %@", [theHotKey stringValue]]];
		
		if( !allHotKeyReponder )
		{
			[NDHotKeyEvent setSignature:'NDhk'];
			allHotKeyReponder = [[NSMutableArray alloc] initWithCapacity:1];
		}
		
		theResponder = [HotKeyReponder hotKeyReponderWithController:self hotKey:theHotKey];
		[allHotKeyReponder addObject:theResponder];
	}
	else
		NSLog(@"No hot key returned");
}

- (IBAction)removeHotKey:(id)aSender
{
	NDHotKeyEvent		* theHotKey;

	[NDHotKeyEvent setAllEnabled:NO];
	theHotKey = [addController findHotKeyFromUser];
	[NDHotKeyEvent setAllEnabled:YES];

	if( theHotKey )
	{
		[self appendText:[NSString stringWithFormat:@"Removed Key: %@", [theHotKey stringValue]]];

		if( allHotKeyReponder )
			[allHotKeyReponder removeObject:[theHotKey target]];
	}
	else
		NSLog(@"No hot key returned");
}

- (IBAction)enableHotKey:(id)aSender
{
	NDHotKeyEvent		* theHotKey;

	[NDHotKeyEvent setAllEnabled:NO];
	theHotKey = [addController findHotKeyFromUser];
	[NDHotKeyEvent setAllEnabled:YES];

	if( theHotKey )
	{
		[self appendText:[NSString stringWithFormat:@"Enable Key: %@", [theHotKey stringValue]]];
		[theHotKey setEnabled:YES];
	}
	else
		NSLog(@"No hot key returned");
}

- (IBAction)disableHotKey:(id)aSender
{
	NDHotKeyEvent		* theHotKey;

	[NDHotKeyEvent setAllEnabled:NO];
	theHotKey = [addController findHotKeyFromUser];
	[NDHotKeyEvent setAllEnabled:YES];

	if( theHotKey )
	{
		[self appendText:[NSString stringWithFormat:@"Disable Key: %@", [theHotKey stringValue]]];
		[theHotKey setEnabled:NO];
	}
	else
		NSLog(@"No hot key returned");
}

- (IBAction)modifierKeysRequired:(id)aSender
{
	[addController setModifierKeysRequired:[aSender state] == NSOnState];
}

- (IBAction)useBlocksChanged:(id)aSender
{
	self.useBlocks = [aSender state] == NSOnState;
}

- (IBAction)readyForHotKey:(id)aSender
{
}

- (void)appendText:(NSString *)aMessage
{
	NSRange		theRange = NSMakeRange( [[textView string] length], [aMessage length] + 1);
	[textView setString:[[textView string] stringByAppendingFormat:@"%@\n",aMessage]];
	[textView scrollRangeToVisible:theRange];
}

@end

@implementation HotKeyReponder

static unsigned long int		hotKeyReponderCount = 0;
static char						* eventNames[] = { "No Event", "Pressed Event", "Released Event" };

+ (id)hotKeyReponderWithController:(WindowController *)aController hotKey:(NDHotKeyEvent *)aHotKey
{
	return [[self alloc] initWithController:aController hotKey:aHotKey];
}

- (id)initWithController:(WindowController *)aController hotKey:(NDHotKeyEvent *)aHotKey
{
	if( self = [self init] )
	{
		controller = aController;
		hotKey = aHotKey;
		count = hotKeyReponderCount++;

//		[hotKey setTarget:self selector:@selector(hotKeyFired:)];

		if( ![aController useBlocks] )
		{
			if( [hotKey setTarget:self] == NO )
			{
				self = nil;
			}
		}
		else
		{
			if( [hotKey setReleasedBlock:^(NDHotKeyEvent * anEvent)
			{
				[controller appendText:[NSString stringWithFormat:@"Block: [#%lu] Pressed hot key: %@", count, [aHotKey stringValue]]];
			}
							pressedBlock:^(NDHotKeyEvent * anEvent)
			{
				[controller appendText:[NSString stringWithFormat:@"Block: [#%lu] Released hot key: %@", count, [aHotKey stringValue]]];
			}] == NO )
			{
				self = nil;
			}
		}
	}

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"HotKeyReponder #%lu", count];
}

- (NDHotKeyEvent *)hotKeyEvent
{
	return hotKey;
}

- (void)enable
{
	if( [hotKey setEnabled:YES] == NO )
		NSLog(@"Enable Failed");
}

- (void)disable
{
	if( [hotKey setEnabled:NO] == NO )
		NSLog(@"Disable Failed");
}

- (void)hotKeyPressed:(NDHotKeyEvent *)aHotKey
{
	NSAssert1( [aHotKey currentEventType] == NDHotKeyPressedEvent, @"Got event %s", eventNames[[aHotKey currentEventType]] );
	[controller appendText:[NSString stringWithFormat:@"[#%lu] Pressed hot key: %@", count, [aHotKey stringValue]]];
}
- (void)hotKeyReleased:(NDHotKeyEvent *)aHotKey
{
	NSAssert1( [aHotKey currentEventType] == NDHotKeyReleasedEvent, @"Got event %s", eventNames[[aHotKey currentEventType]] );
	[controller appendText:[NSString stringWithFormat:@"[#%lu] Released hot key: %@", count, [aHotKey stringValue]]];
}

- (BOOL)targetWillChangeToObject:(id)aTarget forHotKeyEvent:(NDHotKeyEvent *)aEvent
{
	NSParameterAssert( aTarget != self );
	NSParameterAssert( aEvent == hotKey );

	hotKey = nil;
	
	return YES;		// return yes to say it is ok
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSLog( @"keyDown:" );
}

@end
