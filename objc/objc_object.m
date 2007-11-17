/* 
 * objc_object.m
 *
 * Defines a Ruby wrapper that allows Objective-C objects to be manipulated from Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/*
 * Document-class: ObjC::Object
 *
 * ObjC::Object wraps Objective-C objects for manipulation from Ruby.
 *
 * ObjC::Object is the root class for a tree of Ruby classes.
 * Subclasses are automatically generated on demand to match the Objective-C class hierarchy.
 * There is a one-to-one mapping between the Ruby classes of wrapper objects
 * and the Objective-C classes of the objects being wrapped.
 *
 * Objective-C classes are also represented by instances of the Ruby class ObjC::Class,
 * which provides Ruby access to class information maintained in the Objective-C runtime.
 */

/* 
 * Document-class: ObjC::ObjectManager
 *
 * INTERNAL: One instance of this singleton class is created by the ObjC module.
 */

#include "rubyobjc.h"
#include "st.h"

st_table *rb_objects;                             // table of ruby wrappers for objc objects (keyed by id)

VALUE __object_class = 0;

id get_objcid_from_rubyobject(VALUE ruby_object)
{
    ObjC_Object *object_wrapper;
    Data_Get_Struct(ruby_object, ObjC_Object, object_wrapper);
    return object_wrapper->o;
}

id get_objcclass_from_rubyclass(VALUE ruby_class)
{
    VALUE classHash = rb_cvar_get(ruby_class, rb_intern("@@occlass_for_rbclass"));
    VALUE objc_class = rb_hash_aref(classHash, ruby_class);
    ObjC_Class *class_wrapper;
    Data_Get_Struct(objc_class, ObjC_Class, class_wrapper);
    return class_wrapper->c;
}

/////

static int __object_count;

static int yield_object(st_data_t k, st_data_t v, st_data_t d)
{
    VALUE value = (VALUE) v;
    if (((VALUE)d == Qnil) || rb_obj_is_kind_of(value, (VALUE)d)) {
        if (rb_block_given_p())
            rb_yield(value);
        __object_count++;
    }
    return ST_CONTINUE;
}

/*
 * Iterate over the entries in the bridge's internal table of wrapped objects.
 * The table exists to ensure that any Objective-C object has at most one Ruby wrapper.
 * If an optional class (derived from ObjC::Object) is specified, only objects
 * of that class or its children are returned.
 */
VALUE object_each_object(int argc, VALUE *argv, VALUE self)
{
    VALUE object_class = (argc == 1) ? argv[0] : Qnil;
    __object_count = 0;
    if (rb_objects)
        st_foreach(rb_objects, yield_object, object_class);
    return INT2NUM(__object_count);
}

//////////////////////////////////////////////////////////////////

const char *object_class_name(id o)
{
    if (o == nil)
        return "nil";
    else {
        Class c = object_getClass(o);
        return c->name;
    }
}

void object_free(void *p)
{
    ObjC_Object *object = (ObjC_Object *)p;
    id objc_id = object->o;
    OBJC_LOG(@"removing %x (%s) from object table", (int) objc_id, object_class_name(objc_id));
    if (object->allow_release) {
        OBJC_LOG(@"object_free releasing %x (retain count is %d)", (long) objc_id, [objc_id retainCount]);
        [objc_id release];
    }
    else {
        OBJC_LOG(@"object_free not allowed to release %x (retain count is %d)", (long) objc_id, [objc_id retainCount]);
    }
    // remove wrapper from table of wrapped ids
    st_delete(rb_objects, (st_data_t *) &objc_id, NULL);
    free(object);
}

void object_mark(void *p)
{
    ObjC_Object *object = (ObjC_Object *)p;
    id objc_id = object->o;
    OBJC_LOG(@"ruby GC marking %x (%s)", (int) objc_id, object_class_name(objc_id));
}

