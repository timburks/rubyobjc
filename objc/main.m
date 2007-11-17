/* 
 * main.m
 *
 * main() for RubyObjC applications.
 *
 * Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
 * For more information about this file, visit http://www.rubyobjc.com.
 */

extern int RubyObjC_ApplicationMain(const char* rb_main_name, int argc, const char* argv[]);

/*
 * Here's a basic "main". Since it's so easy to load code dynamically, it's really all we need.
 */
int main(int argc, const char *argv[])
{
    return RubyObjC_ApplicationMain("main.rb", argc, argv);
}
