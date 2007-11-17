/* 
 * rubyobjc.h
 *
 * Top-level declarations for RubyObjC.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#import <objc/objc.h>
#import <objc/objc-runtime.h>
#import <objc/objc-class.h>
#import <objc/Protocol.h>
#ifdef LEOPARD_OBJC2
#import <objc/message.h>
#else
#import "tiger_runtime.h"
#endif
#import <Cocoa/Cocoa.h>
#import <ruby.h>
#include <string.h>
#include "ffi.h"

void OBJC_LOG(NSString *format, ...);

typedef struct __objc_class
{
    Class c;
} ObjC_Class;

typedef struct __objc_method
{
    Method m;
} ObjC_Method;

typedef struct __objc_variable
{
    Ivar v;
} ObjC_Variable;

typedef struct __objc_object
{
    id o;
	bool allow_release;
} ObjC_Object;

typedef struct __objc_function
{
    char *name;
    void *function;
    void *handler;
} ObjC_Function;

VALUE method_create(Method m);
void Init_ObjC_Method(VALUE module);

VALUE variable_create(Ivar v);
void Init_ObjC_Variable(VALUE module);

VALUE class_create(Class c);
void Init_ObjC_Class(VALUE module);

VALUE object_create(id o, SEL selector /* the selector that created the object or NULL if it was obtained by other means */);
void Init_ObjC_Object(VALUE module);

VALUE function_create(char *name, void *f, void *h);
void Init_ObjC_Function(VALUE Module);

void Init_ObjC_Builtin(VALUE module);

VALUE lookup_rbclass_for_occlass(Class c);

extern VALUE objc_verbose;
extern VALUE objc_module;
extern long ruby_to_objc_calls;
extern long objc_to_ruby_calls;

VALUE object_wrap_class(VALUE objc_class);

id get_objcid_from_rubyobject(VALUE ruby_object);
id get_objcclass_from_rubyclass(VALUE ruby_class);

ffi_type *ffi_type_for_objc_type(const char *typeString);
void *value_buffer_for_objc_type(const char *typeString);
void set_objc_value_from_ruby_value(void *objc_value, VALUE ruby_value, const char *typeString);
VALUE get_ruby_value_from_objc_value(void *objc_value, const char *typeString, SEL selector);
void object_set_allow_release_for_selector(VALUE value, SEL s);
ffi_cif *ruby_cif();

typedef VALUE(*rubyIMP)(ANYARGS);
rubyIMP construct_function_handler(const char *name, void *f, VALUE returnType, VALUE argTypes);
rubyIMP construct_objc_method_handler(Method m, int is_instance_method);
IMP construct_ruby_method_handler(SEL sel, const char *signature);

void remove_methods(VALUE class, const char *methodsToRemove[], int count);

#include "st.h"
st_table *objc_method_calls;