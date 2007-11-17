/* 
 * objc_function.m
 *
 * Defines a Ruby wrapper that allows C functions to be loaded and manipulated from Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/* 
 * Document-class: ObjC::Function
 *
 * ObjC::Function wraps C functions for manipulation from Ruby.
 */
#import "rubyobjc.h"
#include <dlfcn.h>

static VALUE __function_class;

static void function_free(void *p)
{
    free(p);
}

static VALUE function_alloc(VALUE klass)
{
    ObjC_Function *function = (ObjC_Function *) malloc (sizeof (ObjC_Function));
    VALUE obj = Data_Wrap_Struct(klass, 0, function_free, function);
    function->function = 0;
    function->handler = 0;
    function->name = 0;
    return obj;
}

VALUE function_create(char *function_name, void *f, void *h)
{
    ObjC_Function *function = (ObjC_Function *) malloc (sizeof (ObjC_Function));
    function->function = f;
    function->handler = h;
    function->name = strdup(function_name);
    VALUE obj = Data_Wrap_Struct(__function_class, 0, function_free, function);
    return obj;
}

static void ffi_function_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata)
{
    int argc = *((int *)args[0]);
    VALUE *argv = *((VALUE **)args[1]);
    //VALUE self = *((VALUE *)args[2]);     	// the calling object or module, commented out because it is currently UNUSED

    OBJC_LOG(@"----------------------------------------");
    OBJC_LOG(@"calling C function %s", ((char **)userdata)[5]);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int argument_count = ((int *)userdata)[2];
    VALUE result = Qnil;
    if (argc != argument_count) {
        NSLog(@"error, argument count should be %d, only %d provided", argument_count, argc);
    }
    else {
        void *result_value = value_buffer_for_objc_type(((char **)userdata)[3]);
        void **argument_values = (void **) malloc (argument_count * sizeof(void *));
        int i;
        for (i = 0; i < argument_count; i++) {
            argument_values[i] = value_buffer_for_objc_type(  ((char***)userdata)[4][i]);
            set_objc_value_from_ruby_value(argument_values[i], argv[i], ((char***)userdata)[4][i]);
        }
        ffi_call(((ffi_cif **)userdata)[1], FFI_FN(((void**)userdata)[0]), result_value, argument_values);
        result = get_ruby_value_from_objc_value(result_value, ((char **)userdata)[3], NULL);
        // free the value structures
        for (i = 0; i < argument_count; i++)
            free(argument_values[i]);
        free(argument_values);
        free(result_value);
    }
    [pool release];
    *((VALUE *)returnvalue) = result;
}

rubyIMP construct_function_handler(const char *name, void *f, VALUE returnType, VALUE argTypes)
{
    int argument_count = (argTypes == Qnil) ? 0 : FIX2INT(rb_funcall2(argTypes, rb_intern("size"), 0, NULL));

    // give the handler the function pointer, the cif, and a representation of the argument types
    void **userdata = (void **) malloc (6 * sizeof(void *));
    userdata[0] = (void *) f;
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    userdata[1] = (void *) cif;
    userdata[2] = (void *) argument_count;
    userdata[3] = strdup(StringValuePtr(returnType));
    char **argument_userdata = (argument_count == 0) ? NULL : (char **) malloc (argument_count * sizeof(char *));
    userdata[4] = argument_userdata;
    int i;
    for (i = 0; i < argument_count; i++) {
        VALUE xyz = rb_ary_entry(argTypes, i);
        argument_userdata[i] = strdup(StringValuePtr(xyz));
    }
    userdata[5] = strdup(name);

    ffi_type *result_type = ffi_type_for_objc_type(userdata[3]);
    ffi_type **argument_types = (argument_count == 0) ? NULL : (ffi_type **) malloc (argument_count * sizeof(ffi_type *));
    for (i = 0; i < argument_count; i++)
        argument_types[i] = ffi_type_for_objc_type(argument_userdata[i]);

    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog (@"failed to prepare cif structure");
        return NULL;
    }
    ffi_closure *closure = (ffi_closure *)malloc(sizeof(ffi_closure));
    if (closure == NULL) {
        NSLog(@"failed to allocate closure");
        return NULL;
    }
    // all calls have this signature: VALUE (*)(int argc, VALUE *argv, VALUE self)
    ffi_cif *cif2 = ruby_cif();
    if (!cif2) {
        NSLog(@"failed to prepare cif");
    }
    if (ffi_prep_closure(closure, cif2, ffi_function_handler, userdata) != FFI_OK) {
        NSLog(@"failed to prepare closure");
        return NULL;
    }
    return (rubyIMP) closure;
}

/* 
 * Wrap a C function with a given name <i>p1</i> so that it can be called from Ruby
 * with the specified return type <i>p2</i> and arguments <i>p3</i>.  The return
 * type and argument types are described with Objective-C type encodings.
 * The argument types are passed in a Ruby array of strings.
 *
 * For example, to wrap the C function
 *    int NSApplicationMain(int argc, char *argv[])
 * you would use the following in Ruby:
 *    f = ObjC::Function.wrap('NSApplicationMain', 'i', %w{i ^*})
 * You could then call it with
 *    f.call(0, [])
 * Alternately, you could first install it in a module:
 *    f >> ObjC
 * and then call it like this:
 *    ObjC.NSApplicationMain(0, [])
 */
VALUE function_wrap(VALUE self, VALUE name, VALUE returnType, VALUE argTypes)
{
    char *function_name = StringValuePtr(name);
    void *function = dlsym(RTLD_DEFAULT, function_name);
    if (!function) {
        NSLog(@"%s", dlerror());
        NSLog(@"If you are using a release build, try rebuilding with the KEEP_PRIVATE_EXTERNS variable set.");
        NSLog(@"In Xcode, check the 'Preserve Private External Symbols' checkbox.");
        return Qnil;
    }
    void *handler = construct_function_handler(function_name, function, returnType, argTypes);
    VALUE wrapper = function_create(function_name, function, handler);
    return wrapper;
}

/*
 * Get the name of the corresponding function.
 */
VALUE function_name(VALUE self)
{
    ObjC_Function *function;
    Data_Get_Struct(self, ObjC_Function, function);
    return function->name ? rb_str_new2(function->name) : rb_str_new2("NULL");
}

/*
 * Call a wrapped C function with the associated arguments.
 */
VALUE function_call(int argc, VALUE *argv, VALUE self)
{
    ObjC_Function *function;
    Data_Get_Struct(self, ObjC_Function, function);
    VALUE result = ((rubyIMP) function->handler)(argc, argv, self);
    return result;
}

/*
 * Add the wrapped C function to the specified module <i>p1</i> as a module function.
 */
VALUE function_add_function_to_module(VALUE self, VALUE module)
{
    ObjC_Function *function;
    Data_Get_Struct(self, ObjC_Function, function);
    rb_define_module_function(module, function->name, function->handler, -1);
    return Qnil;
}

void Init_ObjC_Function(VALUE module)
{
                                                  // needed by RDoc
    if (!module) module = rb_define_module("ObjC");
    __function_class = rb_define_class_under(module, "Function", rb_cObject);
    rb_define_alloc_func(__function_class, function_alloc);
    rb_define_singleton_method(__function_class, "wrap", function_wrap, 3);
    rb_define_method(__function_class, "call", function_call, -1);
    rb_define_method(__function_class, "name", function_name, 0);
    rb_define_method(__function_class, "to_s", function_name, 0);
    rb_define_method(__function_class, ">>", function_add_function_to_module, 1);
}
