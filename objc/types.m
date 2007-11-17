/* 
 * types.m
 *
 * Type conversion helpers for bridging between Ruby and Objective-C.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */
#include "rubyobjc.h"

/* 
 * types:
 * c char
 * i int
 * s short
 * l long
 * q long long
 * C unsigned char
 * I unsigned int
 * S unsigned short
 * L unsigned long
 * Q unsigned long long
 * f float
 * d double
 * B bool (c++)
 * v void
 * * char *
 * @ id
 * # Class
 * : SEL
 * ? unknown
 * b4             bit field of 4 bits
 * ^type          pointer to type
 * [type]         array
 * {name=type...} structure
 * (name=type...) union
 *
 * modifiers:
 * r const
 * n in
 * N inout
 * o out
 * O bycopy
 * R byref
 * V oneway
 */

#define NSRECT_SIGNATURE "{_NSRect={_NSPoint=ff}{_NSSize=ff}}"
#define CGRECT_SIGNATURE "{CGRect={CGPoint=ff}{CGSize=ff}}"
#define NSRANGE_SIGNATURE "{_NSRange=II}"
#define NSPOINT_SIGNATURE "{_NSPoint=ff}"
#define NSSIZE_SIGNATURE "{_NSSize=ff}"

// private ffi types
static int initialized_ffi_types = false;
static ffi_type ffi_type_nspoint;
static ffi_type ffi_type_nssize;
static ffi_type ffi_type_nsrect;
static ffi_type ffi_type_nsrange;

void initialize_ffi_types(void)
{
    if (initialized_ffi_types) return;
    initialized_ffi_types = true;

    // It would be better to do this automatically by parsing the ObjC type signatures
	ffi_type_nspoint.size = 0; // sizeof(NSPoint);
    ffi_type_nspoint.alignment = 0;
    ffi_type_nspoint.type = FFI_TYPE_STRUCT;
    ffi_type_nspoint.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_nspoint.elements[0] = &ffi_type_float;
    ffi_type_nspoint.elements[1] = &ffi_type_float;
    ffi_type_nspoint.elements[2] = NULL;

	ffi_type_nssize.size = 0; // sizeof(NSSize);
    ffi_type_nssize.alignment = 0;
    ffi_type_nssize.type = FFI_TYPE_STRUCT;
    ffi_type_nssize.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_nssize.elements[0] = &ffi_type_float;
    ffi_type_nssize.elements[1] = &ffi_type_float;
    ffi_type_nssize.elements[2] = NULL;

	ffi_type_nsrect.size = 0; // sizeof(NSRect);
    ffi_type_nsrect.alignment = 0;
    ffi_type_nsrect.type = FFI_TYPE_STRUCT;
    ffi_type_nsrect.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_nsrect.elements[0] = &ffi_type_nspoint;
    ffi_type_nsrect.elements[1] = &ffi_type_nssize;
    ffi_type_nsrect.elements[2] = NULL;

	ffi_type_nsrange.size = 0; // sizeof(NSRange);
    ffi_type_nsrange.alignment = 0;
    ffi_type_nsrange.type = FFI_TYPE_STRUCT;
    ffi_type_nsrange.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_nsrange.elements[0] = &ffi_type_uint;
    ffi_type_nsrange.elements[1] = &ffi_type_uint;
    ffi_type_nsrange.elements[2] = NULL;
}

char get_typeChar_from_typeString(const char *typeString)
{
    int i = 0;
    char typeChar = typeString[i];
    while ((typeChar == 'r') || (typeChar == 'R') ||
        (typeChar == 'n') || (typeChar == 'N') ||
        (typeChar == 'o') || (typeChar == 'O') ||
        (typeChar == 'V')
    ) {
        if (typeChar != 'r')                      // don't worry about const
            NSLog(@"ignoring qualifier %c in %s", typeChar, typeString);
        typeChar = typeString[++i];
    }
    return typeChar;
}

