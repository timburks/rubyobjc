/* 
 * objc_class.m
 *
 * Defines a Ruby wrapper that allows Objective-C classes to be manipulated from Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/* 
 * Document-class: ObjC::Class
 *
 * ObjC::Class wraps Objective-C classes for manipulation from Ruby.
 *
 * Using methods of this class, Objective-C class methods and instance methods can be accessed from Ruby.
 * New Objective-C classes can be added that subclass existing Objective-C classes;
 * this allows Ruby classes derived from Objective-C classes to be made visible to Objective-C callers.
 * New Objective-C method handlers can be added to allow Objective-C code to call methods written in Ruby.
 *
 * Information about Objective-C classes obtained from ObjC::Class instances is used to
 * automatically build a tree of Ruby classes descending from ObjC::Object.
 * Instances of these classes wrap individual Objective-C objects.
 */
#import "rubyobjc.h"

static VALUE __class_class;

//////////////////////////////////////////////////////////////////

void class_free(void *p)
{
    free(p);
}

VALUE class_alloc(VALUE klass)
{
    ObjC_Class *class = (ObjC_Class *) malloc (sizeof (ObjC_Class));
    class->c = 0;
    return Data_Wrap_Struct(klass, 0, class_free, class);
}

VALUE class_create(Class c)
{
    ObjC_Class *class = (ObjC_Class *) malloc (sizeof (ObjC_Class));
    class->c = c;
    return Data_Wrap_Struct(__class_class, 0, class_free, class);
}

/*
 * Lookup an Objective-C class for the given name <i>p1</i> and return an ObjC::Class wrapper.
 */
VALUE class_find(VALUE self, VALUE name)
{
    char *class_name = StringValuePtr(name);
    Class c = objc_getClass(class_name);
    if (!c) { return Qnil; }
    return class_create(c);
}

/*
 * Get the name of the corresponding Objective-C class.
 */
VALUE class_name(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    return c ? rb_str_new2(c->name) : rb_str_new2("NULL");
}

/*
 * Get the superclass of the corresponding Objective-C class.
 */
VALUE class_super(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    Class s = class_getSuperclass(c);
    if (!s) { return Qnil; }
    return class_create(s);
}

/* 
 * Compare the class with another class <i>p1</i>.
 */
VALUE class_compare(VALUE self, VALUE other)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    ObjC_Class *other_class;
    Data_Get_Struct(other, ObjC_Class, other_class);
    int r = strcmp(class->c->name, other_class->c->name);
    return INT2NUM(r);
}

/* 
 * Test class for equality with another class <i>p1</i>.
 */
VALUE class_equal(VALUE self, VALUE other)
{
    if (TYPE(other) != T_DATA) return Qfalse;
    ObjC_Class *class, *other_class;
    Data_Get_Struct(self, ObjC_Class, class);
    Data_Get_Struct(other, ObjC_Class, other_class);
    return (class->c == other_class->c) ? Qtrue : Qfalse;
}

/*
 * Get a hash value for a class.
 */
VALUE class_hash(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    return INT2FIX((int) c);
}

/*
 * Get an array containing the instance methods of the corresponding Objective-C class.
 * Returns an array of objects of type ObjC::Method. 
 */
VALUE class_instance_methods(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    VALUE arr = rb_ary_new();
    unsigned int method_count;
    Method *method_list = class_copyMethodList(c, &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        rb_ary_push(arr, method_create(method_list[i]));
    }
    free(method_list);
    return arr;
}

/*
 * Get an array containing the class methods of the corresponding Objective-C class.
 * Returns an array of objects of type ObjC::Method. 
 */
VALUE class_class_methods(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    VALUE arr = rb_ary_new();
    unsigned int method_count;
    Method *method_list = class_copyMethodList(object_getClass(c), &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        rb_ary_push(arr, method_create(method_list[i]));
    }
    free(method_list);
    return arr;
}

/*
 * Lookup an instance method of the corresponding Objective-C class by name <i>p1</i>.
 */
VALUE class_get_instance_method(VALUE self, VALUE name)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    char *method_name = StringValuePtr(name);
    SEL sel = sel_getUid(method_name);
    if (!sel) return Qnil;
    Method method = class_getInstanceMethod(c, sel);
    return method ? method_create(method) : Qnil;
}

/*
 * Lookup a class method of the corresponding Objective-C class by name <i>p1</i>.
 */
VALUE class_get_class_method(VALUE self, VALUE name)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    char *method_name = StringValuePtr(name);
    SEL sel = sel_getUid(method_name);
    if (!sel) return Qnil;
    Method method = class_getClassMethod(c, sel);
    return method ? method_create(method) : Qnil;
}

/*
 * Get an array containing the instance variables associated with the class.
 * Returns an array of objects of type ObjC::Variable.
 */
VALUE class_instance_variables(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    unsigned int ivar_count;
    Ivar *ivars = class_copyIvarList(c, &ivar_count);
    VALUE ivar_list = rb_ary_new();
    if (ivar_count == 0)
        return ivar_list;
    int i;
    for (i = 0; i < ivar_count; i++) {
        rb_ary_push(ivar_list, variable_create(ivars[i]));
    }
    free(ivars);
    return ivar_list;
}

/* 
 * Get an array containing all classes currently known to the Objective-C runtime.  Classes are returned as ObjC::Class objects.
 */
VALUE class_all(VALUE self)
{
    VALUE arr = rb_ary_new();
    int numClasses = objc_getClassList(NULL, 0);
    if(numClasses > 0) {
        Class *classes = (Class *) malloc( sizeof(Class) * numClasses );
        objc_getClassList(classes, numClasses);
        int i = 0;
        while (i < numClasses) {
            rb_ary_push(arr, class_create(classes[i]));
            i++;
        }
        free(classes);
    }
    return arr;
}