VALUE object_create(id o, SEL s)
{
    VALUE result;
    BOOL ok = st_lookup(rb_objects, (st_data_t)o, (st_data_t *)&result);
    if (ok) {
        OBJC_LOG(@"object wrapper found in cache %x (%s)", (int) o, object_class_name(o));
        return result;
    }
    Class c = object_getClass(o);
    if (CLS_GETINFO(c, CLS_META)) {
        // The object is a class.  Return the corresponding Ruby subclass of ObjC::Object.
        VALUE result = lookup_rbclass_for_occlass(o);
        if (result == Qnil)
            result = object_wrap_class(class_create(o));
        return result;
    }
    VALUE result_class = lookup_rbclass_for_occlass(c);
    if (result_class == Qnil)
        result_class = object_wrap_class(class_create(c));
    ObjC_Object *object = (ObjC_Object *) malloc (sizeof (ObjC_Object));
    bool already_retained =                       // see Anguish/Buck/Yacktman, p. 104
        (s == @selector(alloc)) || (s == @selector(allocWithZone:))
        || (s == @selector(copy)) || (s == @selector(copyWithZone:))
        || (s == @selector(mutableCopy)) || (s == @selector(mutableCopyWithZone:))
        || (s == @selector(new));
    if (!already_retained) {
        [o retain];
        OBJC_LOG(@"object_create retaining %x (retain count is %d)", (long) o, [o retainCount]);
    }
    object->o = o;
    object->allow_release = true;
    result = Data_Wrap_Struct(result_class, object_mark, object_free, object);
    OBJC_LOG(@"adding %x (%s) to object table", (int) o, rb_class2name(result_class));
    st_insert(rb_objects, (st_data_t)o, (st_data_t)result);
    return result;
}

void object_set_allow_release_for_selector(VALUE value, SEL s)
{
    if (value == Qnil)
        return;
    ObjC_Object *object;
    Data_Get_Struct(value, ObjC_Object, object);
    // objects returned by alloc (and not yet initialized) should not be released; they may be placeholder objects
    object->allow_release = (s != @selector(alloc) && s != @selector(allocWithZone:));
}

/*
 * Get the instance methods defined for the underlying Objective-C class.
 * Returns an array of objects of type ObjC::Method.
 */
VALUE object_instance_methods(VALUE self)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    Class c = object_getClass(object->o);
    VALUE arr = rb_ary_new();
    unsigned int method_count;
    Method *method_list = class_copyMethodList(c, &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        rb_ary_push(arr, method_create(method_list[i]));
    }
    return arr;
}

/*
 * Get the class methods defined for the underlying Objective-C class.
 * Returns an array of objects of type ObjC::Method.
 */
VALUE object_class_methods(VALUE self)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    Class c = object_getClass(object->o);
    VALUE arr = rb_ary_new();
    unsigned int method_count;
    Method *method_list = class_copyMethodList(object_getClass(c), &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        rb_ary_push(arr, method_create(method_list[i]));
    }
    return arr;
}

/*
 * Lookup an instance method of the corresponding Objective-C object by name <i>p1</i>.
 */
VALUE object_get_instance_method(VALUE self, VALUE name)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    Class c = object_getClass(object->o);
    char *method_name = StringValuePtr(name);
    SEL sel = sel_getUid(method_name);
    if (!sel) return Qnil;
    Method method = class_getInstanceMethod(c, sel);
    return method_create(method);
}

/*
 * Lookup a class method of the corresponding Objective-C object by name <i>p1</i>.
 */
VALUE object_get_class_method(VALUE self, VALUE name)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    Class c = object_getClass(object->o);
    char *method_name = StringValuePtr(name);
    SEL sel = sel_getUid(method_name);
    if (!sel) return Qnil;
    Method method = class_getClassMethod(c, sel);
    return method_create(method);
}

enum {OBJC_INVOKE, OBJC_FORWARD};

static VALUE object_invoke_or_forward(VALUE self, VALUE selector, VALUE arguments, int invoke_or_forward)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    SEL sel = sel_getUid(StringValuePtr(selector));
    if (sel == 0) {
        [pool release];
        rb_raise(rb_eNoMethodError, "unable to find selector %s", StringValuePtr(selector));
    }
    NSMethodSignature *methodSignature = [object->o methodSignatureForSelector:sel];
    if (!methodSignature) {
        [pool release];
        rb_raise(rb_eNoMethodError, "unable to forward selector %s", StringValuePtr(selector));
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    [invocation setTarget:object->o];
    [invocation setSelector:sel];
    int argc = [methodSignature numberOfArguments];
    // the following code does some error checking on the arguments array
    int length = NUM2INT(rb_funcall(arguments, rb_intern("length"), 0, nil));
    if (argc-2 != length) {
        [pool release];
        rb_raise(rb_eRuntimeError, "incorrect number of arguments given for selector %s, %d expected, %d given", StringValuePtr(selector), argc-2, length);
    }
    void *buffer;
    int i;
    for (i = 2; i < argc; i++) {
        buffer = value_buffer_for_objc_type([methodSignature getArgumentTypeAtIndex:i]);
        set_objc_value_from_ruby_value(buffer, rb_ary_entry(arguments, i-2), [methodSignature getArgumentTypeAtIndex:i]);
        [invocation setArgument:buffer atIndex:i];
        free(buffer);
    }
    @try
    {
        if (invoke_or_forward == OBJC_INVOKE)
            [invocation invoke];
        else
            [object->o forwardInvocation:invocation];
    }
    @catch (NSException *exception) {
        const char *name = [[exception name] cStringUsingEncoding:NSUTF8StringEncoding];
        const char *reason = [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding];
        rb_raise(rb_eNoMethodError, "%s, %s", name, reason);
        // [pool release]; this is a problem
    }
    VALUE result;
    if (!strcmp([methodSignature methodReturnType], "v")) {
        result = Qnil;
    }
    else {
        buffer = value_buffer_for_objc_type([methodSignature methodReturnType]);
        [invocation getReturnValue:buffer];
        result = get_ruby_value_from_objc_value(buffer, [methodSignature methodReturnType], nil);
        free(buffer);
    }
    [pool release];
    return result;
}

