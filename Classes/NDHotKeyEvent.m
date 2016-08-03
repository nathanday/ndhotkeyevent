/*
	NDHotKeyEvent.m

	Created by Nathan Day on 21.06.06 under a MIT-style license. 
	Copyright (c) 2008 Nathan Day

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

#import "NDHotKeyEvent.h"
#import "NDKeyboardLayout.h"

static const NSUInteger		kNDHotKeyEventVersion = 2;

@interface NDHotKeyEvent ()
+ (NSMapTable *)allHotKeyEvents;
- (void)addHotKey;
- (void)removeHotKey;
- (BOOL)setCollectiveEnabled:(BOOL)aFlag;
- (BOOL)collectiveEnable;
@end

static NSString		* kArchivingKeyCodeKey = @"KeyCodeKey",
					* kArchivingKeyCharacterKey = @"KeyCharacterKey",
					* kArchivingModifierFlagsKey = @"ModifierFlagsKey",
					* kArchivingSelectorReleasedCodeKey = @"SelectorReleasedCodeKey",
					* kArchivingSelectorPressedCodeKey = @"SelectorPressedCodeKey";
const OSType		NDHotKeyDefaultSignature = 'NDHK';

static OSStatus	switchHotKey( NDHotKeyEvent * self, BOOL aFlag );

@interface NDHotKeyEvent () {
@private
	EventHotKeyRef		reference;
	//	UInt16				keyCode;
	unichar				keyCharacter;
	BOOL				keyPad;
	NSUInteger			modifierFlags;
	int					currentEventType;
	id					target;
	SEL					selectorReleased,
	selectorPressed;
#ifdef NS_BLOCKS_AVAILABLE
	void	(^releasedBlock)(NDHotKeyEvent * e);
	void	(^pressedBlock)(NDHotKeyEvent * e);
#endif
	struct
	{
		unsigned			individual		: 1;
		unsigned			collective		: 1;
	}						isEnabled;
}
@end
/*
 * class implementation NDHotKeyEvent
 */
@implementation NDHotKeyEvent

static EventHandlerRef	hotKeysEventHandler = NULL;
static OSType			signature = 0;

static pascal OSErr eventHandlerCallback( EventHandlerCallRef anInHandlerCallRef, EventRef anInEvent, void * self );

static UInt32 _idForCharacterAndModifier( unichar aCharacter, NSUInteger aModFlags ) { return (UInt32)(aCharacter | (aModFlags<<16)); }

static void _getCharacterAndModifierForId( UInt32 anId, unichar *aCharacter, NSUInteger *aModFlags )
{
	*aModFlags = anId>>16;
	*aCharacter = anId&0xFFFF;
}

+ (BOOL)install
{
	if( hotKeysEventHandler == NULL )
	{
		id					theHotKeyEvents = [self allHotKeyEvents];
		EventTypeSpec		theTypeSpec[] =
		{
			{ kEventClassKeyboard, kEventHotKeyPressed },
			{ kEventClassKeyboard, kEventHotKeyReleased }
		};
		
		@synchronized([self class]) {
			if( theHotKeyEvents != nil && hotKeysEventHandler == NULL )
			{
				if( InstallEventHandler( GetEventDispatcherTarget(), NewEventHandlerUPP((EventHandlerProcPtr)eventHandlerCallback), 2, theTypeSpec, (__bridge void *)(theHotKeyEvents), &hotKeysEventHandler ) != noErr )
					NSLog(@"Could not install Event handler");
			}
		}
	}
	
	return hotKeysEventHandler != NULL;
}

+ (void)uninstall
{
	if( hotKeysEventHandler != NULL )
		RemoveEventHandler( hotKeysEventHandler );
}

+ (void)initialize
{
	[NDHotKeyEvent setVersion:kNDHotKeyEventVersion];			// the character attribute has been removed

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentKeyboardLayoutChanged:) name:NDKeyboardLayoutSelectedKeyboardInputSourceChangedNotification object:nil];
}

+ (void)setSignature:(OSType)aSignature
{
	NSAssert( signature == 0 || aSignature == signature, @"The signature used by NDHotKeyEvent can only be set once safely" );
	signature = aSignature;
}

+ (OSType)signature
{
	signature = signature ? signature : NDHotKeyDefaultSignature;
	return signature;
}

