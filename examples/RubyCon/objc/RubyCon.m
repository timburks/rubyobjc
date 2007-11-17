/*
 * RubyCon.m
 *  initialization code for the RubyCon plugin.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */
#import <Cocoa/Cocoa.h>

extern int RubyObjC_BundleStart(NSString *filename);

static NSArray *bundleApps;
static int bundleInstalled = 0;

@interface RubyCon : NSObject
{
}

@end

@implementation RubyCon

+ (void) load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(install:) name:NSApplicationWillFinishLaunchingNotification object:nil];
    // specify the applications you want to enhance here.
    bundleApps = [[NSArray alloc] initWithObjects:
        @"com.apple.AddressBook",
        @"com.apple.Safari",
        0];
}

+ (void) install:(NSNotification*)_notification
{
    id pool = [[NSAutoreleasePool alloc] init];

    NSString* appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleApps containsObject:appIdentifier]) {
        if (!bundleInstalled) {
            NSBundle *bundle = [NSBundle bundleForClass:self];
            NSString *bundle_rb_file = [bundle pathForResource:@"bundle" ofType:@"rb"];
            if (RubyObjC_BundleStart(bundle_rb_file))
                bundleInstalled = 1;
            else
                NSLog(@"Ruby console plugin installation failed");
        }
    }
    [pool release];
}

@end