ffi_type *ffi_type_for_objc_type(const char *typeString)
{
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case 'f': return &ffi_type_float;
        case 'd': return &ffi_type_double;
        case 'v': return &ffi_type_void;
        case 'B': return &ffi_type_uint32;
        case 'C': return &ffi_type_uint32;
        case 'c': return &ffi_type_sint32;
        case 'S': return &ffi_type_uint32;
        case 's': return &ffi_type_sint32;
        case 'I': return &ffi_type_uint32;
        case 'i': return &ffi_type_sint32;
        case 'L': return &ffi_type_uint32;
        case 'l': return &ffi_type_sint32;
        case 'Q': return &ffi_type_uint64;
        case 'q': return &ffi_type_sint64;
        case '@': return &ffi_type_pointer;
        case '#': return &ffi_type_pointer;
        case '*': return &ffi_type_pointer;
        case ':': return &ffi_type_pointer;
        case '^': return &ffi_type_pointer;
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE) || !strcmp(typeString, CGRECT_SIGNATURE)) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nsrect;
            }
            else if (!strcmp(typeString, NSRANGE_SIGNATURE)) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nsrange;
            }
            else if (!strcmp(typeString, NSPOINT_SIGNATURE)) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nspoint;
            }
            else if (!strcmp(typeString, NSSIZE_SIGNATURE)) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nssize;
            }
            else {
                NSLog(@"unknown type identifier %s", typeString);
                return &ffi_type_void;
            }
        }
        default:
        {
            NSLog(@"unknown type identifier %s", typeString);
            return &ffi_type_void;                // urfkd
        }
    }
}

void *value_buffer_for_objc_type(const char *typeString)
{
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case 'f': return malloc(sizeof(float));
        case 'd': return malloc(sizeof(double));
        case 'v': return malloc(sizeof(void *));
        case 'B': return malloc(sizeof(unsigned int));
        case 'C': return malloc(sizeof(unsigned int));
        case 'c': return malloc(sizeof(int));
        case 'S': return malloc(sizeof(unsigned int));
        case 's': return malloc(sizeof(int));
        case 'I': return malloc(sizeof(unsigned int));
        case 'i': return malloc(sizeof(int));
        case 'L': return malloc(sizeof(unsigned long));
        case 'l': return malloc(sizeof(long));
        case 'Q': return malloc(sizeof(unsigned long long));
        case 'q': return malloc(sizeof(long long));
        case '@': return malloc(sizeof(void *));
        case '#': return malloc(sizeof(void *));
        case '*': return malloc(sizeof(void *));
        case ':': return malloc(sizeof(void *));
        case '^': return malloc(sizeof(void *));
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE) || !strcmp(typeString, CGRECT_SIGNATURE)) {
                void *p = malloc(sizeof(NSRect));
                //NSLog(@"allocating NSRect storage at %x", (int) p);
                return p;
            }
            else if (!strcmp(typeString, NSRANGE_SIGNATURE)) {
                return malloc(sizeof(NSRange));
            }
            else if (!strcmp(typeString, NSPOINT_SIGNATURE)) {
                return malloc(sizeof(NSPoint));
            }
            else if (!strcmp(typeString, NSSIZE_SIGNATURE)) {
                return malloc(sizeof(NSSize));
            }
            else {
                NSLog(@"unknown type identifier %s", typeString);
                return malloc(sizeof (void *));
            }
        }
        default:
        {
            NSLog(@"unknown type identifier %s", typeString);
            return malloc(sizeof (void *));
        }
    }
}