/* 
 * Attempt to invoke the specified selector <i>p1</i> with the given array of arguments <i>p2</i>.
 * Raise an exception if the invocation fails.
 */
VALUE object_invoke(VALUE self, VALUE selector, VALUE arguments)
{
    return object_invoke_or_forward(self, selector, arguments, OBJC_INVOKE);
}

/* 
 * Attempt to forward the specified selector <i>p1</i> with the given array of arguments <i>p2</i>.
 * Raise an exception if the forwarding fails.
 */
VALUE object_forward(VALUE self, VALUE selector, VALUE arguments)
{
    return object_invoke_or_forward(self, selector, arguments, OBJC_FORWARD);
}

/* 
 * Compare the object with another object <i>p1</i>.
 */
VALUE object_compare(VALUE self, VALUE other)
{
    ObjC_Object *object, *other_object;
    Data_Get_Struct(self, ObjC_Object, object);
    Data_Get_Struct(other, ObjC_Object, other_object);
    int r = ((int) object->o > (int)other_object->o) ? 1 : ((int) object->o < (int)other_object->o) ? -1 : 0;
    return INT2NUM(r);
}

/* 
 * Test object for equality with another object <i>p1</i>.
 */
VALUE object_equal(VALUE self, VALUE other)
{
    if (TYPE(other) != T_DATA) return Qfalse;
    ObjC_Object *object, *other_object;
    Data_Get_Struct(self, ObjC_Object, object);
    Data_Get_Struct(other, ObjC_Object, other_object);
    return (object->o == other_object->o) ? Qtrue : Qfalse;
}

/*
 * Get a hash value for an object.
 */
VALUE object_hash(VALUE self)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    id obj = object->o;
    return INT2FIX((int) obj);
}

VALUE rb_any_to_s _((VALUE));                     // from ruby internals, convert any object to string

/*
 * Get a string representation of the object.
 * If the object responds to the bytes and length methods (eg. NSData), they are used to create the string.
 * If the object responds to the cStringUsingEncoding method (eg. NSString), it is used to create the string.
 * If the object responds to the stringValue method (eg. NSControl, NSNumber), it is used to create the string.
 * Otherwise, this representation is identical to the one produced by the inspect method.
 */
VALUE object_to_s(VALUE self)
{
    @try
    {
        ObjC_Object *object;
        Data_Get_Struct(self, ObjC_Object, object);
        id obj = object->o;
        if ([obj respondsToSelector:@selector(bytes)] && [obj respondsToSelector:@selector(length)]) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            VALUE returnValue = rb_str_new([obj bytes], [obj length]);
            [pool release];
            return returnValue;
        }
        else if ([obj respondsToSelector:@selector(cStringUsingEncoding:)]) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            const char *s = [obj cStringUsingEncoding:NSASCIIStringEncoding];
            VALUE returnValue = s ? rb_str_new2(s) : Qnil;
            [pool release];
            return returnValue;
        }
        else if ([obj respondsToSelector:@selector(stringValue)]) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            const char *s = [[obj stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
            VALUE returnValue = s ? rb_str_new2(s) : Qnil;
            [pool release];
            return returnValue;
        }
        else {
            return rb_any_to_s(self);
        }
    }
    @catch (NSException *exception) {
        const char *name = [[exception name] cStringUsingEncoding:NSUTF8StringEncoding];
        const char *reason = [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding];
        rb_raise(rb_eNoMethodError, "%s, %s", name, reason);
    }
    return Qnil;
}

/*
 * Get a string description of the object.
 */
VALUE object_inspect(VALUE self)
{
    return rb_any_to_s(self);
}

