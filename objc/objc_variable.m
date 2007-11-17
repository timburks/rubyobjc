/* 
 * objc_variable.m
 *
 * Defines a Ruby wrapper that allows Objective-C instance variables to be manipulated from Ruby.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

/* 
 * Document-class: ObjC::Variable
 *
 * ObjC::Variable wraps Objective-C instance variables for manipulation from Ruby.
 *
 * The methods of this class allow the names, type encodings, and other properties of
 * Objective-C instance variables to be accessed from Ruby.
 * ObjC::Variable objects are returned by the ivars methods of ObjC::Class and ObjC::Object.
 */
#import "rubyobjc.h"

static VALUE __variable_class;

//////////////////////////////////////////////////////////////////

void variable_free(void *p)
{
    free(p);
}

VALUE variable_alloc(VALUE klass)
{
    ObjC_Variable *variable = (ObjC_Variable *) malloc (sizeof (ObjC_Variable));
    variable->v = 0;
    return Data_Wrap_Struct(klass, 0, variable_free, variable);
}

VALUE variable_create(Ivar v)
{
    ObjC_Variable *variable = (ObjC_Variable *) malloc (sizeof (ObjC_Variable));
    variable->v = v;
    return Data_Wrap_Struct(__variable_class, 0, variable_free, variable);
}

/*
 * Get the name of the corresponding Objective-C instance variable.
 */
VALUE variable_name(VALUE self)
{
    ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;
    return v ? rb_str_new2(v->ivar_name) : Qnil;
}

/*
 * Get the type encoding of the corresponding Objective-C instance variable.
 */
VALUE variable_type_encoding(VALUE self)
{
    ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;
    return v ? rb_str_new2(v->ivar_type) : Qnil;
}

/* 
 * Get the offset of the corresponding Objective-C instance variable.
 */
VALUE variable_offset(VALUE self)
{
    ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;
    return v ? INT2NUM(v->ivar_offset) : Qnil;
}

VALUE variable_get(VALUE self, VALUE object)
{
	ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;

    ObjC_Object *object_struct;
    Data_Get_Struct(object, ObjC_Object, object_struct);
    id o = object_struct->o;
	void *location = (void *)&(((char *)o)[v->ivar_offset]);
	VALUE result = get_ruby_value_from_objc_value(location, v->ivar_type, 0);
	return result;
}

VALUE variable_set(VALUE self, VALUE object, VALUE value)
{
	ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;

    ObjC_Object *object_struct;
    Data_Get_Struct(object, ObjC_Object, object_struct);
    id o = object_struct->o;
	void *location = (void *)&(((char *)o)[v->ivar_offset]);
	set_objc_value_from_ruby_value(location, value, v->ivar_type);
	return Qnil;
}

/* 
 * Compare the variable with another variable <i>p1</i>.
 */
VALUE variable_compare(VALUE self, VALUE other)
{
    ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    ObjC_Variable *other_variable;
    Data_Get_Struct(other, ObjC_Variable, other_variable);
    int r = strcmp(variable->v->ivar_name, other_variable->v->ivar_name);
    return INT2NUM(r);
}

/* 
 * Test variable for equality with another variable <i>p1</i>.
 */
VALUE variable_equal(VALUE self, VALUE other)
{
    if (TYPE(other) != T_DATA) return Qfalse;
    ObjC_Variable *variable, *other_variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Data_Get_Struct(other, ObjC_Variable, other_variable);
    return (variable->v == other_variable->v) ? Qtrue : Qfalse;
}

/*
 * Get a hash value for a variable.
 */
VALUE variable_hash(VALUE self)
{
    ObjC_Variable *variable;
    Data_Get_Struct(self, ObjC_Variable, variable);
    Ivar v = variable->v;
    return INT2FIX((int) v);
}

//
// ObjC instance variables are mapped to instances of ObjC::Variable
//
void Init_ObjC_Variable(VALUE module)
{
                                                  // needed by RDoc
    if (!module) module = rb_define_module("ObjC");
    __variable_class = rb_define_class_under(module, "Variable", rb_cObject);
    rb_define_alloc_func(__variable_class, variable_alloc);
    rb_define_method(__variable_class, "name", variable_name, 0);
    rb_define_method(__variable_class, "type_encoding", variable_type_encoding, 0);
    rb_define_method(__variable_class, "offset", variable_offset, 0);
    rb_define_method(__variable_class, "_get", variable_get, 1);
	rb_define_method(__variable_class, "_set", variable_set, 2);
    rb_define_method(__variable_class, "to_s", variable_name, 0);
    rb_define_method(__variable_class, "<=>", variable_compare, 1);
    rb_define_method(__variable_class, "==", variable_equal, 1);
    rb_define_method(__variable_class, "eql?", variable_equal, 1);
    rb_define_method(__variable_class, "hash", variable_hash, 0);
}
