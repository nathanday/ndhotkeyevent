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

static NSString		* kArchivingKeyCodeKey = @"KeyCodeKey",
					* kArchivingKeyCharacterKey = @"KeyCharacterKey",
					* kArchivingModifierFlagsKey = @"ModifierFlagsKey",
					* kArchivingSelectorReleasedCodeKey = @"SelectorReleasedCodeKey",
					* kArchivingSelectorPressedCodeKey = @"SelectorPressedCodeKey";
const OSType		NDHotKeyDefaultSignature = 'NDHK';

@interface NDHotKeyEvent () {
@private
	EventHotKeyRef		_reference;
//	UInt16				keyCode;
	unichar				_keyCharacter;
	BOOL				_keyPad;
	NSUInteger			_modifierFlags;
	NDHotKeyEventType	_currentEventType;
	__weak id <NDHotKeyEventTarget>	_target;
#ifdef NS_BLOCKS_AVAILABLE
	void	(^_releasedBlock)(NDHotKeyEvent * e);
	void	(^_pressedBlock)(NDHotKeyEvent * e);
#endif
	struct
	{
		unsigned			individual		: 1;
		unsigned			collective		: 1;
	}						_isEnabled;
}

@end
/*
 * class implementation NDHotKeyEvent
 */
@implementation NDHotKeyEvent

static EventHandlerRef	hotKeysEventHandler = NULL;
static OSType			signature = 0;

static pascal OSErr eventHandlerCallback( EventHandlerCallRef anInHandlerCallRef, EventRef anInEvent, void * self );

static UInt32 _idForCharacterAndModifier( unichar aCharacter, NSUInteger aModFlags ) { return (UInt32)(aCharacter | (aModFlags << 16)); }

static void _getCharacterAndModifierForId( UInt32 anId, unichar *aCharacter, NSUInteger *aModFlags )
{
	*aModFlags = anId >> 16;
	*aCharacter = anId & 0xFFFF;
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
			theResult = [theAllHotKeyEvents objectForKey:@(anID)];
		}
	}
	
	return theResult;
}

+ (instancetype)hotKeyWithEvent:(NSEvent *)anEvent
{
	return [[self alloc] initWithEvent:anEvent];
}

+ (instancetype)hotKeyWithEvent:(NSEvent *)anEvent target:(id)aTarget
{
	return [[self alloc] initWithEvent:anEvent target:aTarget];
}

+ (instancetype)hotKeyWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self alloc] initWithKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags target:nil];
}

+ (instancetype)hotKeyWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil];
}

+ (instancetype)hotKeyWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget
{
	return [[self alloc] initWithKeyCharacter:aKeyCharacter modifierFlags:aModifierFlags target:aTarget];
}

+ (instancetype)hotKeyWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget];
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
			theDescription = theAllHotKeyEvents.description;
		}
	}
	return theDescription;
}

#pragma mark - creation and destruction
- (instancetype)init NS_UNAVAILABLE
{
	NSAssert( NO, @"You can not initialize a Hot Key with the init method" );
	return nil;
}

- (instancetype)initWithEvent:(NSEvent *)anEvent
{
	return [self initWithEvent:anEvent target:nil];
}

- (instancetype)initWithEvent:(NSEvent *)anEvent target:(id)aTarget
{
	unsigned long		theModifierFlags = anEvent.modifierFlags & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);

	return [self initWithKeyCode:anEvent.keyCode
				   modifierFlags:theModifierFlags
						  target:aTarget];
}

- (instancetype)initWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:[[NDKeyboardLayout keyboardLayout] keyCodeForCharacter:aKeyCharacter numericPad:(aModifierFlags&NSNumericPadKeyMask) != 0] modifierFlags:aModifierFlags target:nil];
}

- (instancetype)initWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil];
}

