# frozen_string_literal: true

class RolesController < ApplicationController
  respond_to :html, :xml, :json
  helper_method :sort_column, :sort_direction
  before_action :authenticate_user!, only: %i[edit update new create]
  before_action :get_role, except: :index

  def index
    @roles = Role.search(params[:search]).order(sort_column + ' ' + sort_direction).paginate(per_page: 10, page: params[:page])
  end

  def new
    respond_with(@role)
  end

  def create
    @role = Role.new(role_params)
    flash[:notice] = 'Successfully created role.' if @role.save
    respond_with(@role)
  end

  def show
    respond_with(@role = Role.find(params[:id]))
  end

  def edit
    respond_with(@role)
  end

  def update
    flash[:notice] = 'Successfully updated role.' if @role.update_attributes(role_params)
    respond_with(@role)
  end

  def destroy
    @role.destroy
    flash[:notice] = 'Successfully destroyed role.' if @role.save
    respond_with(@role)
  end

  private

  def role_params
    params.require(:role).permit(:name, :description)
  end

  def sort_column
    params[:sort] || 'name'
  end

  def sort_direction
    params[:direction] || 'asc'
  end

  def get_role
    @role = params[:id].present? ? Role.find(params[:id]) : Role.new
  end
end