void set_objc_value_from_ruby_value(void *objc_value, VALUE ruby_value, const char *typeString)
{
    OBJC_LOG(@"VALUE => %s", typeString);
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case '@':
            switch(TYPE(ruby_value)) {
                case T_NIL:
                    *((id *) objc_value) = 0;
                    return;
                case T_STRING:
                    *((id *) objc_value) = [NSString stringWithCString:StringValuePtr(ruby_value)];
                    // this doesn't work because NSStrings can't contain internal NULLs.
                    // [[NSString alloc] initWithBytes:RSTRING(ruby_value)->ptr length:RSTRING(ruby_value)->len encoding:NSUTF8StringEncoding];
                    return;
                case T_SYMBOL:
                {
                    VALUE stringValue = rb_funcall2(ruby_value, rb_intern("to_s"), 0, NULL);
                    *((id *) objc_value) = [NSString stringWithCString:StringValuePtr(stringValue)];
                    return;
                }
                case T_FIXNUM:
                case T_BIGNUM:
                    *((id *) objc_value) = [NSNumber numberWithInt:NUM2INT(ruby_value)];
                    return;
                case T_TRUE:
                    *((id *) objc_value) = [NSNumber numberWithInt:0x01];
                    return;
                case T_FALSE:
                    *((id *) objc_value) = [NSNumber numberWithInt:0x00];
                    return;
                case T_FLOAT:
                    *((id *) objc_value) = [NSNumber numberWithDouble:NUM2DBL(ruby_value)];
                    return;
                case T_DATA:
                {
                    ObjC_Object *object;
                    Data_Get_Struct(ruby_value, ObjC_Object, object);
                    *((id *) objc_value) = object->o;
                    return;
                }
                case T_ARRAY:
                {
                    VALUE array = rb_funcall2(ruby_value, rb_intern("to_nsarray"), 0, NULL);
                    ObjC_Object *object;
                    Data_Get_Struct(array, ObjC_Object, object);
                    *((id *) objc_value) = object->o;
                    return;
                }
                case T_HASH:
                {
                    VALUE dictionary = rb_funcall2(ruby_value, rb_intern("to_nsdictionary"), 0, NULL);
                    ObjC_Object *object;
                    Data_Get_Struct(dictionary, ObjC_Object, object);
                    *((id *) objc_value) = object->o;
                    return;
                }
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((id *) objc_value) = [NSString stringWithCString:"unknown"];
                    return;
            }
        case '#':
        {
            switch(TYPE(ruby_value)) {
                case T_CLASS:
                    *((Class *)objc_value) = get_objcclass_from_rubyclass(ruby_value);
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to CLASS", TYPE(ruby_value));
                    *((id *) objc_value) = [NSString stringWithCString:"unknown"];
                    return;
            }
        }
        case '*':
            if (TYPE(ruby_value) == T_STRING) {
                *((char **) objc_value) = StringValuePtr(ruby_value);
            }
            else if (TYPE(ruby_value) == T_SYMBOL) {
                VALUE stringValue = rb_funcall2(ruby_value, rb_intern("to_s"), 0, NULL);
                *((char **) objc_value) = StringValuePtr(stringValue);
                return;
            }
            else {
                NSLog(@"can't convert ruby type %x to char *", TYPE(ruby_value));
                *((char **) objc_value) = "unknown";
                return;
            }
            return;
        case 'b':                                 // send bool as int
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((int *) objc_value) = (int) NUM2INT(ruby_value);
                    return;
                case T_TRUE:
                    *((int *) objc_value) = (int) 0x01;
                    return;
                case T_FALSE:
                    *((int *) objc_value) = (int) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }
        case 'B':                                 // send bool as int
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned int *) objc_value) = (unsigned int) NUM2UINT(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned int *) objc_value) = (unsigned int) 0x01;
                    return;
                case T_FALSE:
                    *((unsigned int *) objc_value) = (unsigned int) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }

        case 'c':                                 // send char as int
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((int *) objc_value) = (int) NUM2INT(ruby_value);
                    return;
                case T_TRUE:
                    *((int *) objc_value) = (int) 0x01;
                    return;
                case T_FALSE:
                    *((int *) objc_value) = (int) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }
        case 'C':                                 // send char as int
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned int *) objc_value) = (unsigned int) NUM2UINT(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned int *) objc_value) = (unsigned int) 0x01;
                    return;
                case T_FALSE:
                    *((unsigned int *) objc_value) = (unsigned int) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }
        case 's':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((int *) objc_value) = NUM2INT(ruby_value);
                    return;
                case T_TRUE:
                    *((int *) objc_value) = 0x01;
                    return;
                case T_FALSE:
                    *((int *) objc_value) = 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }
        case 'S':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned int *) objc_value) = NUM2UINT(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned int *) objc_value) = 0x01;
                    return;
                case T_FALSE:
                    *((unsigned int *) objc_value) = 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((unsigned int *) objc_value) = -1;
                    return;
            }
        case 'i':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((int *) objc_value) = NUM2INT(ruby_value);
                    return;
                case T_TRUE:
                    *((int *) objc_value) = 0x01;
                    return;
                case T_FALSE:
                    *((int *) objc_value) = 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((int *) objc_value) = -1;
                    return;
            }
        case 'I':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned int *) objc_value) = NUM2UINT(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned int *) objc_value) = 0x01;
                    return;
                case T_FALSE:
                    *((unsigned int *) objc_value) = 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((unsigned int *) objc_value) = -1;
                    return;
            }
        case 'l':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((long *) objc_value) = (long) NUM2LONG(ruby_value);
                    return;
                case T_TRUE:
                    *((long *) objc_value) = (long) 0x01;
                    return;
                case T_FALSE:
                    *((long *) objc_value) = (long) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((long *) objc_value) = -1;
                    return;
            }
        case 'L':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned long *) objc_value) =  NUM2ULONG(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned long *) objc_value) = 0x01;
                    return;
                case T_FALSE:
                    *((unsigned long *) objc_value) = 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((unsigned long *) objc_value) = -1;
                    return;
            }
        case 'q':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((long long *) objc_value) = (long long) NUM2LONG(ruby_value);
                    return;
                case T_TRUE:
                    *((long long *) objc_value) = (long long) 0x01;
                    return;
                case T_FALSE:
                    *((long long *) objc_value) = (long long) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((long long *) objc_value) = (long long) -1;
                    return;
            }
        case 'Q':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((unsigned long long *) objc_value) = (unsigned long long) NUM2ULONG(ruby_value);
                    return;
                case T_TRUE:
                    *((unsigned long long *) objc_value) = (unsigned long long) 0x01;
                    return;
                case T_FALSE:
                    *((unsigned long long *) objc_value) = (unsigned long long) 0x00;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((unsigned long long *) objc_value) = (unsigned long long) -1;
                    return;
            }
        case 'd':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((double *) objc_value) = NUM2DBL(ruby_value);
                    return;
                case T_TRUE:
                    *((double *) objc_value) = 1.0;
                    return;
                case T_FALSE:
                    *((double *) objc_value) = 0.0;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((double *) objc_value) = -1;
                    return;
            }
        case 'f':
            switch (TYPE(ruby_value)) {
                case T_FIXNUM:
                case T_BIGNUM:
                case T_FLOAT:
                    *((float *) objc_value) = (float) NUM2DBL(ruby_value);
                    return;
                case T_TRUE:
                    *((float *) objc_value) = 1.0;
                    return;
                case T_FALSE:
                    *((float *) objc_value) = 0.0;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to %c", TYPE(ruby_value), typeChar);
                    *((float *) objc_value) = -1;
                    return;
            }
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE) || !strcmp(typeString, CGRECT_SIGNATURE)) {
                NSRect *rect = (NSRect *) objc_value;
                rect->origin.x = (float) NUM2DBL(rb_ary_entry(ruby_value, 0));
                rect->origin.y = (float) NUM2DBL(rb_ary_entry(ruby_value, 1));
                rect->size.width = (float) NUM2DBL(rb_ary_entry(ruby_value, 2));
                rect->size.height = (float) NUM2DBL(rb_ary_entry(ruby_value, 3));
                //NSLog(@"ruby->rect: %x %f %f %f %f", (void *) rect, rect->origin.x, rect->origin.y, rect->size.width, rect->size.height);
                return;
            }
            else if (!strcmp(typeString, NSRANGE_SIGNATURE)) {
                NSRange *range = (NSRange *) objc_value;
                range->location = (unsigned int) NUM2INT(rb_ary_entry(ruby_value, 0));
                range->length = (unsigned int) NUM2INT(rb_ary_entry(ruby_value, 1));
                return;
            }
            else if (!strcmp(typeString, NSSIZE_SIGNATURE)) {
                NSSize *size = (NSSize *) objc_value;
                size->width = (float) NUM2DBL(rb_ary_entry(ruby_value, 0));
                size->height = (float) NUM2DBL(rb_ary_entry(ruby_value, 1));
                return;
            }
            else if (!strcmp(typeString, NSPOINT_SIGNATURE)) {
                NSPoint *point = (NSPoint *) objc_value;
                point->x = (float) NUM2DBL(rb_ary_entry(ruby_value, 0));
                point->y = (float) NUM2DBL(rb_ary_entry(ruby_value, 1));
                return;
            }
            else {
                NSLog(@"UNIMPLEMENTED: can't wrap structure of type %s", typeString);
                return;
            }
        }
        case ':':
        {
            // selectors must be strings (symbols could be ok too...)
            switch(TYPE(ruby_value)) {
                case T_STRING:
                    *((SEL *) objc_value) = sel_registerName(StringValuePtr(ruby_value));
                    return;
                case T_NIL:
                    *((SEL *) objc_value) = 0;
                    return;
                default:
                    NSLog(@"can't convert ruby type %x to a selector", TYPE(ruby_value));
                    return;
            }
        }
        case '^':
        {
            // pointers require some work.. and cleanup. This LEAKS.
            if (!strcmp(typeString, "^*")) {
                // array of strings
                if (TYPE(ruby_value) == T_ARRAY) {
                    int array_size = FIX2INT(rb_funcall2(ruby_value, rb_intern("size"), 0, NULL));
                    char **array = (char **) malloc (array_size * sizeof(char *));
                    int i;
                    for (i = 0; i < array_size; i++) {
                        VALUE temp = rb_ary_entry(ruby_value, i);
                        array[i] = strdup(StringValuePtr(temp));
                    }
                    *((char ***) objc_value) = array;
                }
                else if (ruby_value == Qnil) {
                    *((char ***) objc_value) = NULL;
                }
                else {
                    NSLog(@"can't convert value of type %d to a pointer to strings", TYPE(ruby_value));
                    *((char ***) objc_value) = NULL;
                }
            }
            else {
                switch(TYPE(ruby_value)) {
                    case T_STRING:
                        *((char **) objc_value) = RSTRING(ruby_value)->ptr;
                        return;
                    case T_NIL:
                        *((char **) objc_value) = 0;
                        return;
                    default:
                        NSLog(@"can't convert value of type %d to a pointer of type %s", TYPE(ruby_value), typeString);
                        return;
                }
            }
            return;
        }
        case 'v':
            return;                               // we don't have to do anything for voids
        default:
            NSLog(@"can't wrap argument of type %s", typeString);
    }

}

