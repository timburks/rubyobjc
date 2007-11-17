require File.dirname(__FILE__) + '/egg'

module RDoc
  module Page
    SITE = "http://www.rubyobjc.com"

    def self.header
      Markaby::Builder.new.xhtml_strict do
        div.banner! do
          h4 do
            self << "RubyObjC. "
            span.lighter_banner "A Ruby/Objective-C bridge."
          end
        end
        div.menu! do
          self << "\n"
          ul do
            self << "\n"
            menuitems = [
              ["home", SITE+"/"],
              ["about RubyObjC", SITE+"/about"],
              ["examples", SITE+"/examples"],
              ["documentation", SITE+"/doc/files/INTRODUCTION.html", :current],
              ["guides", SITE+"/guides"],
              ["history", SITE+"/history"],
              ["contact", SITE+"/contact"]
            ]
            menuitems.each {|pair|
              li do
                if pair.length > 2
                  a :href => pair[1], :class => "current" do
                    self << pair[0]
                  end
                else
                  a :href => pair[1] do
                    self << pair[0]
                  end
                end
              end
              self << "\n"
            }
          end
          self << "\n"
        end
      end.to_s
    end

    def self.footer
      Markaby::Builder.new.xhtml_strict do
        div.footer!.clear do
          p :style => "line-height:1.1em" do
            self << "&copy; Tim Burks, "
            a "Neon Design Technology, Inc.", :href => "http://www.neontology.com"
            br
            self << "Site design by "
            a "20pirates", :href => "http://20pirates.com"
            self << " | "
            a "RDoc", :href => "http://www.ruby-doc.org/stdlib/libdoc/rdoc/rdoc/index.html"
            self << " with "
            a "Allison", :href => "http://blog.evanweaver.com/articles/2006/06/02/allison"
          end
        end
        self << "\n"
        self << <<-END
        <div id="track">
        <script type="text/javascript" src="/rail_stat/tracker_js"></script>
        <img src="/rail_stat/track" width="1" height="1" alt="" style="position: absolute;" />
        <script src="http://www.google-analytics.com/urchin.js" type="text/javascript"></script>
        <script type="text/javascript">_uacct = "UA-239444-1";urchinTracker();</script>
        </div>
        END
      end.to_s
    end

    def self.image
      Markaby::Builder.new.xhtml_strict do
        img :src => "http://www.rubyobjc.com/images/bridge-construction.jpg", :style => "float:left; margin-right:10px; margin-bottom:10px"
      end.to_s
    end

    EGG.hatch(self)
  end
end
