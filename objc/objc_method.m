/* 
 * objc_method.m
 *
 * Defines a Ruby wrapper that allows Objective-C instance variables to be manipulated from Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/* 
 * Document-class: ObjC::Method
 *
 * ObjC::Method wraps Objective-C methods for manipulation from Ruby.
 */
#import "rubyobjc.h"
#include "string.h"

static VALUE __method_class;

static void method_free(void *p)
{
    free(p);
}

static VALUE method_alloc(VALUE klass)
{
    ObjC_Method *method = (ObjC_Method *) malloc (sizeof (ObjC_Method));
    method->m = 0;
    VALUE obj = Data_Wrap_Struct(klass, 0, method_free, method);
    return obj;
}

VALUE method_create(Method m)
{
    assert(m);
    ObjC_Method *method = (ObjC_Method *) malloc (sizeof (ObjC_Method));
    method->m = m;
    VALUE obj = Data_Wrap_Struct(__method_class, 0, method_free, method);
    return obj;
}

/*
 * Get the name of the method from the Objective-C runtime.
 */
VALUE method_name(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    return m ? rb_str_new2(sel_getName(method_getName(m))) : rb_str_new2("NULL");
}

/*
 * Get the signature of the method from the Objective-C runtime.
 * The signature is the concatenated codes for the method return type and the method argument types.
 */
VALUE method_signature(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    const char *encoding = method_getTypeEncoding(m);
    int len = strlen(encoding)+1;
    char *signature = (char *) malloc (len * sizeof(char));
    method_getReturnType(m, signature, len);
    int step = strlen(signature);
    char *start = &signature[step];
    len -= step;
    int argc = method_getNumberOfArguments(m);
    int i;
    for (i = 0; i < argc; i++) {
        method_getArgumentType(m, i, start, len);
        step = strlen(start);
        start = &start[step];
        len -= step;
    }
//  printf("%s %d %d %s\n", sel_getName(method_getName(m)), i, len, signature);
    VALUE result = rb_str_new2(signature);
    free(signature);
    return result;
}

/*
 * Get the type encoding of the method from the Objective-C runtime.
 * The type encoding is like the signature but also includes byte offsets of each argument (these offsets are not used by RubyObjC).
 */
VALUE method_type_encoding(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    return rb_str_new2(method_getTypeEncoding(m));
}

/*
 * Get the number of arguments of the method from the Objective-C runtime.
 */
VALUE method_argument_count(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    return INT2NUM(method_getNumberOfArguments(m));
}

/*
 * Get the type code of a method argument from the Objective-C runtime given its index <i>p1</i>.
 */
VALUE method_argument_type(VALUE self, VALUE index)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    int i = NUM2INT(index);
    Method m = method->m;
    if (i >= method_getNumberOfArguments(m))
        return Qnil;
    char *argumentType = method_copyArgumentType(m, i);
    VALUE result = rb_str_new2(argumentType);
    free(argumentType);
    return result;
}

/*
 * Get the type code of the method return value from the Objective-C runtime.
 */
VALUE method_return_type(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    char *returnType = method_copyReturnType(m);
    VALUE result = rb_str_new2(returnType);
    free(returnType);
    return result;
}

/*
 * Compare the method with another method <i>p1</i>.
 */
VALUE method_compare(VALUE self, VALUE other)
{
    ObjC_Method *method, *other_method;
    Data_Get_Struct(self, ObjC_Method, method);
    Data_Get_Struct(other, ObjC_Method, other_method);
    int r = strcmp(sel_getName(method_getName(method->m)), sel_getName(method_getName(other_method->m)));
    return INT2NUM(r);
}

/* 
 * Test a method for equality with another method <i>p1</i>.
 */
VALUE method_equal(VALUE self, VALUE other)
{
    if (TYPE(other) != T_DATA) return Qfalse;
    ObjC_Method *method, *other_method;
    Data_Get_Struct(self, ObjC_Method, method);
    Data_Get_Struct(other, ObjC_Method, other_method);
    return (method->m == other_method->m) ? Qtrue : Qfalse;
}

/*
 * Get a hash value for a method.
 */
VALUE method_hash(VALUE self)
{
    ObjC_Method *method;
    Data_Get_Struct(self, ObjC_Method, method);
    Method m = method->m;
    return INT2FIX((int) m);
}

/* 
 * Interface to Method descriptions in the Objective-C Runtime
 */
void Init_ObjC_Method(VALUE module)
{
                                                  // needed by RDoc
    if (!module) module = rb_define_module("ObjC");
    __method_class = rb_define_class_under(module, "Method", rb_cObject);
    rb_define_alloc_func(__method_class, method_alloc);
    rb_define_method(__method_class, "type_encoding", method_type_encoding, 0);
    rb_define_method(__method_class, "argument_count", method_argument_count, 0);
    rb_define_method(__method_class, "argument_type", method_argument_type, 1);
    rb_define_method(__method_class, "return_type", method_return_type, 0);
    rb_define_method(__method_class, "signature", method_signature, 0);
    rb_define_method(__method_class, "name", method_name, 0);
    rb_define_method(__method_class, "to_s", method_name, 0);
    rb_define_method(__method_class, "<=>", method_compare, 1);
    rb_define_method(__method_class, "==", method_equal, 1);
    rb_define_method(__method_class, "eql?", method_equal, 1);
    rb_define_method(__method_class, "hash", method_hash, 0);
}
