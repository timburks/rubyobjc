/* 
 * teststructs.m
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import <Foundation/Foundation.h>

@interface StructTester : NSObject
{
}
@end

@interface StructTester(Ruby)
- (NSSize) rubyScaleSize:(NSSize) size by:(float)scale;
- (NSPoint) rubyScalePoint:(NSPoint) size by:(float)scale;
- (NSRect) rubyScaleRect:(NSRect) size by:(float)scale;
- (NSRange) rubyScaleRange:(NSRange) size by:(float)scale;
@end

@implementation StructTester

- (NSSize) scaleSize:(NSSize)size by:(float)scale
{
    return [self rubyScaleSize:size by:scale];
}

- (NSPoint) scalePoint:(NSPoint)point by:(float)scale
{
    return [self rubyScalePoint:point by:scale];
}

- (NSRect) scaleRect:(NSRect)rect by:(float)scale
{
    NSRect returnValue = [self rubyScaleRect:rect by:scale];
//	NSLog(@"scaleRect got %f %f %f %f from rubyScaleRect", returnValue.origin.x, returnValue.origin.y, returnValue.size.width, returnValue.size.height);
	return returnValue;
}

- (NSRange) scaleRange:(NSRange)range by:(float)scale
{
    return [self rubyScaleRange:range by:scale];
}

@end

// C functions that we call from Ruby with an ObjC::Function wrapper
NSSize scaleSize(NSSize size, float scale)
{
    NSSize newsize;
    newsize.width = size.width * scale;
    newsize.height = size.height * scale;
    return newsize;
}

NSRect scaleRect(NSRect rect, float scale)
{
    NSRect newrect;
    newrect.origin.x = rect.origin.x * scale;
    newrect.origin.y = rect.origin.y * scale;
    newrect.size.width = rect.size.width * scale;
    newrect.size.height = rect.size.height * scale;
    return newrect;
}


void Init_teststructs() {}