+ (BOOL)setAllEnabled:(BOOL)aFlag
{
	BOOL			theAllSucceeded = YES;
	NSMapTable		* theAllHotKeyEvents = [NDHotKeyEvent allHotKeyEvents];

	/*
	 * need to install before to make sure the method 'setCollectiveEnabled:'
	 * doesn't try install since install tries to aquire the lock 'hotKeysLock'
	 */
	if( theAllHotKeyEvents && [NDHotKeyEvent install] )
	{
		@synchronized([self class]) {
			for( NDHotKeyEvent * theHotEvent in [theAllHotKeyEvents objectEnumerator] )
			{
				if( ![theHotEvent setCollectiveEnabled:aFlag] )
					theAllSucceeded = NO;
			}
		}
	}

	return theAllSucceeded;
}

+ (BOOL)isEnabledKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self findHotKeyForKeyCode:[[NDKeyboardLayout keyboardLayout] keyCodeForCharacter:aKeyCharacter numericPad:(aModifierFlags&NSNumericPadKeyMask) != 0] modifierFlags:aModifierFlags] isEnabled];
}

+ (BOOL)isEnabledKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self findHotKeyForKeyCode:aKeyCode modifierFlags:aModifierFlags] isEnabled];
}

+ (instancetype)getHotKeyForKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [self getHotKeyForKeyCharacter:[[NDKeyboardLayout keyboardLayout] characterForKeyCode:aKeyCode] modifierFlags:aModifierFlags];
}

#pragma mark - finding hot key event objects
+ (instancetype)getHotKeyForKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	NDHotKeyEvent		* theHotKey = nil;

	theHotKey = [self findHotKeyForKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags];
	return theHotKey ? theHotKey : [self hotKeyWithKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags];
}

+ (instancetype)findHotKeyForKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [self findHotKeyForKeyCharacter:[[NDKeyboardLayout keyboardLayout] characterForKeyCode:aKeyCode] modifierFlags:aModifierFlags];
}

+ (instancetype)findHotKeyForKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [self findHotKeyForId:_idForCharacterAndModifier(aKeyCharacter, aModifierFlags)];
}

+ (instancetype)findHotKeyForId:(UInt32)anID
{
	NDHotKeyEvent				* theResult = nil;
	NSMapTable		* theAllHotKeyEvents = [NDHotKeyEvent allHotKeyEvents];

	if( theAllHotKeyEvents )
	{
		@synchronized([self class]) {
			theResult = [theAllHotKeyEvents objectForKey:[NSNumber numberWithUnsignedInt:anID]];
		}
	}
	
	return theResult;
}

+ (instancetype)hotKeyWithEvent:(NSEvent *)anEvent
{
	return [[self alloc] initWithEvent:anEvent];
}

+ (instancetype)hotKeyWithEvent:(NSEvent *)anEvent target:(id)aTarget selector:(SEL)aSelector
{
	return [[self alloc] initWithEvent:anEvent target:aTarget selector:aSelector];
}

+ (instancetype)hotKeyWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self alloc] initWithKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags target:nil selector:(SEL)0];
}

+ (instancetype)hotKeyWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil selector:(SEL)0];
}

+ (instancetype)hotKeyWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [[self alloc] initWithKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags target:aTarget selector:aSelector];
}

+ (instancetype)hotKeyWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget selector:aSelector];
}

+ (instancetype)hotKeyWithWithPropertyList:(id)aPropertyList
{
	return [[self alloc] initWithPropertyList:aPropertyList];
}

+ (NSString *)description
{
	NSMapTable		* theAllHotKeyEvents = [NDHotKeyEvent allHotKeyEvents];
	NSString		* theDescription = nil;
	if( theAllHotKeyEvents )
	{
		@synchronized([self class]) {
			theDescription = [theAllHotKeyEvents description];
		}
	}
	return theDescription;
}

#pragma mark - creation and destruction
- (instancetype)init
{
	NSAssert( NO, @"You can not initialize a Hot Key with the init method" );
	return nil;
}

- (instancetype)initWithEvent:(NSEvent *)anEvent
{
	return [self initWithEvent:anEvent target:nil selector:NULL];
}