- (instancetype)initWithKeyCode:(UInt16)aKeyCode modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget
{
	return [self initWithKeyCharacter:[[NDKeyboardLayout keyboardLayout] characterForKeyCode:aKeyCode] modifierFlags:aModifierFlags target:aTarget];
}

- (instancetype)initWithKeyCharacter:(unichar)aKeyCharacter modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget
{
	if( (self = [super init]) != nil )
	{
		_keyCharacter = aKeyCharacter;
		_modifierFlags = aModifierFlags;
		_target = aTarget;
		_currentEventType = NDHotKeyNoEvent;
		_isEnabled.collective = YES;
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
		if( aDecoder.allowsKeyedCoding )
		{
			NSNumber	* theValue = [aDecoder decodeObjectForKey:kArchivingKeyCharacterKey];
			if( theValue == nil )
			{
				theValue = [aDecoder decodeObjectForKey:kArchivingKeyCodeKey];
				_keyCharacter = [[NDKeyboardLayout keyboardLayout] characterForKeyCode:theValue.unsignedShortValue];
			}
			else
				_keyCharacter = theValue.unsignedShortValue;
			_modifierFlags = [[aDecoder decodeObjectForKey:kArchivingModifierFlagsKey] unsignedIntegerValue];
		}
		else
		{
			if( [aDecoder versionForClassName:@"NDHotKeyNoEvent"] == 1 )
			{
				unsigned short		theKeyCode;
				[aDecoder decodeValueOfObjCType:@encode(UInt16) at:&theKeyCode];
				_keyCharacter = [[NDKeyboardLayout keyboardLayout] characterForKeyCode:theKeyCode];
			}
			else
				[aDecoder decodeValueOfObjCType:@encode(unichar) at:&_keyCharacter];
			[aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&_modifierFlags];
		}

		[self addHotKey];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)anEncoder
{
	if( anEncoder.allowsKeyedCoding )
	{
		[anEncoder encodeObject:@(_keyCharacter) forKey:kArchivingKeyCharacterKey];
		[anEncoder encodeObject:@(_modifierFlags) forKey:kArchivingModifierFlagsKey];
	}
	else
	{
		[anEncoder encodeValueOfObjCType:@encode(unichar) at:&_keyCharacter];
		[anEncoder encodeValueOfObjCType:@encode(NSUInteger) at:&_modifierFlags];
	}
}

- (instancetype)initWithPropertyList:(id)aPropertyList
{
	if( aPropertyList )
	{
		NSNumber	* theKeyCode,
					* theModiferFlag;

		theKeyCode = aPropertyList[kArchivingKeyCodeKey];
		theModiferFlag = aPropertyList[kArchivingModifierFlagsKey];

		self = [self initWithKeyCode:theKeyCode.unsignedShortValue modifierFlags:theModiferFlag.unsignedIntValue];
	}
	else
		self = nil;

	return self;
}

- (id)propertyList
{
	return @{kArchivingKeyCodeKey: @([self keyCode]),
		kArchivingModifierFlagsKey: @([self modifierFlags])};
}

- (EventHotKeyRef)reference
{
	return _reference;
}

- (void)dealloc
{
	if( _reference )
	{
		if( UnregisterEventHotKey( _reference ) != noErr )	// in lock from release
			NSLog( @"Failed to unregister hot key %@", self );
	}

	[[NDHotKeyEvent allHotKeyEvents] removeObjectForKey:@(self.hotKeyId)];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NDKeyboardLayoutSelectedKeyboardInputSourceChangedNotification object:nil];

}

