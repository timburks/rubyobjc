/*
 * RubySaver.m
 *  initialization code for the RubySaver screen saver plugin.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaverView.h>

extern int RubyObjC_BundleStart(NSString *filename);

static int bundleInstalled = 0;

@interface RubySaver : ScreenSaverView
{
}

@end

@implementation RubySaver

+ (void) initialize
{
    id pool = [[NSAutoreleasePool alloc] init];
    if (!bundleInstalled) {
        NSBundle *bundle = [NSBundle bundleForClass:self];
        NSString *bundle_rb_file = [bundle pathForResource:@"bundle" ofType:@"rb"];
        if (RubyObjC_BundleStart(bundle_rb_file))
            bundleInstalled = 1;
        else
            NSLog(@"Ruby screensaver installation failed");
    }
    [pool release];
}

@end
