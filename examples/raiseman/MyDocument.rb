ObjC.add_function(ObjC::Function.wrap("NSRunAlertPanel", "i", ["@", "@", "@", "@", "@"]))

class MyDocument < ObjC::NSDocument
  property :personController, :tableView, :employees

  imethod "init" do
    super
    @employees = ObjC::NSMutableArray.alloc.init
    ObjC::NSNotificationCenter.defaultCenter.addObserver_selector_name_object_(
    self, "handleColorChanged:", PreferenceController::RRMTableBgColorChanged, nil)
    self
  end

  imethod "handleColorChanged:" do |notification|
    # The notification object is of type PreferenceController
    # because of this line: notification_center.postNotification(notification)
    table_color = notification.userInfo.objectForKey_(PreferenceController::RRMTableBgColorKey)
    @tableView.setBackgroundColor_(table_color)
  end

  imethod "remove:", "v@:@" do |sender|
    selected = @personController.selectedObjects
    choice = ObjC.NSRunAlertPanel("Delete", "Do you want to delete #{selected.count} records?", "Delete", "Cancel", "Zero raise")
    if choice == ObjC::NSAlertDefaultReturn
      @personController.remove_(sender)
    elsif choice == -1  # ObjC::NSAlertOtherReturn is bridged incorrectly as an unsigned int
      @personController.selectedObjects.each do |p|
        p.setExpectedRaise_(0.0)
      end
    end
  end

  imethod "insertObject:inEmployeesAtIndex:", "v@:@i" do |person, index|
    undo_manager = self.undoManager
    undo_manager.prepareWithInvocationTarget_(self).removeObjectFromEmployeesAtIndex_(index)
    undo_manager.setActionName_("Insert Person") unless undo_manager.isUndoing != 0
    self.startObservingPerson(person)
    @employees.insertObject_atIndex_(person, index)
  end

  imethod "removeObjectFromEmployeesAtIndex:", "v@:i" do |index|
    person = @employees[index]
    undo_manager = self.undoManager
    undo_manager.prepareWithInvocationTarget_(self).insertObject_inEmployeesAtIndex_(person, index)
    undo_manager.setActionName_("Delete Person") unless undo_manager.isUndoing != 0
    self.stopObservingPerson(person)
    @employees.removeObjectAtIndex_(index)
  end

  imethod "changeKeyPath:ofObject:toValue:", "v@:@@@" do |keyPath, obj, newValue|
    obj.setValue_forKeyPath_(newValue, keyPath)
  end

  imethod "observeValueForKeyPath:ofObject:change:context:", "v@:@@@^v" do |keyPath, obj, change, context|
    undo_manager = self.undoManager
    oldValue = change.objectForKey_(ObjC::NSKeyValueChangeOldKey)
    undo_manager.prepareWithInvocationTarget_(self).changeKeyPath_ofObject_toValue_(keyPath, obj, oldValue)
    undo_manager.setActionName_("Edit")
  end

  imethod "windowNibName" do
    "MyDocument"
  end

  imethod "windowControllerDidLoadNib:" do |aController|
    super(aController)
    defaults = ObjC::NSUserDefaults.standardUserDefaults
    color_as_data = defaults.objectForKey_(PreferenceController::RRMTableBgColorKey)
    @tableView.setBackgroundColor_(ObjC::NSKeyedUnarchiver.unarchiveObjectWithData_(color_as_data))
  end

  imethod "dataRepresentationOfType:" do |aType|
    @personController.commitEditing
    ObjC::NSKeyedArchiver.archivedDataWithRootObject_(employees)
  end

  imethod "loadDataRepresentation:ofType:" do |data, aType|
    @employees = ObjC::NSKeyedUnarchiver.unarchiveObjectWithData_(data)
    true
  end
  
  def employees=(array)
    return if @employees == array
    # we need to stop observing old ones before assigning to array
    @employees.each {|p| stopObservingPerson(p)}
    # start observing the new data
    @employees = array
    @employees.each {|p| startObservingPerson(p)}
  end
  
  def startObservingPerson(person)
    person.addObserver_forKeyPath_options_context_(self, "personName", ObjC::NSKeyValueObservingOptionOld, nil)
    person.addObserver_forKeyPath_options_context_(self, "expectedRaise", ObjC::NSKeyValueObservingOptionOld, nil)
  end

  def stopObservingPerson(person)
    person.removeObserver_forKeyPath_(self, "personName")
    person.removeObserver_forKeyPath_(self, "expectedRaise")
  end
end