/*
 * Get a floating-point representation of the object, if possible. Otherwise, return zero.
 */
VALUE object_to_f(VALUE self)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    id obj = object->o;
    if ([obj respondsToSelector:@selector(doubleValue)]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        VALUE returnValue = rb_float_new([obj doubleValue]);
        [pool release];
        return returnValue;
    }
    else {
        return rb_float_new(0.0);
    }
}

/*
 * Get an integer representation of the object, if possible. Otherwise, return zero.
 */
VALUE object_to_i(VALUE self)
{
    ObjC_Object *object;
    Data_Get_Struct(self, ObjC_Object, object);
    id obj = object->o;
    if ([obj respondsToSelector:@selector(intValue)]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        VALUE returnValue = INT2NUM([obj intValue]);
        [pool release];
        return returnValue;
    }
    else {
        return INT2NUM(0);
    }
}

VALUE lookup_rbclass_for_occlass(Class c)
{
    VALUE classHash = rb_cvar_get(__object_class, rb_intern("@@rbclass_for_occlass"));
    VALUE classWrapper = class_create(c);
    return rb_hash_aref(classHash, classWrapper);
}

static VALUE link_classes(VALUE self, VALUE rb_class, VALUE oc_class)
/* 
 * INTERNAL: Associate a Ruby wrapper class <i>p1</i> (derived from ObjC::Object) with the corresponding instance of ObjC::Class <i>p2</i>.
 */
{
    VALUE rbclass_for_occlass = rb_cvar_get(__object_class, rb_intern("@@rbclass_for_occlass"));
    rb_hash_aset(rbclass_for_occlass, oc_class, rb_class);
    VALUE occlass_for_rbclass = rb_cvar_get(__object_class, rb_intern("@@occlass_for_rbclass"));
    rb_hash_aset(occlass_for_rbclass, rb_class, oc_class);
    return Qnil;
}

static VALUE add_ruby_subclass(VALUE self, VALUE oc_class, VALUE name)
/* 
 * INTERNAL: Add a new subclass to wrap an Objective-C subclass of the Objective-C class corresponding to the ObjC::Class instance <i>p1</i>.
 * The new subclass name is also passed as a parameter <i>p2</i>. RubyObjC uses this internally to build the tree of wrapper
 * classes rooted at ObjC::Object.
 */
{
    VALUE new_class = rb_define_class_under(objc_module, StringValuePtr(name), self);
    link_classes(self, new_class, oc_class);
    return new_class;
}

static VALUE claim_ruby_subclass(VALUE self, VALUE oc_class, VALUE name)
{                                                 // Here good and evil are one. This method reparents an existing class into the ObjC class hierarchy.
    VALUE new_class = rb_funcall(objc_module, rb_intern("const_get"), 1, name);
    // set superclass to self
    RCLASS(new_class)->super = self;
    // set metaclass superclass to self's metaclass
    RCLASS(RCLASS(new_class)->basic.klass)->super = CLASS_OF(self);
    link_classes(self, new_class, oc_class);
    return new_class;
}

static VALUE add_objc_instance_method_handler(VALUE self, VALUE method, VALUE name)
/* 
 * INTERNAL: Add an instance method handler to an ObjC::Object subclass to handle an Objective-C instance method <i>p1</i>
 * with the specified name <i>p2</i>. RubyObjC uses this internally to make Objective-C instance methods available from Ruby.
 */
{
    ObjC_Method *method_s;
    Data_Get_Struct(method, ObjC_Method, method_s);
    Method m = method_s->m;
    rb_define_method(self, StringValuePtr(name), construct_objc_method_handler(m, true), -1);
    return Qnil;
}

static VALUE add_objc_class_method_handler(VALUE self, VALUE method, VALUE name)
/* 
 * INTERNAL: Add a class method handler to to an ObjC::Object subclass to handle an Objective-C class method <i>p1</i>
 * with the specified name <i>p2</i>. RubyObjC uses this internally to make Objective-C class methods available from Ruby.
 */
{
    ObjC_Method *method_s;
    Data_Get_Struct(method, ObjC_Method, method_s);
    Method m = method_s->m;
    rb_define_singleton_method(self, StringValuePtr(name), construct_objc_method_handler(m, false), -1);
    return Qnil;
}

VALUE object_wrap_class(VALUE objc_class)
{
    return rb_funcall(__object_class, rb_intern("wrap_class"), 1, objc_class);
}

