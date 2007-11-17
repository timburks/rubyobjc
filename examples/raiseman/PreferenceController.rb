class PreferenceController < ObjC::NSWindowController
  RRMTableBgColorKey     = "Table Background Color"
  RRMEmptyDocKey         = "Empty Document Flag"
  RRMTableBgColorChanged = "Table Background Color Changed"

  property :colorWell, :checkBox

  imethod "init" do
    initWithWindowNibName_("Preferences")
  end

  imethod "windowDidLoad" do
    @colorWell.setColor_(self.tableBackgroundColor)
    @checkBox.setState_(self.emptyDoc?)
  end

  imethod "changeBackgroundColor:" do |sender|
    color = sender.color
    defaults = ObjC::NSUserDefaults.standardUserDefaults
    defaults.setObject_forKey_(ObjC::NSKeyedArchiver.archivedDataWithRootObject_(color), RRMTableBgColorKey)
    color_info = ObjC::NSDictionary.dictionaryWithObject_forKey_(color, RRMTableBgColorKey)
    notification = ObjC::NSNotification.notificationWithName_object_userInfo_(RRMTableBgColorChanged, self, color_info)
    ObjC::NSNotificationCenter.defaultCenter.postNotification_(notification)
  end

  imethod "changeNewEmptyDoc:" do |sender|
    ObjC::NSUserDefaults.standardUserDefaults.setBool_forKey_(sender.state, RRMEmptyDocKey)
  end

  imethod "tableBackgroundColor" do
    defaults = ObjC::NSUserDefaults.standardUserDefaults
    data = defaults.objectForKey_(RRMTableBgColorKey)
    data ? ObjC::NSKeyedUnarchiver.unarchiveObjectWithData_(data) : ObjC::NSColor.grayColor
  end

  def emptyDoc?
    ObjC::NSUserDefaults.standardUserDefaults.boolForKey_(RRMEmptyDocKey)
  end

  imethod "resetToDefaults:" do |sender|
    defaults = ObjC::NSUserDefaults.standardUserDefaults
    keys = defaults.dictionaryRepresentation.allKeys
    keys.each {|key| defaults.removeObjectForKey_(key)}
    reloadUserDefaults
  end

  def reloadUserDefaults
    defaults = ObjC::NSUserDefaults.standardUserDefaults
    @colorWell.setColor_(ObjC::NSKeyedUnarchiver.unarchiveObjectWithData_(defaults.objectForKey_(RRMTableBgColorKey)))
    @checkBox.setState_(defaults.objectForKey_(RRMEmptyDocKey).to_i)
    color_info = ObjC::NSDictionary.dictionaryWithObject_forKey_(@colorWell.color, RRMTableBgColorKey)
    ObjC::NSNotificationCenter.defaultCenter.postNotificationName_object_userInfo_(RRMTableBgColorChanged, self, color_info)
  end
end