- (instancetype)initWithEvent:(NSEvent *)anEvent target:(id)aTarget selector:(SEL)aSelector
{
	unsigned long		theModifierFlags = [anEvent modifierFlags] & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);

	return [self initWithKeyCode:[anEvent keyCode]
				   modifierFlags:theModifierFlags
						  target:aTarget
						selector:aSelector];
}

- (instancetype)initWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:[[NDKeyboardLayout keyboardLayout] keyCodeForCharacter:aKeyCharacter numericPad:(aModifierFlags&NSNumericPadKeyMask) != 0] modifierFlags:aModifierFlags target:nil selector:NULL];
}

- (instancetype)initWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil selector:NULL];
}

- (instancetype)initWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [self initWithKeyCharacter:[[NDKeyboardLayout keyboardLayout] characterForKeyCode:aKeyCode] modifierFlags:aModifierFlags target:aTarget selector:aSelector];
}

- (instancetype)initWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	if( (self = [super init]) != nil )
	{
		keyCharacter = aKeyCharacter;
		modifierFlags = aModifierFlags;
		target = aTarget;
		selectorReleased = aSelector;
		currentEventType = NDHotKeyNoEvent;
		isEnabled.collective = YES;
		[self addHotKey];
	}
	else
		self = nil;

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	if( (self = [super init]) != nil)
	{
		if( [aDecoder allowsKeyedCoding] )
		{
			NSNumber	* theValue = [aDecoder decodeObjectForKey:kArchivingKeyCharacterKey];
			if( theValue == nil )
			{
				theValue = [aDecoder decodeObjectForKey:kArchivingKeyCodeKey];
				keyCharacter = [[NDKeyboardLayout keyboardLayout] characterForKeyCode:[theValue unsignedShortValue]];
			}
			else
				keyCharacter = [theValue unsignedShortValue];
			modifierFlags = [[aDecoder decodeObjectForKey:kArchivingModifierFlagsKey] unsignedIntegerValue];
			
			selectorReleased = NSSelectorFromString( [aDecoder decodeObjectForKey:kArchivingSelectorReleasedCodeKey] );
			selectorPressed = NSSelectorFromString( [aDecoder decodeObjectForKey:kArchivingSelectorPressedCodeKey] );
		}
		else
		{
			if( [aDecoder versionForClassName:@"NDHotKeyNoEvent"] == 1 )
			{
				unsigned short		theKeyCode;
				[aDecoder decodeValueOfObjCType:@encode(UInt16) at:&theKeyCode];
				keyCharacter = [[NDKeyboardLayout keyboardLayout] characterForKeyCode:theKeyCode];
			}
			else
				[aDecoder decodeValueOfObjCType:@encode(unichar) at:&keyCharacter];
			[aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&modifierFlags];

			selectorReleased = NSSelectorFromString( [aDecoder decodeObject] );
			selectorPressed = NSSelectorFromString( [aDecoder decodeObject] );
		}

		[self addHotKey];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)anEncoder
{
	if( [anEncoder allowsKeyedCoding] )
	{
		[anEncoder encodeObject:[NSNumber numberWithUnsignedShort:keyCharacter] forKey:kArchivingKeyCharacterKey];
		[anEncoder encodeObject:[NSNumber numberWithUnsignedInteger:modifierFlags] forKey:kArchivingModifierFlagsKey];

		[anEncoder encodeObject:NSStringFromSelector( selectorReleased ) forKey:kArchivingSelectorReleasedCodeKey];
		[anEncoder encodeObject:NSStringFromSelector( selectorPressed ) forKey:kArchivingSelectorPressedCodeKey];
	}
	else
	{
		[anEncoder encodeValueOfObjCType:@encode(unichar) at:&keyCharacter];
		[anEncoder encodeValueOfObjCType:@encode(NSUInteger) at:&modifierFlags];

		[anEncoder encodeObject:NSStringFromSelector( selectorReleased )];
		[anEncoder encodeObject:NSStringFromSelector( selectorPressed )];
	}
}

