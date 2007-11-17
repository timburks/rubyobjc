/* 
 * testspeed.m
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import <Foundation/Foundation.h>

@interface Tester : NSObject
{
}
- (int) add:(int) x to:(int)y;
@end

@implementation Tester

- (int) add:(int) x to:(int)y
{
	return x+y;
}

@end

// C functions that we call from Ruby with an ObjC::Function wrapper
int add(int x, int y)
{
   return x+y;
}

void Init_testspeed() {}
