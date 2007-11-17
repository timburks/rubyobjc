# Set the application search path
ObjC.set_path :LOCAL

# Activate optional components
ObjC.require :foundation, :appkit, :console

# Load all ruby files in the application's Resource directory
ObjC.load_internal_files(__FILE__)

# if the app is started at the command line, this will make it take focus
ObjC::NSApplication.sharedApplication.activateIgnoringOtherApps_(true)

# start the main event loop
ObjC.NSApplicationMain(0, nil)
