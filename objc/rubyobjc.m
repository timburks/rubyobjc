/* 
 * rubyobjc.m
 *
 * Defines the ObjC module.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/* 
 * Document-module: ObjC
 *
 * The ObjC module contains the main elements of RubyObjC, a bridge connecting the Ruby and Objective-C programming languages.
 * RubyObjC allows code written in Ruby and Objective-C to be easily mixed,
 * yielding software implementations that exploit the strengths of both languages.
 *
 * - Ruby wrappers exist for Objective-C classes (ObjC::Class), methods (ObjC::Method), 
 *   instance variables (ObjC::Variable), and objects (ObjC::Object),
 *   giving Ruby programs direct access to the Objective-C runtime.
 * - Objective-C objects are accessible using Ruby wrappers that are instances of classes derived from ObjC::Object.
 *   Using information obtained from the ObjC::Class and ObjC::Method interfaces,
 *   these wrappers are given handlers for Objective-C methods to allow Ruby calls to Objective-C methods.
 * - When the Ruby wrapper class for a class of Objective-C objects is subclassed, a new Objective-C class is created automatically.
 *   Handlers for Ruby methods of the new subclass are added to allow those Ruby methods to be called from Objective-C.
 *   This is done using methods of ObjC::Class.
 * - Ruby wrappers for C functions can be created at runtime to allow Ruby calls to arbitrary C functions.
 *   Objective-C type signatures are used to specify argument and return types for all calls between Ruby and C.
 *   Arbitrary C functions are wrapped using instances of ObjC::Function.
 * - Many introspective features have been added to support debugging and performance analysis of the bridge itself.
 */

#import "rubyobjc.h"
#include <dlfcn.h>

VALUE module_require(int argc, VALUE *argv, VALUE self);

VALUE objc_verbose = Qnil;
VALUE objc_module;
long ruby_to_objc_calls = 0;
long objc_to_ruby_calls = 0;

static const char *copyright = "RubyObjC. Copyright 2007, Neon Design Technology, Inc. All Rights Reserved.";

static NSFileHandle *logFileHandle = nil;