void remove_methods(VALUE class, const char *methodsToRemove[], int count)
{
    int i;
    for (i = 0; i < count; i++) {
        rb_undef_method(CLASS_OF(__object_class), methodsToRemove[i]);
    }
}

/* 
 * Get the number of entries in the bridge's internal table of wrapped objects.
 * The table exists to ensure that any Objective-C object has at most one Ruby wrapper.
 */
VALUE object_count(VALUE module)
{
    return INT2NUM(rb_objects->num_entries);
}

static VALUE __object_manager_class;

static int mark_object_if_retained(st_data_t k, st_data_t v, st_data_t d)
{
    VALUE value = (VALUE) v;
    ObjC_Object *object;
    Data_Get_Struct(value, ObjC_Object, object);
    int retainCount = [object->o retainCount];
    if ((retainCount > 1) && (retainCount != 2147483647)) {
        if (objc_verbose != Qnil) OBJC_LOG(@"marking %@ %d", object_getClass(object->o), retainCount);
        rb_gc_mark(value);
    }
    else {
        //if (objc_verbose != Qnil) OBJC_LOG(@"NOT marking %@ %d", object_getClass(object->o), retainCount);
    }
    return ST_CONTINUE;
}

/*
 * Iterate over the entries in the bridge's internal table of wrapped objects.
 * If any have retain counts > 1, then mark them so they won't be garbage collected.
 */
void object_mark_retained()
{
    //if (objc_verbose != Qnil) OBJC_LOG(@"object manager: marking all retained objects");
    if (rb_objects)
        st_foreach(rb_objects, mark_object_if_retained, 0);
    //if (objc_verbose != Qnil) OBJC_LOG(@"object manager: finished marking all retained objects");
}

void Init_ObjC_Object(VALUE module)
{
                                                  // needed by RDoc
    if (!module) module = rb_define_module("ObjC");
    rb_objects = st_init_numtable();
    __object_class = rb_define_class_under(module, "Object", rb_cObject);
    const char *methodsToRemove[] = {
        "allocate", "clone", "const_defined?", "const_get", "const_missing", "const_set", "constants",
        "clone", "display", "dup", "freeze", "frozen?", "id", "include?", "included_modules", "name",
        "new", "taint", "tainted?", "untaint"
    };
    remove_methods(CLASS_OF(__object_class), methodsToRemove, sizeof(methodsToRemove)/sizeof(const char *));
    remove_methods(__object_class, methodsToRemove, sizeof(methodsToRemove)/sizeof(const char *));

    rb_define_method(__object_class, "cmethods", object_class_methods, 0);
    rb_define_method(__object_class, "imethods", object_instance_methods, 0);
    rb_define_method(__object_class, "get_cmethod", object_get_class_method, 1);
    rb_define_method(__object_class, "get_imethod", object_get_instance_method, 1);
    rb_define_method(__object_class, "forward", object_forward, 2);
    rb_define_method(__object_class, "invoke", object_invoke, 2);
    rb_define_method(__object_class, "<=>", object_compare, 1);
    rb_define_method(__object_class, "==", object_equal, 1);
    rb_define_method(__object_class, "eql?", object_equal, 1);
    rb_define_method(__object_class, "hash", object_hash, 0);
    rb_define_method(__object_class, "to_s", object_to_s, 0);
    rb_define_method(__object_class, "to_f", object_to_f, 0);
    rb_define_method(__object_class, "to_i", object_to_i, 0);
    rb_define_method(__object_class, "inspect", object_inspect, 0);

    rb_define_singleton_method(__object_class, "link_classes", link_classes, 2);
    rb_define_singleton_method(__object_class, "add_ruby_subclass", add_ruby_subclass, 2);
    rb_define_singleton_method(__object_class, "claim_ruby_subclass", claim_ruby_subclass, 2);
    rb_define_singleton_method(__object_class, "add_objc_imethod_handler", add_objc_instance_method_handler, 2);
    rb_define_singleton_method(__object_class, "add_objc_cmethod_handler", add_objc_class_method_handler, 2);
    rb_define_singleton_method(__object_class, "object_count", object_count, 0);
    rb_define_singleton_method(__object_class, "each_object", object_each_object, -1);

    rb_define_class_variable(__object_class, "@@rbclass_for_occlass", rb_hash_new());
    rb_define_class_variable(__object_class, "@@occlass_for_rbclass", rb_hash_new());

    const char *x = "ObjectManager";
    __object_manager_class = rb_define_class_under(module, x, rb_cObject);
    rb_define_class_variable(__object_class, "@@manager", Data_Wrap_Struct(__object_manager_class, &object_mark_retained, 0, 0));
}
