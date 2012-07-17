require 'thread'
require 'fileutils'
require 'active_support/core_ext'
require 'unix_utils'

require 'xlsx_writer/cell'
require 'xlsx_writer/row'
require 'xlsx_writer/header_footer'
require 'xlsx_writer/autofilter'
require 'xlsx_writer/page_setup'
require 'xlsx_writer/xml'
# manual
require 'xlsx_writer/xml/sheet'
require 'xlsx_writer/xml/sheet_rels'
require 'xlsx_writer/xml/image'
require 'xlsx_writer/xml/shared_strings'
# automatic
require 'xlsx_writer/xml/app'
require 'xlsx_writer/xml/content_types'
require 'xlsx_writer/xml/doc_props'
require 'xlsx_writer/xml/rels'
require 'xlsx_writer/xml/styles'
require 'xlsx_writer/xml/workbook'
require 'xlsx_writer/xml/workbook_rels'
require 'xlsx_writer/xml/vml_drawing'
require 'xlsx_writer/xml/vml_drawing_rels'

class XlsxWriter
  attr_reader :staging_dir
  attr_reader :sheets
  attr_reader :images
  attr_reader :page_setup
  attr_reader :header_footer
  attr_reader :shared_strings

  def initialize
    staging_dir = ::UnixUtils.tmp_path 'xlsx_writer'
    ::FileUtils.mkdir_p staging_dir
    @staging_dir = staging_dir
    @sheets = []
    @images = []
    @page_setup = PageSetup.new
    @header_footer = HeaderFooter.new
    @shared_strings = {}
    @mutex = ::Mutex.new
  end

  # Instead of TRUE or FALSE, show TRUE and blank if false
  def quiet_booleans!
    @quiet_booleans = true
  end

  def quiet_booleans?
    @quiet_booleans == true
  end

  def add_sheet(name)
    raise ::RuntimeError, "Can't add sheet, already generated!" if generated?
    sheet = Sheet.new self, name
    sheets << sheet
    sheet
  end
  
  delegate :header, :footer, :to => :header_footer
  
  def add_image(path, width, height)
    raise ::RuntimeError, "Can't add image, already generated!" if generated?
    image = Image.new self, path, width, height
    images << image
    image
  end

  def path
    @path || @mutex.synchronize do
      @path ||= begin 
        sheets.each(&:generate)
        images.each(&:generate)
        Xml.auto.each do |part|
          part.new(self).generate
        end
        with_zip_extname = ::UnixUtils.zip staging_dir
        with_xlsx_extname = with_zip_extname.sub(/.zip$/, '.xlsx')
        ::FileUtils.mv with_zip_extname, with_xlsx_extname
        @generated = true
        with_xlsx_extname
      end
    end
  end

  def cleanup
    ::FileUtils.rm_rf @staging_dir.to_s
    ::FileUtils.rm_f @path.to_s
  end
  
  def generate
    path
    true
  end
  
  def generated?
    @generated == true
  end
end

# backwards compatibility
XlsxWriter::Document = XlsxWriter
