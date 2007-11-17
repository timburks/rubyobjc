/* 
 * methods.m
 *
 * Contains functions that handle Objective-C method calls by forwarding them to Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

#include "rubyobjc.h"

#include "st.h"
st_table *objc_method_calls = 0;

@interface NSMethodSignature (UndocumentedInterface)
+ (id) signatureWithObjCTypes:(const char*)types;
@end

// beware the hack: we pretend that an array of VALUEs is really a single VALUE to get across the rb_protect interface.
static VALUE rb_protected_apply(VALUE args)
{
    return rb_apply(((VALUE *)args)[0], ((VALUE *)args)[1], ((VALUE *)args)[2]);
}

static void ffi_ruby_method_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata)
{
    objc_to_ruby_calls++;
    int argc = cif->nargs - 2;
    id rcv = *((id*)args[0]);
    // unused: SEL sel = *((SEL*)args[1]);
    // get a ruby wrapper for object
    VALUE ruby_object = object_create(rcv, NULL);
    char *ruby_name = ((char **)userdata)[1];
    if (objc_verbose != Qnil) {
        OBJC_LOG(@"----------------------------------------");
        OBJC_LOG(@"calling Ruby method %s", ruby_name);
    }
    VALUE arguments = rb_ary_new();
    int i;
    for (i = 0; i < argc; i++) {
        VALUE value = get_ruby_value_from_objc_value(args[i+2], ((char **)userdata)[i+2], NULL);
        rb_ary_push(arguments, value);
    }
    #ifdef RUBYOBJC_BYPASS_EXCEPTION_HANDLING
    VALUE result = rb_apply(ruby_object, rb_intern(ruby_name), arguments);
    #else
    VALUE protected_args[3];
    protected_args[0] = ruby_object;
    protected_args[1] = rb_intern(ruby_name);
    protected_args[2] = arguments;
    int errors;
    VALUE result = rb_protect(rb_protected_apply, (VALUE) protected_args, &errors);
    if (errors) {
        NSLog(@"ERROR: exception thrown in Ruby call to %s", ruby_name);
        VALUE lasterr = rb_gv_get("$!");
        // class
        VALUE klass = rb_class_path(CLASS_OF(lasterr));
        NSLog(@"class: %s", RSTRING(klass)->ptr);
        // message
        VALUE message = rb_obj_as_string(lasterr);
        NSLog(@"message: %s", RSTRING(message)->ptr);
        // backtrace
        if(!NIL_P(ruby_errinfo)) {
            VALUE ary = rb_funcall(ruby_errinfo, rb_intern("backtrace"), 0);
            int c;
            for (c=0; c<RARRAY(ary)->len; c++) {
                NSLog(@"from %s", RSTRING(RARRAY(ary)->ptr[c])->ptr);
            }
        }
    }
    #endif
    //NSLog(@"in ruby method handler, putting result in %x", (int) returnvalue);
    set_objc_value_from_ruby_value(returnvalue, result, ((char **)userdata)[0]);
}

IMP construct_ruby_method_handler(SEL sel, const char *signature)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
    const char *return_type_string = [methodSignature methodReturnType];
    ffi_type *result_type = ffi_type_for_objc_type(return_type_string);
    int argument_count = [methodSignature numberOfArguments];
    char **userdata = (char **) malloc ((argument_count+2) * sizeof(char*));
    ffi_type **argument_types = (ffi_type **) malloc (argument_count * sizeof(ffi_type *));
    userdata[0] = strdup(return_type_string);
    // get the method name, replacing colons with underscores
    const char *method_name = sel_getName(sel);
    char *ruby_name = (char *) malloc ((strlen(method_name)+1) * sizeof(char));
    int i;
    for(i = 0; true; i++) {
        char ch = method_name[i];
        ruby_name[i] = (ch == ':') ? '_' : ch;
        if (ch == 0) break;
    }
    userdata[1] = ruby_name;
    for (i = 0; i < argument_count; i++) {
        const char *argument_type_string = [methodSignature getArgumentTypeAtIndex:i];
        if (i > 1) userdata[i] = strdup(argument_type_string);
        argument_types[i] = ffi_type_for_objc_type(argument_type_string);
    }
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    if (cif == NULL) {
        NSLog(@"failed to allocate cif structure");
        return NULL;
    }
    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog (@"failed to prepare cif structure");
        NSLog (@"result type: %s", return_type_string);
        for (i = 0; i < argument_count; i++)
            NSLog(@"argument %d: %s", i, [methodSignature getArgumentTypeAtIndex:i]);
        return NULL;
    }
    ffi_closure *closure = (ffi_closure *)malloc(sizeof(ffi_closure));
    if (closure == NULL) {
        return NULL;
    }
    if (ffi_prep_closure(closure, cif, ffi_ruby_method_handler, userdata) != FFI_OK) {
        return NULL;
    }
    [pool release];
    return (IMP) closure;
}

static void raise_argc_exception(SEL s, int count, int given)
{
    rb_raise(rb_eRuntimeError, "incorrect number of arguments for selector %s, %d expected but %d provided", sel_getName(s), count, given);
}

#define BUFSIZE 500

typedef VALUE (*custom_handler)(IMP, SEL, id, int, VALUE*);

static void ffi_objc_method_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata)
{
    // NSLog(@"ffi_objc_method_handler cif %p nargs %d", cif, cif->nargs);
    Method m = ((Method *) userdata)[0];
    if (objc_verbose != Qnil) {
        OBJC_LOG(@"----------------------------------------");
        OBJC_LOG(@"calling ObjC method %s", sel_getName(method_getName(m)));
    }
    int is_instance_method = ((int *) userdata)[1];
    int argc = *((int *)args[0]);
    VALUE *argv = *((VALUE **)args[1]);
    VALUE self = *((VALUE *)args[2]);
    id target = is_instance_method ? get_objcid_from_rubyobject(self) : get_objcclass_from_rubyclass(self);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    IMP imp = method_getImplementation(m);
    SEL s = method_getName(m);
    VALUE result = Qnil;
    ruby_to_objc_calls++;
    if (objc_method_calls) {
        int count = 0;
        BOOL ok = st_lookup(objc_method_calls, (st_data_t)m, (st_data_t *)&count);
        if (!ok) count = 1; else count++;
        st_insert(objc_method_calls, (st_data_t)m, (st_data_t)count);
    }
    // use a hard-coded method handler if one is provided
    custom_handler handler = ((custom_handler *) userdata)[2];
    if (handler) {
        result = (handler)(imp, s, target, argc, argv);
    }
    // otherwise, dynamically construct the method call
    else {
        int argument_count = method_getNumberOfArguments(m);
        if (argc != argument_count-2) {
            raise_argc_exception(s, argument_count-2, argc);
        }
        else {
            char return_type_buffer[BUFSIZE], arg_type_buffer[BUFSIZE];
            method_getReturnType(m, return_type_buffer, BUFSIZE);
            ffi_type *result_type = ffi_type_for_objc_type(&return_type_buffer[0]);
            void *result_value = value_buffer_for_objc_type(&return_type_buffer[0]);
            ffi_type **argument_types = (ffi_type **) malloc (argument_count * sizeof(ffi_type *));
            void **argument_values = (void **) malloc (argument_count * sizeof(void *));
            int i;
            for (i = 0; i < argument_count; i++) {
                method_getArgumentType(m, i, &arg_type_buffer[0], BUFSIZE);
                argument_types[i] = ffi_type_for_objc_type(&arg_type_buffer[0]);
                argument_values[i] = value_buffer_for_objc_type(&arg_type_buffer[0]);
                if (i == 0)
                    *((id *) argument_values[i]) = target;
                else if (i == 1)
                    *((SEL *) argument_values[i]) = method_getName(m);
                else
                    set_objc_value_from_ruby_value(argument_values[i], argv[i-2], &arg_type_buffer[0]);
            }
            ffi_cif cif2;
            int status = ffi_prep_cif(&cif2, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
            if (status != FFI_OK) {
                NSLog (@"failed to prepare cif structure for objc method handler, status=%d", status);
                NSLog (@"result type: %s", return_type_buffer);
                for (i = 0; i < argument_count; i++) {
                    method_getArgumentType(m, i, &arg_type_buffer[0], BUFSIZE);
                    NSLog(@"argument %d: %s", i, arg_type_buffer);
                }
            }
            else {
                const char *name = 0;
                const char *reason = 0;
                @try
                {
                    ffi_call(&cif2, FFI_FN(imp), result_value, argument_values);
                }
                @catch (NSException *exception) {
                    name = [[exception name] cStringUsingEncoding:NSUTF8StringEncoding];
                    reason = [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding];
                    // [pool release]; this is a problem
                }
                if (name) {
                    rb_raise(rb_eRuntimeError, "%s, %s", name, reason);
                }
                result = get_ruby_value_from_objc_value(result_value, (const char *) &return_type_buffer[0], s);
                // if result value is an id, retain it
                if (return_type_buffer[0] == '@') object_set_allow_release_for_selector(result, s);
            }
            // free the value structures
            for (i = 0; i < argument_count; i++)
                free(argument_values[i]);
            free(argument_values);
            free(result_value);
            // free the argument type array (when this array is passed in as userdata, this should not be freed)
            free(argument_types);
        }
    }
    [pool release];
    *((VALUE *)returnvalue) = result;
}

// optimize method calls with hard-coded callers for specific signatures

// test function (i@:ii)
static VALUE signature_caller_0(IMP imp, SEL s, id target, int argc, VALUE *argv)
{
    if (argc != 2) raise_argc_exception(s, 2, argc);
    int arg0;
    set_objc_value_from_ruby_value(&arg0, argv[0], "i");
    int arg1;
    set_objc_value_from_ruby_value(&arg1, argv[1], "i");
    typedef int (*handler)(id, SEL, ...);
    int result_value = ((handler) imp)(target, s, arg0, arg1);
    return get_ruby_value_from_objc_value(&result_value, "i", s);
}

// actions (v@:@)
static VALUE signature_caller_1(IMP imp, SEL s, id target, int argc, VALUE *argv)
{
    if (argc != 1) raise_argc_exception(s, 1, argc);
    id arg0;
    set_objc_value_from_ruby_value(&arg0, argv[0], "@");
    typedef void (*handler)(id, SEL, ...);
    ((handler) imp)(target, s, arg0);
    return Qnil;
}

// accessors (@@:)
static VALUE signature_caller_2(IMP imp, SEL s, id target, int argc, VALUE *argv)
{
    if (argc != 0) raise_argc_exception(s, 0, argc);
    id result_value = imp(target, s);
    VALUE result = get_ruby_value_from_objc_value(&result_value, "@", s);
    object_set_allow_release_for_selector(result, s);
    return result;
}

// (v@:)
static VALUE signature_caller_3(IMP imp, SEL s, id target, int argc, VALUE *argv)
{
    if (argc != 0) raise_argc_exception(s, 0, argc);
    typedef void (*handler)(id, SEL, ...);
    ((handler) imp)(target, s);
    return Qnil;
}

struct signature_caller
{
    char *signature;
    void *caller;
};

struct signature_caller signature_callers[] =
{
    {"i16@0:4i8i12", &signature_caller_0},
    {"v12@0:4@8", &signature_caller_1},
    {"@8@0:4", &signature_caller_2},
    {"v8@0:4", &signature_caller_3}
};

// fast Objective-C method handler. Bypasses libffi.
static VALUE foh(int argc, VALUE *argv, VALUE self, void *userdata)
{
    Method m = ((Method *) userdata)[0];
    if (objc_verbose != Qnil) {
        OBJC_LOG(@"----------------------------------------");
        OBJC_LOG(@"fast-handling ObjC method %s", sel_getName(method_getName(m)));
    }
    int is_instance_method = ((int *) userdata)[1];
    id target = is_instance_method ? get_objcid_from_rubyobject(self) : get_objcclass_from_rubyclass(self);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    IMP imp = method_getImplementation(m);
    SEL s = method_getName(m);
    // use the hard-coded method handler
    custom_handler handler = ((custom_handler *) userdata)[2];
    VALUE result;
    if (handler) {
        result = (handler)(imp, s, target, argc, argv);
    }
    else {
        result = Qnil;
    }
    [pool release];
    return result;
}

#include "fast_handlers.i"

rubyIMP construct_objc_method_handler(Method m, int is_instance_method)
{
    // this array will be passed to the method handler.
    void **userdata = (void **) malloc (3 * sizeof(void *));
    if (!userdata) {
        NSLog(@"failed to allocate userdata");
        return NULL;
    }
    userdata[0] = (void *) m;
    userdata[1] = (void *) is_instance_method;
    userdata[2] = nil;                            // optional hard-coded method caller
    #ifndef RUBYOBC_DONT_OPTIMIZE_METHOD_CALLS
    // optimization 1: intercept specific signatures and use a hard-coded method caller instead of constructing the call with libffi.
    int i;
    int max = sizeof(signature_callers)/sizeof(struct signature_caller);
    const char *type_encoding = method_getTypeEncoding(m);
    for (i = 0; i < max; i++) {
        if (!strcmp(type_encoding, signature_callers[i].signature)) {
            userdata[2] = signature_callers[i].caller;
            break;
        }
    }
    // optimization 2: insert a pre-compiled handler into the Ruby method table instead of making one with libffi.
    if (userdata[2] && (global_handlers < MAX_HANDLERS)) {
        global_userdata[global_handlers] = userdata;
        return fast_objc_handlers[global_handlers++];
    }
    #endif
    // otherwise, we rely on libffi.
    ffi_cif *cif = ruby_cif();
    if (!cif) {
        NSLog(@"failed to prepare cif");
        return NULL;
    }
    ffi_closure *closure = (ffi_closure *)malloc(sizeof(ffi_closure));
    if (closure == NULL) {
        NSLog(@"failed to allocate closure");
        return NULL;
    }
    if (ffi_prep_closure(closure, cif, ffi_objc_method_handler, userdata) != FFI_OK) {
        NSLog(@"failed to prepare closure");
        return NULL;
    }
    return (rubyIMP) closure;
}

ffi_cif *ruby_cif()
{
    // all ruby method handlers that we generate have the same signature:
    // VALUE (*)(int argc, VALUE *argv, VALUE self)
    ffi_type *result_type = &ffi_type_ulong;      // VALUE
    ffi_type **argument_types = (ffi_type **) malloc (3 * sizeof(ffi_type *));
    argument_types[0] = &ffi_type_sint;           // int argc
    argument_types[1] = &ffi_type_pointer;        // VALUE *argv
    argument_types[2] = &ffi_type_ulong;          // VALUE self
    // construct the cif for the ruby method handler
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    if (cif == NULL) {
        NSLog(@"failed to allocate cif structure");
        return NULL;
    }
    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, 3, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog (@"failed to prepare cif structure for ruby method handler");
        return NULL;
    }
    return cif;
}