- (instancetype)initWithPropertyList:(id)aPropertyList
{
	if( aPropertyList )
	{
		NSNumber	* theKeyCode,
					* theModiferFlag;

		theKeyCode = [aPropertyList objectForKey:kArchivingKeyCodeKey];
		theModiferFlag = [aPropertyList objectForKey:kArchivingModifierFlagsKey];

		if( (self = [self initWithKeyCode:[theKeyCode unsignedShortValue] modifierFlags:[theModiferFlag unsignedIntValue]]) != nil )
		{
			selectorPressed = NSSelectorFromString([aPropertyList objectForKey:kArchivingSelectorPressedCodeKey]);
			selectorReleased = NSSelectorFromString([aPropertyList objectForKey:kArchivingSelectorReleasedCodeKey]);
		}
	}
	else
		self = nil;

	return self;
}

- (id)propertyList
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:[self keyCode]], kArchivingKeyCodeKey,
		[NSNumber numberWithUnsignedInteger:[self modifierFlags]], kArchivingModifierFlagsKey,
		NSStringFromSelector( selectorPressed ), kArchivingSelectorPressedCodeKey,
		NSStringFromSelector( selectorReleased ), kArchivingSelectorReleasedCodeKey,
		nil];
}

- (void)dealloc
{
	if( reference )
	{
		switchHotKey( self, NO );
		if( UnregisterEventHotKey( reference ) != noErr )	// in lock from release
			NSLog( @"Failed to unregister hot key %@", self );
	}

	[[NDHotKeyEvent allHotKeyEvents] removeObjectForKey:@(self.hotKeyId)];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NDKeyboardLayoutSelectedKeyboardInputSourceChangedNotification object:nil];

}

- (BOOL)setEnabled:(BOOL)aFlag
{
	BOOL		theResult = YES;

	if( [NDHotKeyEvent install] )
	{
		/*
		 * if individual and collective YES then currently ON, otherwise currently off
		 */
		@synchronized([self class]) {
			if( aFlag == YES && isEnabled.collective == YES  && isEnabled.individual == NO )
				theResult = (switchHotKey( self, YES ) == noErr);
			else if( aFlag == NO && isEnabled.collective == YES  && isEnabled.individual == YES )
				theResult = (switchHotKey( self, NO ) == noErr);
		}

		if( theResult )
			isEnabled.individual = aFlag;
		else
			NSLog(@"%s failed ", aFlag ? "enable" : "disable" );
	}
	else
		theResult = NO;

	return theResult;
}

- (void)setIsEnabled:(BOOL)aFlag { [self setEnabled:aFlag]; }

- (BOOL)isEnabled { return isEnabled.individual && isEnabled.collective; }
- (id)target { return target; }
- (SEL)selector { return selectorReleased; }
- (SEL)selectorReleased { return selectorReleased; }
- (SEL)selectorPressed { return selectorPressed; }
- (int)currentEventType { return currentEventType; }				// (NDHotKeyNoEvent | NDHotKeyPressedEvent | NDHotKeyReleasedEvent)
- (BOOL)setTarget:(id)aTarget selector:(SEL)aSelector { return [self setTarget:aTarget selectorReleased:aSelector selectorPressed:(SEL)0]; }

#ifdef NS_BLOCKS_AVAILABLE
- (BOOL)setBlock:(void(^)(NDHotKeyEvent*))aBlock { return [self setReleasedBlock:aBlock pressedBlock:nil]; }
#endif

- (BOOL)setTarget:(id)aTarget selectorReleased:(SEL)aSelectorReleased selectorPressed:(SEL)aSelectorPressed
{
	BOOL	theResult = NO;
	[self setEnabled:NO];
	if( target != nil && target != aTarget )
	{
		if( ![target respondsToSelector:@selector(targetWillChangeToObject:forHotKeyEvent:)] || [target targetWillChangeToObject:aTarget forHotKeyEvent:self] )
		{
			target = aTarget;
			theResult = YES;
		}
	}
	else
	{
		target = aTarget;
		theResult = YES;
	}

	selectorReleased = aSelectorReleased;
	selectorPressed = aSelectorPressed;

#ifdef NS_BLOCKS_AVAILABLE
	releasedBlock = nil;
	pressedBlock = nil;
#endif

	return theResult;		// was change succesful
}

