# Set the application search path
ObjC.set_path :LOCAL

# Activate any optional components
ObjC.require :Foundation  
ObjC.require :AppKit
ObjC.require :console
ObjC.require :menu

# Load all ruby files in the application's Resource directory
ObjC.load_internal_files(__FILE__)

# Load any ruby files in same directory as the application
# optional -- use for development only!
#ObjC.load_external_files

# The application delegate configures the application
# after all basic services have been started
class ApplicationDelegate < ObjC::NSObject
  imethod "applicationDidFinishLaunching:" do |sender|
    make_menu "RubyObjC Demo"
    console
  end
end

# keep a reference to the delegate to keep it safe
# from premature garbage-collection
$delegate = ApplicationDelegate.alloc.init
ObjC::NSApplication.sharedApplication.setDelegate_($delegate)

# if the app is started at the command line,
# we need this to make it take focus
ObjC::NSApplication.sharedApplication.activateIgnoringOtherApps_(true)

# start the main event loop
ObjC.NSApplicationMain(0, nil)