VALUE get_ruby_value_from_objc_value(void *objc_value, const char *typeString, SEL selector)
{
    OBJC_LOG(@"%s => VALUE", typeString);
    char typeChar = get_typeChar_from_typeString(typeString);
    switch(typeChar) {
        case 'v': return Qnil;
        case 'B': return (*((unsigned int *)objc_value) == 0) ? Qfalse : Qtrue;
        case 'c': return INT2NUM(*((int *)objc_value));
        case 'C': return UINT2NUM(*((unsigned int *)objc_value));
        case 's': return INT2NUM((int) *((int *)objc_value));
        case 'S': return UINT2NUM((unsigned int) *((unsigned int *)objc_value));
        case 'i': return INT2NUM(*((int *)objc_value));
        case 'I': return UINT2NUM(*((unsigned int *)objc_value));
        case 'l': return LONG2NUM(*((long *)objc_value));
        case 'L': return ULONG2NUM(*((unsigned long *)objc_value));
        case 'q': return LONG2NUM(*((long long *)objc_value));
        case 'Q': return ULONG2NUM(*((unsigned long long *)objc_value));
        case 'f': return rb_float_new((double) *((float *)objc_value));
        case 'd': return rb_float_new(*((double *)objc_value));
        case '@':
        {
            id o = *((id *)objc_value);
            VALUE result = o ? object_create(o, selector) : Qnil;
            return result;
        }
        case '#':
        {
            id o = *((id *)objc_value);
            if (!o) return Qnil;
            VALUE result_class = lookup_rbclass_for_occlass(o);
            if (result_class == Qnil)
                result_class = object_wrap_class(class_create(o));
            return result_class;
        }
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE) || !strcmp(typeString, CGRECT_SIGNATURE)) {
                NSRect *rect = (NSRect *)objc_value;
                VALUE array = rb_ary_new();
                //NSLog(@"rect->ruby: %x %f %f %f %f", (void *) rect, rect->origin.x, rect->origin.y, rect->size.width, rect->size.height);
                rb_ary_push(array, rb_float_new((double)rect->origin.x));
                rb_ary_push(array, rb_float_new((double)rect->origin.y));
                rb_ary_push(array, rb_float_new((double)rect->size.width));
                rb_ary_push(array, rb_float_new((double)rect->size.height));
                return array;
            }
            else if (!strcmp(typeString, NSRANGE_SIGNATURE)) {
                NSRange *range = (NSRange *)objc_value;
                VALUE array = rb_ary_new();
                rb_ary_push(array, INT2FIX(range->location));
                rb_ary_push(array, INT2FIX(range->length));
                return array;
            }
            else if (!strcmp(typeString, NSPOINT_SIGNATURE)) {
                NSPoint *point = (NSPoint *)objc_value;
                VALUE array = rb_ary_new();
                rb_ary_push(array, rb_float_new(point->x));
                rb_ary_push(array, rb_float_new(point->y));
                return array;
            }
            else if (!strcmp(typeString, NSSIZE_SIGNATURE)) {
                NSSize *size = (NSSize *)objc_value;
                VALUE array = rb_ary_new();
                rb_ary_push(array, rb_float_new(size->width));
                rb_ary_push(array, rb_float_new(size->height));
                return array;
            }
            else {
                NSLog(@"UNIMPLEMENTED: can't wrap structure of type %s", typeString);
            }
        }
        case '^':
        {
            // pointers require some work.. and cleanup. This LEAKS.
            if (!strcmp(typeString, "^v")) {
                // this is a bit extreme...
                NSLog(@"WARNING: assuming Qnil for void *.. without checking");
                return Qnil;
            }
            else {
                NSLog(@"UNIMPLEMENTED: can't wrap pointer of type %s", typeString);
            }
            return Qnil;
        }
        case '*':
        {
            return rb_str_new2(*((char **)objc_value));
        }
        case ':':
        {
            SEL sel = *((SEL *)objc_value);
            return rb_str_new2(sel_getName(sel));
        }
        default:
            NSLog (@"UNIMPLEMENTED: unable to wrap object of type %s", typeString);
            return Qnil;
    }
}