#ifdef NS_BLOCKS_AVAILABLE
- (BOOL)setReleasedBlock:(void(^)(NDHotKeyEvent*))aReleasedBlock pressedBlock:(void(^)(NDHotKeyEvent*))aPressedBlock
{
	BOOL	theResult = NO;
	[self setEnabled:NO];
	if( ![target respondsToSelector:@selector(targetWillChangeToObject:forHotKeyEvent:)] || [target targetWillChangeToObject:nil forHotKeyEvent:self] )
	{
		if( releasedBlock != aReleasedBlock )
			releasedBlock = [aReleasedBlock copy];

		if( pressedBlock != aPressedBlock )
			pressedBlock = [aPressedBlock copy];

		selectorReleased = (SEL)0;
		selectorPressed = (SEL)0;
		theResult = YES;
	}
	
	return theResult;		// was change succesful
}
#endif

- (void)performHotKeyReleased
{
	NSAssert( target != nil || releasedBlock != nil, @"Release hot key fired without target or release block" );

	currentEventType = NDHotKeyReleasedEvent;
	if( selectorReleased )
	{
		if([target respondsToSelector:selectorReleased])
			[target performSelector:selectorReleased withObject:self];
		else if( [target respondsToSelector:@selector(makeObjectsPerformSelector:withObject:)] )
			[target makeObjectsPerformSelector:selectorReleased withObject:self];
	}
#ifdef NS_BLOCKS_AVAILABLE
	else if( releasedBlock )
		releasedBlock(self);
#endif
	currentEventType = NDHotKeyNoEvent;
}

- (void)performHotKeyPressed
{
	NSAssert( target != nil || pressedBlock != nil, @"Release hot key fired without target or pressed block" );

	currentEventType = NDHotKeyPressedEvent;
	if( selectorPressed )
	{
		if([target respondsToSelector:selectorPressed])
			[target performSelector:selectorPressed withObject:self];
		else if( [target respondsToSelector:@selector(makeObjectsPerformSelector:withObject:)] )
			[target makeObjectsPerformSelector:selectorPressed withObject:self];
	}
#ifdef NS_BLOCKS_AVAILABLE
	else if( pressedBlock )
		pressedBlock(self);
#endif

	currentEventType = NDHotKeyNoEvent;
}

- (unichar)keyCharacter { return keyCharacter; }
- (BOOL)keyPad { return keyPad; }
- (UInt16)keyCode { return [[NDKeyboardLayout keyboardLayout] keyCodeForCharacter:self.keyCharacter numericPad:self.keyPad]; }
- (NSUInteger)modifierFlags { return modifierFlags; }
- (UInt32)hotKeyId { return _idForCharacterAndModifier( self.keyCharacter, self.modifierFlags ); }
- (NSString *)stringValue { return [[NDKeyboardLayout keyboardLayout] stringForKeyCode:[self keyCode] modifierFlags:[self modifierFlags]]; }

- (BOOL)isEqual:(id)anObject
{
	return [super isEqual:anObject] || ([anObject isKindOfClass:[self class]] == YES && [self keyCode] == [(NDHotKeyEvent*)anObject keyCode] && [self modifierFlags] == [anObject modifierFlags]);
}

- (NSUInteger)hash { return (NSUInteger)self.keyCharacter | (self.modifierFlags<<16); }

- (NSString *)description
{
	return [NSString stringWithFormat:@"{\n\tKey Combination: %@,\n\tEnabled: %s\n\tKey Press Selector: %@\n\tKey Release Selector: %@\n}\n",
					[self stringValue],
					[self isEnabled] ? "yes" : "no",
					NSStringFromSelector([self selectorPressed]),
					NSStringFromSelector([self selectorReleased])];
}

pascal OSErr eventHandlerCallback( EventHandlerCallRef anInHandlerCallRef, EventRef anInEvent, void * anInUserData )
{
//	NSHashTable			* allHotKeyEvents = (NSHashTable *)anInUserData;
	EventHotKeyID		theHotKeyID;
	OSStatus			theError;

	NSCAssert( GetEventClass( anInEvent ) == kEventClassKeyboard, @"Got event that is not a hot key event" );

	theError = GetEventParameter( anInEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(EventHotKeyID), NULL, &theHotKeyID );

	if( theError == noErr )
	{
		NDHotKeyEvent		* theHotKeyEvent;
		UInt32				theEventKind;
		
		NSCAssert( [NDHotKeyEvent signature] == theHotKeyID.signature, @"Got hot key event with wrong signature" );

		theHotKeyEvent = [NDHotKeyEvent findHotKeyForId:theHotKeyID.id];

		theEventKind = GetEventKind( anInEvent );
		if( kEventHotKeyPressed == theEventKind )
			[theHotKeyEvent performHotKeyPressed];
		else if( kEventHotKeyReleased == theEventKind )
			[theHotKeyEvent performHotKeyReleased];
	}

	return theError;
}