/* 
 * Iterate over all classes currently known to the Objective-C runtime.  Classes are returned as ObjC::Class objects.
 */
VALUE class_each(VALUE self)
{
    if (rb_block_given_p()) {
        int numClasses = objc_getClassList(NULL, 0);
        if(numClasses > 0) {
            Class *classes = (Class *) malloc( sizeof(Class) * numClasses );
            objc_getClassList(classes, numClasses);
            int i = 0;
            while (i < numClasses) {
                rb_yield(class_create(classes[i]));
                i++;
            }
            free(classes);
        }
    }
    return self;
}

/* 
 * Get an array containing the names of all protocols supported by the corresponding Objective-C class.
 */
VALUE class_protocols(VALUE self)
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    VALUE arr = rb_ary_new();
    struct objc_protocol_list *protocolList;
    protocolList = c->protocols;
    while( protocolList != NULL ) {
        int protocol_count = protocolList->count;
        int i = 0;
        while (i < protocol_count) {
            Protocol *p = protocolList->list[i];
            VALUE protocolName = rb_str_new2([p name]);
            rb_ary_push(arr, protocolName);
            i++;
        }
        // do something with the method list here
        protocolList = protocolList->next;
    }
    return arr;
}

VALUE add_objc_subclass(VALUE self, VALUE subclass_name)
/*
 * INTERNAL: Create a subclass of the underlying Objective-C class with the given name <i>p1</i>.
 */
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    const char *name = StringValuePtr(subclass_name);
    Class s = objc_allocateClassPair(c, name, 0);
    objc_registerClassPair(s);
    return class_create(s);
}

VALUE class_add_ruby_instance_method_handler(VALUE self, VALUE method_name, VALUE signature)
/*
 * INTERNAL: Add an instance method to the underlying Objective-C class to call Ruby instance methods with the given name <i>p1</i> and signature <i>p2</i>.
 * RubyObjC uses this internally to make Ruby instance methods available from Objective-C.
 */
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c;
    const char *method_name_str = StringValuePtr(method_name);
    const char *signature_str = StringValuePtr(signature);
    SEL sel = sel_registerName(method_name_str);

    IMP imp = construct_ruby_method_handler(sel, signature_str);
    if (imp == NULL) {
        NSLog(@"failed to construct handler for %s(%s)", method_name_str, signature_str);
        return Qfalse;
    }
    else {
        BOOL status = class_addMethod(c, sel, imp, signature_str);
        if (!status) {
            // don't complain, the class probably already had the method
            //NSLog(@"failed to add handler for %s(%s) to class %s", method_name_str, signature_str, c->name);
            return Qfalse;
        }
    }
    return Qtrue;
}

VALUE class_add_ruby_class_method_handler(VALUE self, VALUE method_name, VALUE signature)
/*
 * INTERNAL: Add a class method to the underlying Objective-C class to call Ruby class methods with the given name <i>p1</i> and signature <i>p2</i>.
 * RubyObjC uses this internally to make Ruby class methods available from Objective-C.
 */
{
    ObjC_Class *class;
    Data_Get_Struct(self, ObjC_Class, class);
    Class c = class->c->isa;
    const char *method_name_str = StringValuePtr(method_name);
    const char *signature_str = StringValuePtr(signature);
    SEL sel = sel_registerName(method_name_str);

    IMP imp = construct_ruby_method_handler(sel, signature_str);
    if (imp == NULL) {
        NSLog(@"failed to construct handler for %s(%s)", method_name_str, signature_str);
        return Qfalse;
    }
    else {
        BOOL status = class_addMethod(c, sel, imp, signature_str);
        if (!status) {
            // don't complain, the class probably already had the method
            //NSLog(@"failed to add handler for %s(%s) to class %s", method_name_str, signature_str, c->name);
            return Qfalse;
        }
    }
    return Qtrue;
}

//
// ObjC classes are mapped to instances of OC::Class and classes of OC::Objects
//
void Init_ObjC_Class(VALUE module)
{
                                                  // needed by RDoc
    if (!module) module = rb_define_module("ObjC");
    __class_class = rb_define_class_under(module, "Class", rb_cObject);
    rb_define_alloc_func(__class_class, class_alloc);
    rb_define_singleton_method(__class_class, "to_a", class_all, 0);
    rb_define_singleton_method(__class_class, "each", class_each, 0);
    rb_define_singleton_method(__class_class, "find", class_find, 1);
    rb_define_method(__class_class, "name", class_name, 0);
    rb_define_method(__class_class, "super", class_super, 0);
    rb_define_method(__class_class, "to_s", class_name, 0);
    rb_define_method(__class_class, "cmethods", class_class_methods, 0);
    rb_define_method(__class_class, "imethods", class_instance_methods, 0);
    rb_define_method(__class_class, "get_cmethod", class_get_class_method, 1);
    rb_define_method(__class_class, "get_imethod", class_get_instance_method, 1);
    rb_define_method(__class_class, "ivars", class_instance_variables, 0);
    rb_define_method(__class_class, "add_objc_subclass", add_objc_subclass, 1);
    rb_define_method(__class_class, "protocols", class_protocols, 0);
    rb_define_method(__class_class, "add_ruby_imethod_handler", class_add_ruby_instance_method_handler, 2);
    rb_define_method(__class_class, "add_ruby_cmethod_handler", class_add_ruby_class_method_handler, 2);
    rb_define_method(__class_class, "<=>", class_compare, 1);
    rb_define_method(__class_class, "==", class_equal, 1);
    rb_define_method(__class_class, "eql?", class_equal, 1);
    rb_define_method(__class_class, "hash", class_hash, 0);
}
