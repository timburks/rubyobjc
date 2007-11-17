/* 
 * tiger_runtime.h
 *
 * Replacements for objc2.0 runtime enhancements only available in OS X 10.5 (Leopard).
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#ifndef LEOPARD_OBJC2
#import <stddef.h>
BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types);
Ivar *class_copyIvarList(Class cls, unsigned int *outCount);
Method *class_copyMethodList(Class cls, unsigned int *outCount);
Class class_getSuperclass(Class cls);
const char *ivar_getName(Ivar v);
ptrdiff_t ivar_getOffset(Ivar v);
const char *ivar_getTypeEncoding(Ivar v);
char *method_copyArgumentType(Method m, unsigned int index);
char *method_copyReturnType(Method m);
void method_getArgumentType(Method m, unsigned int index, char *dst, size_t dst_len);
IMP method_getImplementation(Method m);
SEL method_getName(Method m);
void method_getReturnType(Method m, char *dst, size_t dst_len);
const char *method_getTypeEncoding(Method m);
Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes);
void objc_registerClassPair(Class cls);
Class object_getClass(id obj);
#endif
