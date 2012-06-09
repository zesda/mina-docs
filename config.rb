activate :automatic_image_sizes
activate :relative_assets

helpers do
  def here
    Page.glob(request.path + '.*').first
  end

  def roots
    Page.roots
  end

  def index
    Page.glob('index').first
  end

  def site_name
    index ? index.title : "Site"
  end

  # Relativize
  def rel(url)
    # Assume abs path
    url = url[1..-1]
    url = url.squeeze('/')

    # Append ../'s
    depth = request.path.count('/') - 1
    path = '../' * depth + url

    path.squeeze('/')
  end

  def page_children(page)
    children = page.children
    of_type  = lambda { |str| children.select { |p| p.data['type'] == str } }

    children.
      group_by { |p|
        type = p.data['type']
        type # pluralize me
      }
  end

  # A link to the source file on GitHub
  def github_source_link
    nil
    # if project.config.github && project.config.git
    #   if page.meta.source_file
    #     "https://github.com/#{project.config.github}/blob/#{project.config.git[0..6]}/#{page.source_file}#L#{page.source_line}".squeeze('/')
    #   end
    # end
  end
end

# Page model.
#
#     # Lookup by filename
#     Page['index.html.haml']           #=> Page instance or nil
#     Page.glob 'index.html.*'          #=> Array of Pages
#
#
# Metadata:
#
#     page.title             #=> "Getting started"
#     page.basename          #=> "getting_started"
#     page.path              #=> "/getting_started/index.html"
#     page.data              #=> Hash
#     page.template_type     #=> "haml"
#     page.raw               #=> String (raw template data)
#     page.content           #=> String
#
# Tree traversal:
#
#     page.parent?           #=> True/false
#     page.parent            #=> Page, or nil if it's a root
#     page.root?             #=> True if depth = 0
#     page.depth             #=> Number, minimum of 0
#     page.breadcrumbs       #=> Array of ancestors
#     page.children          #=> Array
#     page.siblings          #=> Array
#
class Page
  attr_reader :path
  attr_reader :basename
  attr_reader :raw
  attr_reader :title
  attr_reader :data
  attr_reader :template_type

  def self.source_path
    'source'
  end

  def self.glob(spec, except=nil)
    fullspec = File.join(source_path, spec)
    list = Dir[fullspec].map do |f|
      Page[ f[(source_path.length + 1)..-1] ]
    end.sort
    list = list.reject { |p| p.path == except.path }  if except
    list
  end

  def self.[](name)
    @pages ||= Hash.new
    @pages[name] ||= Page.new name
  end

  def self.roots
    Pages.new(glob('*.html.*') + glob('*/index.html.*'))
  end

  def sort_index
    [ (data['order'] || 99999), @basename ]
  end

  def <=>(other)
    sort_index <=> other.sort_index
  end

  def self.mm_server
    ::Middleman::Application.server.inst
  end

  def self.fm_manager
    mm_server.frontmatter_manager
  end

  def initialize(path)
    path = path.gsub(/^(\.?\/)+/, '')
    @basepath = (path =~ /^(.*)\.html\.([A-Za-z0-9]*)$/) && $1 || path
    @template_type = $2
    @basename = File.basename(@basepath)
    @dir = File.dirname(path)
    @parent_dir = File.dirname(@dir)
    @parent_dir = ''  if @parent_dir == '.'
    @full_path = File.join(self.class.source_path, path)
    @path = "/#{@basepath}.html"
    @data, @raw = self.class.fm_manager.data(path)
    @title = data['title'] || @basename
  end

  def content
    # TODO: Parse
    @content ||= @raw
  end

  def to_s
    title
  end

  def parent
    if @basename == 'index'
      # ./tasks/index.html is a child of ./index.html
      Page.glob(File.join(@parent_dir, 'index.html.*'), self).first
    else
      # ./tasks/git_clone.html is a child of ./tasks/index.html,
      # or ./tasks.html
      Page.glob(File.join(@dir, 'index.html.*'), self).first ||
      Page.glob(File.join(@parent_dir, "#{File.basename(@dir)}.html.*"), self).first
    end
  end

  def parent?
    !! parent
  end

  def root?
    ! parent?
  end

  def depth
    root ? 0 : parent.depth + 1
  end

  def breadcrumbs
    if parent?
      [ *parent.breadcrumbs, self ]
    else
      [ self ]
    end
  end

  def children
    list = if @basename == 'index' && !root?
      (Page.glob(File.join(@dir, '*.html.*'), self) +
      Page.glob(File.join(@dir, '*', 'index.html.*'), self)).sort
    else
      (Page.glob(File.join(@dir, @basepath, '*.html.*'), self) +
      Page.glob(File.join(@dir, @basepath, '*', 'index.html.*'), self)).sort
    end

    Pages.new list
  end

  def siblings
    if @basename == 'index' && !root?
      list = (Page.glob(File.join(@parent_dir, '*.html.*')) +
      Page.glob(File.join(@parent_dir, '*', 'index.html.*'))).sort
    else
      list = Page.glob(File.join(@dir, '*.html.*'))
      list = list.reject { |p| p.basename == 'index' }
      list += Page.glob(File.join(@dir, '*', 'index.html.*'))
      list = list.sort
    end
    Pages.new list
  end
end

class Pages < Array
  def groups(attribute='group')
    group_by { |p| p.data[attribute.to_s] }
  end
end

set :layout, :'_templates/layout'

# class Injectah
#   def manipulate_resource_list(resources)
#     resources + ::Middleman::Sitemap::Resource.new(
#       ::Middleman::Application.server.inst.sitemap,
#       '/x.js',
#       '/home/me/real_path_to_x.js'
#     )
#   end
# end

# sitemap.register_resource_list_manipulator :injectah, Injectah.new, false
