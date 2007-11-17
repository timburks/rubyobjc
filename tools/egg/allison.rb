require File.dirname(__FILE__) + '/egg'

module RDoc
  module Page
    def self.header
      Markaby::Builder.new.xhtml_strict do
        div.banner! do
          h4 do
            self << "Allison. "
            span.lighter_banner "Made with RDoc."
          end
        end
      end.to_s
    end

    def self.footer
      Markaby::Builder.new.xhtml_strict do
        div.footer!.clear do
          p :style => "line-height:1.1em" do
            self << "Made with "
            a "RDoc", :href => "http://www.ruby-doc.org/stdlib/libdoc/rdoc/rdoc/index.html"
            self << " and "
            a "Allison", :href => "http://blog.evanweaver.com/articles/2006/06/02/allison"
          end
        end
      end.to_s
    end

    def self.image
      ""
    end

    EGG.hatch(self)
  end
end
