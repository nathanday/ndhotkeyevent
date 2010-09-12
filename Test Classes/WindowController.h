/* WindowController */

#import <Cocoa/Cocoa.h>

@class			AddController;

@interface WindowController : NSWindowController
{
	IBOutlet NSTextView		* textView;
	IBOutlet AddController	* addController;

	BOOL					start;
	NSMutableArray			* allHotKeyReponder;
	BOOL					useBlocks;
}

@property	BOOL useBlocks;

- (IBAction)clear:(id)sender;
- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)allHotKey:(id)sender;

- (IBAction)addHotKey:(id)sender;
- (IBAction)newHotKey:(id)sender;
- (IBAction)removeHotKey:(id)sender;
- (IBAction)enableHotKey:(id)sender;
- (IBAction)disableHotKey:(id)sender;

- (IBAction)modifierKeysRequired:(id)sender;
- (IBAction)useBlocksChanged:(id)sender;

- (IBAction)readyForHotKey:(id)sender;

- (void)appendText:(NSString *)message;

@end
