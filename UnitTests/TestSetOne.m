/*
	TestSetOne.m
	NDHotKeyEvent

	Created by Nathan Day on 22/01/10.
	Copyright 2010 Nathan Day. All rights reserved.
*/

#import "TestSetOne.h"
#import "NDHotKeyEvent.h"

@implementation TestSetOne

- (void)testArchiving
{
	NDHotKeyEvent		* theHotKey = [NDHotKeyEvent hotKeyWithKeyCharacter:'z' modifierFlags:NSShiftKeyMask];
	STAssertNotNil( theHotKey, @"Failed to create new Hot Key" );
	NSData				* theData = [NSArchiver archivedDataWithRootObject:theHotKey];
	STAssertNotNil( theData, @"Failed to create serized data" );
	[theHotKey release];
	NDHotKeyEvent		* theNewHotKey = [NSUnarchiver unarchiveObjectWithData:theData];
	STAssertTrue( [theNewHotKey isKindOfClass:[NDHotKeyEvent class]], @"Unarchived data is of the wrong kind %@", [NDHotKeyEvent class] );
	STAssertTrue( theNewHotKey.character == 'Z', @"The unarchived hit key has the character %c", theNewHotKey.character );
	STAssertTrue( theNewHotKey.modifierFlags == NSShiftKeyMask, @"The unarchived hit key has the character %d", theNewHotKey.modifierFlags );
}

@end
