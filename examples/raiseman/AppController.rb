class AppController < ObjC::NSObject
  property :preferenceController, :aboutWindow

  imethod "applicationDidFinishLaunching:" do |sender|
    #uncomment the following line to get an interactive console on startup
    #console
  end

  cmethod "initialize", "v@:" do
    ObjC::NSLog "initializing for #{self}"
    default_values = ObjC::NSMutableDictionary.dictionary
    color_as_data = ObjC::NSKeyedArchiver.archivedDataWithRootObject_(ObjC::NSColor.yellowColor)
    default_values[PreferenceController::RRMTableBgColorKey] = color_as_data
    default_values[PreferenceController::RRMEmptyDocKey] = true
    ObjC::NSUserDefaults.standardUserDefaults.registerDefaults_(default_values)
  end

  imethod "showPreferencePanel:" do |sender|
    @preferenceController = PreferenceController.alloc.init unless @preferenceController
    @preferenceController.showWindow_(self)
  end

  imethod "showAbout:" do |sender|
    ObjC::NSBundle.loadNibNamed_owner_("About", self)
    @aboutWindow.makeKeyAndOrderFront_(self)
  end

  imethod "applicationShouldOpenUntitledFile:", "i@:@" do |sender|
    ObjC::NSUserDefaults.standardUserDefaults.boolForKey_(PreferenceController::RRMEmptyDocKey)
  end
end
