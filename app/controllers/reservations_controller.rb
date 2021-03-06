class ReservationsController < ApplicationController
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]
  before_action :authorize, only: [:show, :edit, :update, :destroy, :schedule, :index]
  include UsersHelper

  def index
    # checks if user admin or logged in

    @stylist = User.stylist
    if params[:reservation]
      
      @reservations = Reservation.includes(:user).where(nil).all
      # if params[:reservation][:date_start] != "" || params[:reservation][:date_end] != ""
      #   @reservations = @reservations.date_range(params[:reservation][:date_start],params[:reservation][:date_end]).all 
      # end
      if params[:reservation][:date_on] != "" 
        @reservations = @reservations.on_date(params[:reservation][:date_on]).all 
      end
      if params[:reservation][:stylist] != ""
        @reservations = @reservations.stylist_name(params[:reservation][:stylist]).all 
      end
      if params[:reservation][:service] != ""
        @reservations = @reservations.service_name(params[:reservation][:service]).all 
      end
      @reservations.order('status = 0 DESC').order(reservation_date: :desc ).order(reservation_time: :desc )
      respond_to do |format|    
        format.html {render :index }
        format.js
      end
    else
      if Reservation.all.where(status: 'pending').any?
        @reservations = Reservation.all.where(status: 'pending')
      else  
      @reservations = Reservation.all.order(status: :desc).order(reservation_date: :desc ).order(reservation_time: :desc )
      end
    end
  end

  def new
    @reservation = Reservation.new
    @stylist = User.stylist
    @user = User.new
  end

  def edit
  end


  def create
    
    @stylist = User.stylist
    @reservation = Reservation.new(reservation_params)
    if !@reservation.service_id.nil?
    length = @reservation.service.length
    @reservation.end_time = @reservation.reservation_time + (length * 60)
    end
    respond_to do |format|
      if @reservation.save # format.js { render :file => "/layouts/application.js"}
        flash.now.notice = "Reservation request submitted."
        format.html { redirect_to current_user, notice: 'Reservation request submitted.' }
        format.json { render :show, status: :created, location: @reservation }

      else
        # flash.now.notice = @reservation.errors.full_messages.to_sentence 
        flash.now.notice = @reservation.errors[:overlapping_appointments].first || @reservation.errors[:stylist_id].first || @reservation.errors[:verify_time].first || @reservation.errors[:verify_day].first
        format.js { render :file => "/layouts/application.js"}
        format.html { render :new }
        format.json { render json: @reservation.errors, status: :unprocessable_entity }
      end
    end
   
  end


  def update
    unless current_user.operator? || current_user.admin?
      redirect_to new_reservation_path, notice: 'Reservation for current service already exists.'
    end
    respond_to do |format|
      if @reservation.update(reservation_params)
        format.html { redirect_to reservations_url, notice: 'Reservation was successfully updated.' }
        # format.json { render :show, status: :ok, location: @reservation }
      else
        format.html { render :edit }
        format.json { render json: @reservation.errors, status: :unprocessable_entity }
      end
    end
  end


  def destroy
    @reservation.destroy
    respond_to do |format|
      format.html { redirect_to reservations_url, notice: 'Reservation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def status_change
    @reservation = Reservation.find(params[:id])
    if @reservation.pending?
      @reservation.status = 'approved'
      @reservation.save
      
      redirect_to reservations_url, notice: 'Reservation was approved.'
    else
      @reservation.status = 'pending'
      @reservation.save
      redirect_to reservations_url, notice: 'Status changed to pending.'
    end

  end

  def autofill
 
    @user = User.find(params[:user_id])


    respond_to do |format|
      format.json { render :json => {:first_name => @user.first_name, :last_name => @user.last_name, :phone_number => @user.phone_number, :email => @user.email, status: :success}}
    end

  end

  def schedule

    if params[:reservation]

      if params[:reservation][:date_on] != "" 
        @date = params[:reservation][:date_on] 
        @schedule = Date.parse("#{@date}")
      end
    else
      @date = Date.today.strftime('%Y-%m-%d')
      @schedule = Date.today
    end
 
  end

  private
      # to keep users other than admin from accessing
    def authorize
      if logged_in?
        unless current_user.admin? || current_user.operator?
          redirect_to root_path, alert: 'You must be admin to access this page.' 
        end
      else
        redirect_to root_path
      end
    end
    # Use callbacks to share common setup or constraints between actions.
    def set_reservation
      @reservation = Reservation.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def reservation_params
      params.require(:reservation).permit(:user_id, :service_id, :reservation_date, :reservation_time, :notes, :stylist_id, :status, :first_name, :last_name, :phone_number, :force_create)
    end
end
