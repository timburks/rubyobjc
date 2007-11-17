# Evan's Generic Girlfriend RDoc template
#  a shameless bastard child of Allison.

# Allison is Copyright 2006 Cloudburst LLC
# non-malicious wounds performed in 2007 Neon Design Technology, Inc.
# provided here with no claims and no warranty.

require 'rubygems'
require 'markaby'

module EGG
  def self.hatch(page)
    [:FONTS, :METHOD_LIST, :SRC_PAGE, :FILE_PAGE, :CLASS_PAGE].each do |c|
      page.const_set c, ""
    end

    page.const_set :FR_INDEX_BODY, "!INCLUDE!" # who knows

    page.const_set :JAVASCRIPT, File.open(File.dirname(__FILE__) + "/allison.js").read
    page.const_set :STYLE, File.open(File.dirname(__FILE__)+ "/stark.css").read

    page.const_set :INDEX, Markaby::Builder.new.xhtml_strict {
      head do
        title '%title%'
        link :rel => 'stylesheet', :type => 'text/css', :href => 'rdoc-style.css', :media => 'screen'
        tag! :meta, 'http-equiv' => 'refresh', 'content' => '0;url=%initial_page%'
      end
      body do
        div.container! do
          div.header! do
            span.title! do
              p {'&nbsp;'}
              h1 {'&nbsp;'}
            end
          end
          div.clear {}
          div.redirect! do
            a :href => '%initial_page%' do
            end
          end
        end
      end
    }.to_s

    [:FILE_INDEX, :METHOD_INDEX, :CLASS_INDEX].each do |c|
      page.const_set c, Markaby::Builder.new.capture {
        a :href => '%href%' do
          self << '%name%'
          br
        end
      }.loop('entries')
    end

    page.const_set :BODY, Markaby::Builder.new.xhtml_strict {
      head do
        title "%title%"
        link :rel => 'stylesheet', :type => 'text/css', :href => "http://www.rubyobjc.com/stylesheets/stark.css"
        script :type => 'text/javascript' do
          page::JAVASCRIPT
        end
      end
      body do
        self << "\n"
        div.container! do

          self << page.header
          self << "\n"
          div.sidebar! do
            self << (div.navigation.top.child_of! do
              # death to you, horrible templater >:(
              h3 "Child of"
              self << "<span>\n#{"<a href='%par_url%'>".if_exists}%parent%#{"</a>".if_exists('par_url')}</span>"
            end).if_exists('parent')

            self << (div.navigation.top.defined_in! do
              h3('Defined in')
              self << a('%full_path%', :href => '%full_path_url%').if_exists.loop('infiles')
            end).if_exists('infiles')

            ['includes', 'requires', 'methods'].each { |item|
              self << (div.navigation.top(:id => item) do
                self << h3(item.capitalize)
                self << "<span>\n#{"<a href='%aref%'>".if_exists}%name%#{br}#{"</a>".if_exists('aref')}</span>".if_exists('name').loop(item)
              end).if_exists(item)
            }

            div.spacer! ''

            # for the javascript ajaxy includes
            ['class', 'file', 'method'].each { |item|
              div.navigation.index :id => "#{item}_wrapper" do
                div.list_header do
                  h3 'All ' + (item == 'class' ? 'classes' : item + 's')
                end
                div.list_header_link do
                  a((item == 'method' ? 'Show...' : 'Hide...'),
                  :id => "#{item}_link", :href => "#",
                  :onclick=> "toggle('#{item}'); toggleText('#{item}_link'); return false;")
                end
                div.clear {}
                div(:id => item) {
                  form do
                    label(:for => "filter_#{item}") { 'Filter:' + '&nbsp;' * 2 }
                    input '', :type => 'text', :id => "filter_#{item}",
                    :onKeyUp => "return filterList('#{item}', this.value, event);",
                    :onKeyPress => "return disableSubmit(event);"
                  end
                }
              end
            }
          end

          div.content! {
            self << page.image
            self << capture do
              h1.item_name! '%title%'
            end.if_exists('title')
            self << capture do
              self << '%description%'
            end.if_exists('description')

            br :style => "clear:left"
            self << capture do
              self << h1 {a '%sectitle%', :name => '%secsequence%'}.if_exists('sectitle')
              self << p {'%seccomment%'}.if_exists

              self << capture do
                h1 "Child modules and classes"
                p.classlist '%classlist%'
              end.if_exists('classlist')

              ['constants', 'aliases', 'attributes'].each do |item|
                self << capture do
                  h1(item.capitalize)
                  p do
                    table do
                      fields = %w[name value old_name new_name rw desc a_desc]
                      self << tr do
                        # header row
                        th.first " "
                        if item == 'constants'
                          th 'Name'
                          th 'Value'
                        elsif item == 'aliases'
                          th 'Old name'
                          th 'New name'
                        elsif item == 'attributes'
                          th 'Name'
                          th 'Read/write?'
                        end
                        th.description(:colspan => 2){"Description"}
                      end
                      self << tr do
                        # looped item rows
                        td.first " "
                        fields.each do |field|
                          if field !~ /desc/
                            self << td('%' + field + '%', :class => field =~ /^old|^name/ ? "highlight" : "normal").if_exists
                          else
                            self << td(('%' + field+ '%').if_exists)
                          end
                        end
                      end.loop(item)
                    end
                  end
                end.if_exists(item)
              end

              self << capture do
                div.section_spacer ''
                h1('%type% %category% methods')
                self << capture do
                  div.a_method do
                    div do
                      self << a.small(:name => '%aref%') {}.if_exists
                      h3 { "<a href='#%aref%'>".if_exists + '%callseq%'.if_exists + '%name%'.if_exists + '%params%'.if_exists + "</a>".if_exists('aref')}
                      self << '%m_desc%'.if_exists
                      self << capture do
                        p.source_link :id => '%aref%-show-link' do
                          a "Show source...", :id => '%aref%-link', :href => "#",
                          :onclick=> "toggle('%aref%-source'); toggleText('%aref%-link'); return false;"
                        end
                        div.source :id => '%aref%-source' do
                          pre { '%sourcecode%' }
                        end
                      end.if_exists('sourcecode')
                    end
                  end
                end.loop('methods').if_exists('methods')
              end.loop('method_list').if_exists('method_list')
            end.loop('sections').if_exists('sections')
          }
         self << page.footer
        end
      end
    }.to_s
  end
end

class String
  # fuck this stupid rdoc templater system
  def if_exists (item = nil)
    unless item
      self unless self =~ /(%(\w+)%)/
      "\nIF:#{$2}\n#{self}\nENDIF:#{$2}\n"
    else
      "\nIF:#{item}\n#{self}\nENDIF:#{item}\n"
    end
  end
  def loop(item)
    "\nSTART:#{item}\n#{self}\nEND:#{item}\n"
  end
end