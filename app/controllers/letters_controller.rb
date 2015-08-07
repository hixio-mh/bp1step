class LettersController < ApplicationController
  respond_to :html, :json
  before_filter :authenticate_user!, :only => [:edit, :new, :create, :update, :destroy]
  before_action :set_letter, only: [:show, :edit, :update, :destroy]
  helper_method :sort_column, :sort_direction
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

  def index
    @title_letter = 'Письма'
    if params[:date].present? # письма за дату
      @letters = Letter.where(date: params[:date])
      @title_letter += ' за ' + params[:date]
    else
      if params[:addresse].present? # письма от адресанта + письма алресату
        @letters = Letter.where('sender ILIKE ?', params[:addresse])
        @title_letter += ' адреса[н]та ' + params[:addresse]
      else
        if params[:status].present?
          @letters = Letter.where('status = ?', params[:status])
          @title_letter += " в статусе [ #{LETTER_STATUS.key(params[:status].to_i)} ]"
        else
          if params[:user].present?
            user = User.find(params[:user])
            @letters = Letter.joins(:user_letter).where("user_letters.user_id = ?", params[:user])
            @title_letter += " исполнителя [ #{user.displayname} ]"
          else
            #@letters = Letter.search(params[:search]).where('status < 90').includes(:user_letter, :letter_appendix).order(sort_column + ' ' + sort_direction).paginate(:per_page => 10, :page => params[:page])
            @letters = Letter.search(params[:search]).includes(:user_letter, :letter_appendix)
          end
        end
      end
    end
    @letters = @letters.order(sort_column + ' ' + sort_direction).paginate(:per_page => 10, :page => params[:page])
  end

  def show
    @requirements = Requirement.where(letter_id: @letter.id) # требования, созданные из письма
    respond_to do |format|
      format.html
      format.json { render json: @letter }
    end
  end

  def new
    @letter = Letter.new
    @letter.sender = params[:addresse] if params[:addresse].present?
    @letter.author_id = current_user.id if user_signed_in?
    @letter.duedate = (Time.current + 10.days).strftime("%d.%m.%Y") # срок исполнения - даем 10 дней по умолчанию
    @letter.status = 0
  end

  def edit
    @user_letter = UserLetter.new(letter_id: @letter.id)    # заготовка для ответственного
    @letter.author_id = current_user.id if @letter.author_id.blank? and user_signed_in?   # если автора нет - назначим первого, кто внес изменения
  end

  def create
    @letter = Letter.new(letter_params)

    if @letter.save
      redirect_to @letter, notice: 'Letter was successfully created.'
    else
      render action: 'new'
    end
  end

  def update
    if @letter.update(letter_params)
      # begin
      #   LetterMailer.update_letter(@letter, current_user, nil, '').deliver    # оповестим Исполнителей об изменении Письма
      # rescue  Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError => e
      #   flash[:alert] = "Error sending mail to responsible for the letter"
      # end
      redirect_to @letter, notice: 'Letter was successfully updated.'
    else
      @user_letter = UserLetter.new(letter_id: @letter.id)
      render action: 'edit'
    end
  end

  def destroy
    @letter.destroy
    redirect_to letters_url, notice: 'Letter was successfully destroyed.'
  end

  def clone
    letter = Letter.find(params[:id])   # письмо - прототип
    @letter = Letter.new(sender: letter.sender)
    @letter.author_id = current_user.id if user_signed_in?
    @letter.duedate = (Time.current + 10.days).strftime("%d.%m.%Y") # срок исполнения - даем 10 дней по умолчанию
    @letter.source = letter.source
    @letter.subject = letter.subject
  end

  def create_requirement
    letter = Letter.find(params[:id])   # письмо - прототип
    @requirement = Requirement.new(letter_id: letter.id)
    #redirect_to requirements_new(@requirement) and return
    redirect_to proc { new_requirement_url(letter_id: letter.id) } and return
  end

  def create_user
    @letter = Letter.find(params[:id])
    @user_letter = UserLetter.new(letter_id: @letter.id)    # заготовка для ответственного
    render :create_user
    ##respond_with(@letter)
  end

  def update_user
    user_letter = UserLetter.new(params[:user_letter]) if params[:user_letter].present?
    if user_letter
      if user_letter.save
        flash[:notice] = "Исполнитель #{user_letter.user_name} назначен"
        begin
          UserLetterMailer.user_letter_create(user_letter, current_user).deliver_now    # оповестим нового исполнителя
        rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError => e
          flash[:alert] = "Error sending mail to #{user_letter.user.email}"
        end
        @letter = user_letter.letter   #Letter.find(@user_letter.letter_id)
        @letter.update_column(:status, 5) if @letter.status < 1 # если есть ответственные - статус = Назначено
      end
    else
      flash[:alert] = "Ошибка - ФИО Исполнителя не указано."
    end
    respond_with(@letter)
  end

  def record_not_found
    flash[:alert] = "Неверный #id - нет такого письма."
    redirect_to action: :index
  end

  def appendix_create
    @letter = Letter.find(params[:id])
    @letter_appendix = LetterAppendix.new(letter_id: @letter.id)
    render :appendix_create
  end

  def appendix_update
    @letter_appendix = LetterAppendix.new(params[:letter_appendix]) if params[:letter_appendix].present?
    if @letter_appendix
      puts "\n\nappendix_update"
      puts @letter_appendix.inspect
      @letter = @letter_appendix.letter
      puts "\n #{@letter.inspect}"
      if @letter_appendix.save
        flash[:notice] = 'Файл приложения "' + @letter_appendix.appendix_file_name  + '" загружен.'
      end
      puts @letter_appendix.inspect
      puts @letter_appendix.errors.full_messages
    else      
      flash[:alert] = "Ошибка - имя файла не указано."
    end
    respond_with(@letter_appendix.letter)
  end


  private
    def set_letter
      @letter = Letter.find(params[:id])
    end

    def letter_params
      params.require(:letter).permit(:regnumber, :regdate, :number, :date, :subject, :source, :sender, :duedate, 
        :body, :status, :status_name, :result, :letter_id, :author_id, :author_name, :letter_appendix, :letter_id, :name, :appendix)
    end

    def sort_column
      #params[:sort] || "date"
      params[:sort] || "id"   # вверху - самые новые письма
    end

    def sort_direction
      params[:direction] || "desc"
    end
  def record_not_found
    flash[:alert] = "Письмо ##{params[:id]} не найдено."
    redirect_to action: :index
  end


end
