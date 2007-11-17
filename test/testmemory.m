/* 
 * testmemory.m
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import <Foundation/Foundation.h>

@interface MemoryTester : NSObject
{
    NSMutableArray *array;
}

- (void) createObjects:(int) n;
- (id) objectAtIndex:(int) i;
@end

@implementation MemoryTester

- (void) createObjects:(int) n
{
    array = [[NSMutableArray alloc] init];

    Class c = NSClassFromString(@"MyString");
    int i;
    for (i = 0; i < n; i++) {
        [array addObject:[[c alloc] initWithString:[NSString stringWithFormat:@"item %d", i]]];
    }
}

- (id) objectAtIndex:(int) i
{
    return [array objectAtIndex:i];
}

@end

void Init_testmemory() {}