- (OSStatus)switchHotKey:(BOOL)aFlag
{
	OSStatus		theError = noErr;
	if( aFlag )
	{
		EventHotKeyID 		theHotKeyID;

		if( _reference )
			theError = UnregisterEventHotKey( _reference );
		if( theError == noErr )
		{
			theHotKeyID.signature = [NDHotKeyEvent signature];
			theHotKeyID.id = [self hotKeyId];

			NSCAssert( theHotKeyID.signature, @"HotKeyEvent signature has not been set yet" );
			NSCParameterAssert(sizeof(unsigned long) >= sizeof(id) );

			theError = RegisterEventHotKey( self.keyCode, NDCarbonModifierFlagsForCocoaModifierFlags(self.modifierFlags), theHotKeyID, GetEventDispatcherTarget(), 0, &_reference );
		}
	}
	else
	{
		theError = UnregisterEventHotKey( _reference );
		_reference = NULL;
	}

	return theError;
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
			if( aFlag == YES && _isEnabled.collective == YES  && _isEnabled.individual == NO )
				theResult = ([self switchHotKey:YES] == noErr);
			else if( aFlag == NO && _isEnabled.collective == YES  && _isEnabled.individual == YES )
				theResult = ([self switchHotKey:NO] == noErr);
		}

		if( theResult )
			_isEnabled.individual = aFlag;
		else
			NSLog(@"%s failed ", aFlag ? "enable" : "disable" );
	}
	else
		theResult = NO;

	return theResult;
}

- (void)setIsEnabled:(BOOL)aFlag { [self setEnabled:aFlag]; }

- (BOOL)isEnabled { return _isEnabled.individual && _isEnabled.collective; }
- (id <NDHotKeyEventTarget>)target { return _target; }
- (NDHotKeyEventType)currentEventType { return _currentEventType; }

#ifdef NS_BLOCKS_AVAILABLE
- (BOOL)setBlock:(void(^)(NDHotKeyEvent*))aBlock { return [self setReleasedBlock:aBlock pressedBlock:nil]; }
#endif

- (BOOL)setTarget:(id <NDHotKeyEventTarget>)aTarget
{
	BOOL	theResult = NO;
	[self setEnabled:NO];
	if( _target != nil && _target != aTarget )
	{
		if( ![_target respondsToSelector:@selector(targetWillChangeToObject:forHotKeyEvent:)] || [_target targetWillChangeToObject:aTarget forHotKeyEvent:self] )
		{
			_target = aTarget;
			theResult = YES;
		}
	}
	else
	{
		_target = aTarget;
		theResult = YES;
	}

#ifdef NS_BLOCKS_AVAILABLE
	_releasedBlock = nil;
	_pressedBlock = nil;
#endif

	return theResult;		// was change succesful
}

#ifdef NS_BLOCKS_AVAILABLE
- (BOOL)setReleasedBlock:(void(^)(NDHotKeyEvent*))aReleasedBlock pressedBlock:(void(^)(NDHotKeyEvent*))aPressedBlock
{
	BOOL	theResult = NO;
	[self setEnabled:NO];
	if( ![_target respondsToSelector:@selector(targetWillChangeToObject:forHotKeyEvent:)] || [_target targetWillChangeToObject:nil forHotKeyEvent:self] )
	{
		if( _releasedBlock != aReleasedBlock )
			_releasedBlock = [aReleasedBlock copy];

		if( _pressedBlock != aPressedBlock )
			_pressedBlock = [aPressedBlock copy];

		theResult = YES;
	}
	
	return theResult;		// was change succesful
}
#endif

- (void)performHotKeyReleased
{
	NSAssert( self.target != nil || _releasedBlock != nil, @"Release hot key fired without target or release block" );

	_currentEventType = NDHotKeyReleasedEvent;

	if([self.target respondsToSelector:@selector(hotKeyReleased:)])
		[self.target performSelector:@selector(hotKeyReleased:) withObject:self];
	else if( [self.target respondsToSelector:@selector(makeObjectsPerformSelector:withObject:)] )
		[(NSArray *)self.target makeObjectsPerformSelector:@selector(hotKeyReleased:) withObject:self];

#ifdef NS_BLOCKS_AVAILABLE
	else if( _releasedBlock )
		_releasedBlock(self);
#endif
	_currentEventType = NDHotKeyNoEvent;
}

