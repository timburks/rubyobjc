/* 
 * testobject.m
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import <Foundation/Foundation.h>

@interface TestObject : NSObject
{
#ifndef __OBJC2__
	BOOL _boolValue;
	int _intValue;
	long _longValue;
	float _floatValue;
	double _doubleValue;
#endif
}

#ifdef __OBJC2__
@property(ivar) BOOL boolValue;
@property(ivar) int intValue;
@property(ivar) long longValue;
@property(ivar) float floatValue;
@property(ivar) double doubleValue;
#else
- (BOOL) boolValue;
- (int) intValue;
- (long) longValue;
- (float) floatValue;
- (double) doubleValue;
- (void) setBoolValue:(BOOL) b;
- (void) setIntValue:(int) i;
- (void) setLongValue:(long) l;
- (void) setFloatValue:(float) f;
- (void) setDoubleValue:(double) d;
#endif
@end

@protocol Hello
- (NSString *) hello;
- (int) two;
- (int) add:(int)x plus:(int)y;
- (float) fadd:(float)x plus:(float)y;
- (double) dadd:(double)x plus:(double)y;
@end

@interface NSObject(RubyClassMethods)
+ (int) passInt:(int)x;
@end

@implementation TestObject
#ifndef __OBJC2__
- (BOOL) boolValue {return _boolValue;}
- (int) intValue {return _intValue;}
- (long) longValue {return _longValue;}
- (float) floatValue {return _floatValue;}
- (double) doubleValue {return _doubleValue;}
- (void) setBoolValue:(BOOL) b {_boolValue = b;}
- (void) setIntValue:(int) i {_intValue = i;}
- (void) setLongValue:(long) l {_longValue = l;}
- (void) setFloatValue:(float) f {_floatValue = f;}
- (void) setDoubleValue:(double) d {_doubleValue = d;}
#endif
- (void) logBoolValue {NSLog(@"%d", _boolValue);}
- (void) logIntValue {NSLog(@"%d", _intValue);}
- (void) logLongValue {NSLog(@"%ld", _longValue);}
- (void) logFloatValue {NSLog(@"%f", _floatValue);}
- (void) logDoubleValue {NSLog(@"%lf", _doubleValue);}

- (int) testStack
{
    int errors = 0;

    Class stackClass = NSClassFromString(@"Stack");
    id stack = [[stackClass alloc] init];
    NSString *hello = [stack hello];
    if (![hello isEqual:@"hello Brad, this is Matz"]) {
        NSLog(@"string mismatch: %@", hello);
        errors++;
    }

    int two = [stack two];
    if (two != 2) {
        NSLog(@"two = %d", two);
        errors++;
    }

    int four = [stack add:two plus:two];
    if (four != 4) {
        NSLog(@"int: two + two = %d", four);
        errors++;
    }

    float f_four = [stack fadd:(float)2.1 plus:(float)2.2];
    if (fabs(f_four - 4.3) > 0.00001) {
        NSLog(@"float: two + two = %f", f_four);
        errors++;
    }

    double d_four = [stack dadd:2.3 plus:2.4];
    if (fabs(d_four - 4.7) > 0.00001) {
        NSLog(@"double: two + two = %lf", d_four);
        errors++;
    }
    return errors;
}

- (int) testClassMethod
{
	int errors = 0;
	int x = [NSObject passInt:99];
	if (x != 99) {
		NSLog(@"passInt failed with return value %d", x);
		errors++;
	}
	return errors;
}

@end

int itwo()
{
    return 2;
}

char cadd(char a, char b)
{
	//NSLog(@"adding %d to %d", a, b);	
	return a+b;
}

unsigned char ucadd(unsigned char a, unsigned char b)
{
	//NSLog(@"adding %d to %d", a, b);	
	return a+b;
}

int iadd(int a, int b)
{
	//NSLog(@"adding %d to %d", a, b);	
    return a+b;
}

unsigned int uiadd(unsigned int a, unsigned int b)
{
	//NSLog(@"adding %lld to %lld", (long long) a, (long long) b);	
    return a+b;
}

long ladd(long a, long b)
{
	//NSLog(@"adding %ld to %ld", a, b);
    return a+b;
}

unsigned long uladd(unsigned long a, unsigned long b)
{
	//NSLog(@"adding %lld to %lld", (long long) a, (long long) b);
    return a+b;
}

long long qadd(long long a, long long b)
{
	//NSLog(@"adding %lld to %lld", a, b);
    return a+b;
}

unsigned long long uqadd(unsigned long long a, unsigned long long b)
{
	//NSLog(@"adding %lld to %lld", a, b);
    return a+b;
}

double dadd(double a, double b)
{
    return a+b;
}

char *testFunction(int argc, char *argv[])
{
	char *leakyBuffer = (char *) malloc (1024 * sizeof(char));
    int i;
	char *p = leakyBuffer;
	strcpy(p, "");
    for (i = 0; i < argc; i++) {
		strcpy(p, argv[i]);
		p += strlen(argv[i]);
    }
    return leakyBuffer;
}

void Init_testobject() {}
