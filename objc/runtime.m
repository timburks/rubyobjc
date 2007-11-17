/* 
 * runtime.m
 *
 * Cocoa runtime support for RubyObjC.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import "rubyobjc.h"
#import <string.h>
#import <Foundation/Foundation.h>

void Init_objc_base();
void Init_objc();

/*
 * Call this instead of NSApplicationMain. Give it the name of the main Ruby file for your application.
 */
int RubyObjC_ApplicationMain(const char* main_rb, int argc, const char* argv[])
{
    id pool = [[NSAutoreleasePool alloc] init];
    // Push the main_rb file name onto the argv list and initialize Ruby.
    int new_argc = 0;
    const char **new_argv = malloc (sizeof(char*) * (argc + 2));
    int i;
    for (i = 0; i < argc; i++)
        if (strncmp(argv[i], "-psn_", 5) != 0)
            new_argv[new_argc++] = argv[i];
    if (main_rb == NULL) main_rb = "main.rb";
    NSBundle* bundle = [NSBundle mainBundle];
    new_argv[new_argc++] = strdup([[bundle pathForResource:[NSString stringWithUTF8String: main_rb] ofType:nil] fileSystemRepresentation]);
    new_argv[new_argc] = NULL;
    ruby_init();
    ruby_options(new_argc, (char**) new_argv);
    // Push the resource directory into the Ruby load path.
    char *resource_path = strdup([[bundle resourcePath] fileSystemRepresentation]);
    extern VALUE rb_load_path;
    rb_ary_unshift(rb_load_path, rb_str_new2(resource_path));
    Init_objc_base();
    [pool release];
    // Start the Ruby interpreter. It will never return.
    pool = [[NSAutoreleasePool alloc] init];
    ruby_run();
	[pool release];
	return 0;                                     // unreached
}

int RubyObjC_BundleStart(NSString *filename)
{
    ruby_init();
    Init_objc_base();
    NSError *err;
    NSString *program = [NSString stringWithContentsOfFile:filename encoding:NSASCIIStringEncoding error:&err];
    rb_eval_string([program cStringUsingEncoding:NSASCIIStringEncoding]);
    return true;
}