- (void)performHotKeyPressed
{
	NSAssert( self.target != nil || _pressedBlock != nil, @"Release hot key fired without target or pressed block" );

	_currentEventType = NDHotKeyPressedEvent;

	if([self.target respondsToSelector:@selector(hotKeyPressed:)])
		[self.target performSelector:@selector(hotKeyPressed:) withObject:self];
	else if( [self.target respondsToSelector:@selector(makeObjectsPerformSelector:withObject:)] )
		[(NSArray *)self.target makeObjectsPerformSelector:@selector(hotKeyPressed:) withObject:self];

#ifdef NS_BLOCKS_AVAILABLE
	else if( _pressedBlock )
		_pressedBlock(self);
#endif

	_currentEventType = NDHotKeyNoEvent;
}

- (unichar)keyCharacter { return _keyCharacter; }
- (BOOL)keyPad { return _keyPad; }
- (UInt16)keyCode { return [[NDKeyboardLayout keyboardLayout] keyCodeForCharacter:self.keyCharacter numericPad:self.keyPad]; }
- (NSUInteger)modifierFlags { return _modifierFlags; }
- (UInt32)hotKeyId { return _idForCharacterAndModifier( self.keyCharacter, self.modifierFlags ); }
- (NSString *)stringValue { return [[NDKeyboardLayout keyboardLayout] stringForKeyCode:[self keyCode] modifierFlags:[self modifierFlags]]; }

- (BOOL)isEqual:(id)anObject
{
	return [super isEqual:anObject] || ([anObject isKindOfClass:[self class]] == YES && [self keyCode] == [(NDHotKeyEvent*)anObject keyCode] && [self modifierFlags] == [anObject modifierFlags]);
}

- (NSUInteger)hash { return (NSUInteger)self.keyCharacter | (self.modifierFlags<<16); }

- (NSString *)description
{
	return [NSString stringWithFormat:@"{\n\tKey Combination: %@,\n\tEnabled: %s\n}\n",
					[self stringValue],
					[self isEnabled] ? "yes" : "no"];
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
			[theHotEvent switchHotKey:theHotEvent.isEnabled];
		}
	}
}

- (void)addHotKey
{
	@synchronized([self class]) {
		[[NDHotKeyEvent allHotKeyEvents] setObject:self forKey:@([self hotKeyId])];
	}
}

- (void)removeHotKey
{
	[self setEnabled:NO];

	@synchronized([self class]) {
		[[NDHotKeyEvent allHotKeyEvents] removeObjectForKey:@([self hotKeyId])];
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
			if( aFlag == YES && _isEnabled.collective == NO  && _isEnabled.individual == YES )
				theResult = ([self switchHotKey:YES] == noErr);
			else if( aFlag == NO && _isEnabled.collective == YES  && _isEnabled.individual == YES )
				theResult = ([self switchHotKey:NO] == noErr);
		}

		if( theResult )
			_isEnabled.collective = aFlag;
		else
			NSLog(@"%s failed", aFlag ? "enable" : "disable" );
	}
	else
		theResult = NO;

	return theResult;
}

- (BOOL)collectiveEnabled { return _isEnabled.collective; }

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
	return [self hotKeyWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil];
}

/*
 * +hotKeyWithKeyCode:character:modifierFlags:target:selector:
 */
+ (id)hotKeyWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [[self alloc] initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget];
}

/*
 * -initWithKeyCode:character:modifierFlags:
 */
- (id)initWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:nil];
}

/*
 * -initWithKeyCode:character:modifierFlags:target:selector:
 */
- (id)initWithKeyCode:(UInt16)aKeyCode character:(unichar)aChar modifierFlags:(NSUInteger)aModifierFlags target:(id)aTarget selector:(SEL)aSelector
{
	return [self initWithKeyCode:aKeyCode modifierFlags:aModifierFlags target:aTarget];
}

@end
