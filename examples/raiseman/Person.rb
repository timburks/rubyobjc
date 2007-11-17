class Person < ObjC::NSObject
  property :personName, :expectedRaise

  imethod "init" do
    super
    @personName = "New Employee"
    @expectedRaise = 5.0
    self
  end

  imethod "setNilValueForKey:", "v@:@" do |key|
    ObjC.NSLog "setNilValueForKey_(#{key})"
    if key.isEqual?("expectedRaise")
      expectedRaise = 0.0
    else
      super(key)
    end
  end

  imethod "key", "@@:" do
    @personName
  end

  imethod "encodeWithCoder:", "@@:@" do |coder|
    coder.encodeObject_forKey_(personName, "personName")
    coder.encodeObject_forKey_(expectedRaise, "expectedRaise")
  end

  imethod "initWithCoder:", "@@:@" do |coder|
    init # it would be better to send this to the superclass, but this will work
    @personName = coder.decodeObjectForKey_("personName")
    @expectedRaise = coder.decodeObjectForKey_("expectedRaise")
    self
  end
end
