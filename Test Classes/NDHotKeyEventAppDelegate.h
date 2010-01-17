//
//  NDHotKeyEventAppDelegate.h
//  NDHotKeyEvent
//
//  Created by Nathan Day on 20/10/09.
//  Copyright 2009 Nathan Day. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NDHotKeyEventAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
