class Api::V2::BaseController < ActionController::API
  include Pundit::Authorization
  include WithZone
  
  set_current_tenant_through_filter
  prepend_before_action :set_tenant
  impersonates :user

  before_action :verify_jwt_auth
  before_action :set_asset_and_mailer_host
  before_action :store_current_attrs

  helper_method :current_user
  helper_method :cast

  rescue_from ActiveRecord::RecordNotFound do |exception|
    Current.log_loud exception
    Rollbar.info(exception)
    Rails.logger.warn "[404] #{exception.class.name}: #{exception.message}"
    render json: { error: 'Record not found' }, status: :not_found
  end

  rescue_from Pundit::NotAuthorizedError do |exception|
    policy_name = exception.policy.class.to_s.underscore
    Current.log_loud "[Pundit::NotAuthorizedError] #{policy_name}.#{exception.query} #{exception.message}"
    render json: { error: 'Access denied' }, status: :forbidden
  end

  rescue_from Pundit::AuthorizationNotPerformedError do |exception|
    Current.log_loud "[Pundit::AuthorizationNotPerformedError] #{exception.message}"
    render status: :forbidden, plain: "Authorization not performed" and return
  end

  rescue_from ActionController::ParameterMissing do |exception|
    Rails.logger.warn "[400] #{exception.class.name}: #{exception.message}"
    Rollbar.info(exception)
    render json: { error: exception.message }, status: :bad_request
  end

  def verify_jwt_auth
    authenticate_user!
  rescue
    render json: { error: 'You need to sign in or sign up before continuing.' }, status: :unauthorized
  end
  
  def subdomain
    request.subdomains.last&.downcase
  end

  def set_tenant
    Current.subdomain = subdomain

    if (subdomain.present? && subdomain.include?('biomedix2-pr-')) || Current.review_app?
      tenant = Tenant['portal']
      set_current_tenant(tenant)
      Current.log_loud "API - Set Tenant: #{tenant.name} for #{subdomain}.#{Current.host_root}", symbol: '&'

    elsif subdomain.present? && !Current.admin_tenant? && Tenant.find_by(subdomain: subdomain).nil?
      tenant = Tenant['portal']
      set_current_tenant(tenant)

      message = "API - Unknown subdomain.... rendering 404. Attempted Subdomain: #{subdomain}.#{Current.host_root}"
      Current.log_loud(message, symbol: '&')
      Rollbar.info(message, subdomain: subdomain, host: Current.host_root)

      render json: { message: 'Organization not found' }, status: :not_found and return

    elsif subdomain.present? && !Current.admin_tenant?
      Current.tenant = tenant = Tenant.find_by(subdomain: subdomain)

      if tenant
        set_current_tenant(tenant)
        Current.log_loud "API - Set Tenant: #{tenant.name} for #{subdomain}.#{Current.host_root}", symbol: '&'
      else
        Current.log_loud "API - Set Tenant FAILED for #{subdomain}.#{Current.host_root}", symbol: '&'
      end

    else
      Current.log_loud "API - Set Tenant SKIPPED for #{subdomain}.#{Current.host_root}", symbol: '&'
    end

    Current.tenant = current_tenant
  end

  def pagination_meta(collection)
    {
      page: collection.current_page,
      per_page: collection.limit_value,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end

  def cast(this)
    ActiveModel::Type::Boolean.new.cast(this)
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ?  params[:direction] : 'asc'
  end

  protected
  
    def store_current_attrs
      Current.user = current_user
      Current.true_user = true_user
    end

  private

    def set_asset_and_mailer_host
      ActionController::Base.asset_host             = Current.tenant_host_with_port
      ActionMailer::Base.default_url_options[:host] = Current.tenant_host
      Rails.application.routes.default_url_options  = ActionMailer::Base.default_url_options
      if Rails.env.test?
        ActiveStorage::Current.host = "http://#{Current.tenant_host_with_port}"
      end
      # log what we're working with
      Current.log_environment("#{self.class.to_s}#set_asset_and_mailer_host")
    end

end
