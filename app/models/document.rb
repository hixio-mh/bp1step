# encoding: utf-8
class Document < ActiveRecord::Base
  # FIXME разобраться со статусами на русском
  # STATUSES = %w[Проект Согласование Утвержден]
  # validates_inclusion_of :status, in: STATUSES

  acts_as_taggable
  #acts_as_taggable_on :category

  #before_validation { document_file.clear if delete_file == '1' }
  has_attached_file :document_file,
    :url  => "/store/:id.:ymd.:basename.:extension",
    :presence  => false,
    :styles => { :pdf => "pdf" }, 
    :path => ":rails_root/public/store/:id.:ymd.:basename.:extension",
    :hash_secret => "BankPermBP1Step",
    :processors => [:convert_to_pdf]
  #validates :document_file, :attachment_presence => false
  ##do_not_validate_attachment_file_type :document_file
  validates_attachment_content_type :document_file, :content_type => ['application/pdf', 'application/vnd.oasis.opendocument.text']

  #after_document_file_post_process :copy_to_pdf
  after_post_process :copy_to_pdf

  #validates_attachment :document_file, :content_type => ["application/pdf", "application/odf", "application/msword", "plain/text"]
  #validates_attachment :document_file, :content_type => { :content_type => "application/pdf" }

  validates :name, :length => {:minimum => 10, :maximum => 200}
  #validates :bproce_id, :presence => true # документ относится к процессу
  validates :dlevel, :numericality => {:less_than => 5, :greater_than => 0}
  validates :place, :presence => true   # документ должен иметь место хранения
  validates :owner_id, presence: true   # должен иметь ответственного
  validates :description, :length => {:maximum => 255}  # описание - не длиннее 255 символов

  include PublicActivity::Model
  tracked owner: Proc.new { |controller, model| controller.current_user }

  # документ относится к процессу
  #belongs_to :bproce
  belongs_to :user
  belongs_to :owner, :class_name => 'User'
  has_many :directive, :through => :document_directive
  has_many :document_directive, :dependent => :destroy
  has_many :bproce, through: :bproce_document
  has_many :bproce_document, dependent: :destroy 

  attr_accessible  :name, :dlevel, :description, :owner_name, :status, :approveorgan, :approved, :note, :place, :document_file, :file_delete

  before_save :destroy_file?  # в не надо ли удалить файл документа?
  after_save :copy_to_pdf

  def owner_name
    owner.try(:displayname)
  end

  def owner_name=(name)
    self.owner = User.find_by_displayname(name) if name.present?
  end

  def pdf_path
    if self.document_file
      extention = File.extname(self.document_file.path)
      if extention != ".pdf"
        pdf_path = self.document_file.path[0, self.document_file.path.length - extention.length] + '.pdf'  # путь к файлу PDF для просмотра
      else
        pdf_path = self.document_file.path
      end
    end
  end

  def pdf_url
    if self.document_file
      extention = File.extname(self.document_file.path)
      if extention != ".pdf"
        pdf_url = self.document_file.url.gsub(extention, ".pdf")  # url файла PDF для просмотра
      else
        pdf_url = self.document_file.url
      end
    end
  end

  def shortname
    return name.split(//u)[0..50].join
  end

  def self.search(search)
    if search
      where('name ILIKE ? or description ILIKE ? or id = ?', "%#{search}%", "%#{search}%", "#{search.to_i}")
    else
      where(nil)
    end
  end

  def file_delete
    @file_delete ||= "0"
  end

  def file_delete=(value)
    @file_delete = value
  end


  private

  # интерполяция для paperclip - вернуть дату последней загрузки файла документа в формате ГГГГММДД
  Paperclip.interpolates :ymd do |attachment, style|
    attachment.instance_read(:updated_at).strftime('%Y%m%d')
  end

  def destroy_file?
    self.document_file = nil if @file_delete == "1"
  end
  
  def copy_to_pdf
    if valid?
      if @file_delete == '1' # файл удаляется
      else
        if self.document_file_file_name?  # задано имя файла
          puts "***model/document.rb:copy_to_pdf*** if " + document_file.path.to_s
          if File.exist?(self.document_file.path)
            puts "***model/document.rb*** convert_to_pdf" + self.document_file.path.to_s
            Paperclip.run('unoconv', "-f pdf #{self.document_file.path}") if File.extname(self.document_file.path) != ".pdf"
          else
            puts "***model/document.rb*** file not found " + self.document_file.path.to_s
          end
        end
      end
    end
  end

end