#pragma mark Private methods

+ (NSMapTable *)allHotKeyEvents
{
	static NSMapTable		* allHotKeyEvents = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		allHotKeyEvents = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableWeakMemory capacity:0];
	});
	return allHotKeyEvents;
}

+ (void)currentKeyboardLayoutChanged:(NSNotification *)aNotification
{
	@synchronized([self class]) {
		for( NDHotKeyEvent * theHotEvent in [[NDHotKeyEvent allHotKeyEvents] objectEnumerator] )
		{
			switchHotKey( theHotEvent, theHotEvent.isEnabled );
		}
	}
}

- (void)addHotKey
{
	@synchronized([self class]) {
		[[NDHotKeyEvent allHotKeyEvents] setObject:self forKey:[NSNumber numberWithUnsignedInt:[self hotKeyId]]];
	}
}

- (void)removeHotKey
{
	[self setEnabled:NO];

	@synchronized([self class]) {
		[[NDHotKeyEvent allHotKeyEvents] removeObjectForKey:[NSNumber numberWithUnsignedInt:[self hotKeyId]]];
	}
}

- (BOOL)setCollectiveEnabled:(BOOL)aFlag
{
	BOOL		theResult = YES;
	
	if( [NDHotKeyEvent install] )
	{
		/*
		 * if individual and collective YES then currently ON, otherwise currently off
		 */
		@synchronized([self class]) {
			if( aFlag == YES && isEnabled.collective == NO  && isEnabled.individual == YES )
				theResult = (switchHotKey( self, YES ) == noErr);
			else if( aFlag == NO && isEnabled.collective == YES  && isEnabled.individual == YES )
				theResult = (switchHotKey( self, NO ) == noErr);
		}

		if( theResult )
			isEnabled.collective = aFlag;
		else
			NSLog(@"%s failed", aFlag ? "enable" : "disable" );
	}
	else
		theResult = NO;

	return theResult;
}

- (BOOL)collectiveEnable { return isEnabled.collective; }

static OSStatus switchHotKey( NDHotKeyEvent * self, BOOL aFlag )
{
	OSStatus		theError = noErr;
	if( aFlag )
	{
		EventHotKeyID 		theHotKeyID;

		if( self->reference )
			theError = UnregisterEventHotKey( self->reference );
		if( theError == noErr )
		{
			theHotKeyID.signature = [NDHotKeyEvent signature];
			theHotKeyID.id = [self hotKeyId];

			NSCAssert( theHotKeyID.signature, @"HotKeyEvent signature has not been set yet" );
			NSCParameterAssert(sizeof(unsigned long) >= sizeof(id) );

			theError = RegisterEventHotKey( self.keyCode, NDCarbonModifierFlagsForCocoaModifierFlags(self->modifierFlags), theHotKeyID, GetEventDispatcherTarget(), 0, &self->reference );
		}
	}
	else
	{
		theError = UnregisterEventHotKey( self->reference );
		self->reference = 0;
	}

	return theError;
}

#pragma mark - Deprecated Methods

+ (NDHotKeyEvent *)getHotKeyForKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags
{
	return [self getHotKeyForKeyCode:aKeyCode modifierFlags:aModifierFlags];
}

/*
 * +hotKeyWithKeyCode:character:modifierFlags:
 */
+ (id)hotKeyWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags
{
	return [self hotKeyWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil selector:NULL];
}

/*
 * +hotKeyWithKeyCode:character:modifierFlags:target:selector:
 */
+ (id)hotKeyWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget selector:aSelector];
}

/*
 * -initWithKeyCode:character:modifierFlags:
 */
- (id)initWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil selector:NULL];
}

/*
 * -initWithKeyCode:character:modifierFlags:target:selector:
 */
- (id)initWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget selector:aSelector];
}

@end