void OBJC_LOG(NSString *format, ...)
{
    if (objc_verbose == Qnil)
        return;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (!logFileHandle) {
        NSString *path = @"rubyobjc.log";
        bool fileCreated = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        if (!fileCreated) NSLog (@"failed to create log file at %@", path);
        logFileHandle = [[NSFileHandle fileHandleForWritingAtPath:path] retain];
        if (!logFileHandle) NSLog (@"failed to open log file at %@", path);
    }
    va_list args;
    va_start(args, format);
    NSString *result = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [logFileHandle writeData:[@"ObjC: " dataUsingEncoding:NSASCIIStringEncoding]];
    [logFileHandle writeData:[result dataUsingEncoding:NSASCIIStringEncoding]];
    [logFileHandle writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [result release];
    [pool release];
}

VALUE global_method_hash = Qnil;

static int add_method_call_to_hash(st_data_t k, st_data_t v, st_data_t d)
{
    Method m = (Method) k;
 	int count = (int) v;
	VALUE key = method_create(m);
	VALUE value = INT2NUM(count);
	rb_hash_aset(global_method_hash, key, value);
    return ST_CONTINUE;
}

/* 
 * When Objective-C method call tracking is enabled, this returns a hash containing 
 * ObjC::Method objects as keys and the number of times each method has been called
 * from Ruby since tracking was enabled.
 */
VALUE module_method_calls(VALUE self)
{
    global_method_hash = rb_hash_new();
    if (objc_method_calls)
        st_foreach(objc_method_calls, add_method_call_to_hash, 0);
    return global_method_hash;
}

/*
 * Control tracking of Objective-C method calls. Set to true to enable tracking.
 */
VALUE module_set_method_tracking(VALUE self, VALUE value)
{
    if ((value == Qnil) || (value == Qfalse)) {
        if (objc_method_calls) {
            free(objc_method_calls);
        }
        objc_method_calls = nil;
    }
    else {
        objc_method_calls = st_init_numtable();
    }
    return value;
}

/*
 * Determine whether or not Objective-C method call tracking is enabled.
 */
VALUE module_method_tracking(VALUE self)
{
	return objc_method_calls ? Qtrue : Qfalse;
}

/* 
 * Add an ObjC::Function <i>p1</i> to the ObjC module as a module function.
 * The module function will have the same name as the ObjC::Function.
 * This method is typically used to wrap code that is not written in Objective-C.
 */
VALUE module_add_to_module(VALUE self, VALUE function_value)
{
    ObjC_Function *function;
    Data_Get_Struct(function_value, ObjC_Function, function);
    rb_define_module_function(self, function->name, function->handler, -1);
    return Qnil;
}

/* 
 * Add an integer constant to the ObjC module with the specified name <i>p1</i> and value <i>p2</i>.
 * This method is typically used to wrap code that is not written in Objective-C.
 */
VALUE module_add_enum(VALUE self, VALUE name, VALUE value)
{
    rb_define_const(self, StringValuePtr(name), value);
    return value;
}

/* 
 * Add a symbolic constant to the ObjC module by importing the value corresponding to the specified symbol <i>p1</i> and type <i>p2</i>.
 * This method is typically used to wrap code that is not written in Objective-C.
 */
VALUE module_add_constant(VALUE self, VALUE name, VALUE type)
{
    void *p = dlsym(RTLD_DEFAULT, StringValuePtr(name));
    if (!p) {
        NSLog(@"can't find symbol named %s", StringValuePtr(name));
        return Qnil;
    }
    char *typeStr = StringValuePtr(type);
    VALUE value = get_ruby_value_from_objc_value(p, typeStr, NULL);
    rb_define_const(self, StringValuePtr(name), value);
    return value;
}

/*
 * Get the verbosity of the ObjC module.
 */
VALUE module_verbose(VALUE self)
{
    return objc_verbose;
}

/* 
 * Control the verbosity of the ObjC module.  Set <i>p1</i> to non-nil to generate logging messages.
 */
VALUE module_set_verbose(VALUE self, VALUE value)
{
	if (value == Qfalse) value = Qnil;
    objc_verbose = value;
    return objc_verbose;
}

/*
 * Write a message <i>p1</i> to the bridge logfile.
 */
VALUE module_log(VALUE self, VALUE value)
{
    OBJC_LOG(@"%s", StringValuePtr(value));
    return Qnil;
}

/* 
 * Get the number of times Objective-C code has been called from Ruby.
 */
VALUE module_ruby_to_objc_calls(VALUE self)
{
    return LONG2NUM(ruby_to_objc_calls);
}

/* 
 * Get the number of times Ruby code has been called from Objective-C.
 */
VALUE module_objc_to_ruby_calls(VALUE self)
{
    return LONG2NUM(objc_to_ruby_calls);
}

/*
 * Get a string describing the RubyObjC copyright.
 */
VALUE module_copyright(VALUE self)
{
    return rb_str_new2(copyright);
}

/*
 * Set the Ruby search path to be used by the application.
 * Possible values are
 * :LOCAL (to use the search path of the locally-installed ruby),
 * :INTERNAL (to limit the search to the application's Resource directory),
 * or a Ruby array of path names to use as the search path.
 * This should be called at the beginning of any RubyObjC Cocoa application;
 * it should typically be the first statement in the application's main.rb file.
 */
VALUE module_set_path(VALUE self, VALUE path)
{
    VALUE name = rb_str_new2("ObjC");
    module_require(1, &name, objc_module);
    return rb_funcall(self, rb_intern("_set_path"), 1, path);
}

void Init_objc_base()
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    objc_module = rb_define_module("ObjC");
    Init_ObjC_Class(objc_module);
    Init_ObjC_Method(objc_module);
    Init_ObjC_Variable(objc_module);
    Init_ObjC_Object(objc_module);
    Init_ObjC_Function(objc_module);
    rb_define_module_function(objc_module, "add_function", module_add_to_module, 1);
    rb_define_module_function(objc_module, "add_enum", module_add_enum, 2);
    rb_define_module_function(objc_module, "add_constant", module_add_constant, 2);
    rb_define_module_function(objc_module, "set_path", module_set_path, 1);
    rb_define_module_function(objc_module, "verbose", module_verbose, 0);
    rb_define_module_function(objc_module, "verbose=", module_set_verbose, 1);
    rb_define_module_function(objc_module, "log", module_log, 1);
    rb_define_module_function(objc_module, "ruby_to_objc_calls", module_ruby_to_objc_calls, 0);
    rb_define_module_function(objc_module, "objc_to_ruby_calls", module_objc_to_ruby_calls, 0);
    rb_define_module_function(objc_module, "copyright", module_copyright, 0);
    rb_define_module_function(objc_module, "objc_method_calls", module_method_calls, 0);
    rb_define_module_function(objc_module, "objc_method_tracking", module_method_tracking, 0);
    rb_define_module_function(objc_module, "objc_method_tracking=", module_set_method_tracking, 1);
    Init_ObjC_Builtin(objc_module);
	[pool release];
}

void Init_objc()
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Init_objc_base();
    VALUE name = rb_str_new2("ObjC");
    module_require(1, &name, objc_module);
	[pool release];
}
