require 'jwt'
module RailsAuth::Application
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_account, :current_authorized_token
    after_action :set_auth_token
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_authorized_token&.user
  end

  def current_account
    return @current_account if defined?(@current_account)
    @current_account = current_authorized_token&.account
  end

  def require_login(return_to: nil)
    return if current_user
    store_location(return_to)

    if current_authorized_token&.oauth_user
      @code = 'oauth_user'
    elsif current_authorized_token&.account
      @code = 'account'
    else
      @code = 'authorized_token'
    end

    if request.format.html?
      render 'require_login', layout: 'application', status: 401
    else
      render 'require_login', status: 401
    end
  end

  def require_authorized_token
    return if current_authorized_token
    @code = 'authorized_token'

    render 'require_authorized_token', status: 401
  end

  def current_authorized_token
    return @current_authorized_token if defined?(@current_authorized_token)

    if request.headers['Authorization']
      auth_token = request.headers['Authorization'].to_s.split(' ').last.presence
    else
      auth_token = request.headers['Auth-Token'].presence || session[:auth_token] || params[:auth_token]
    end
    return unless auth_token

    if verify_auth_token(auth_token)
      @current_authorized_token = ::AuthorizedToken.find_by(token: auth_token)
      @current_authorized_token.increment! :access_counter, 1 if RailsAuth.config.enable_access_counter if @current_authorized_token
      @current_authorized_token
    end
  end

  def store_location(path = nil)
    if path
      session[:return_to] = path
    elsif request.get?
      session[:return_to] = request.url
    else
      session[:return_to] = request.referer
    end

    return if session[:return_to].blank?
    r_path = URI(session[:return_to]).path.delete_suffix('/')

    if RailsAuth.config.ignore_return_paths.include?(r_path)
      session[:return_to] = RailsAuth.config.default_return_path
    end
  end

  def login_by_account(account)
    if params[:uid].present?
      oauth_user = OauthUser.find_by uid: params[:uid]
      if oauth_user
        oauth_user.account_id = account.id
        oauth_user.save
      end
    end

    account.user.update(last_login_at: Time.now)

    @current_account = account
    @current_user = account.user

    logger.debug "  ==========> Login by account #{account.id} as user: #{account.user_id}"
  end

  def login_by_oauth_user(oauth_user)
    session[:auth_token] = oauth_user.account.auth_token
    oauth_user.user.update(last_login_at: Time.current)

    logger.debug "  ==========> Login by oauth user #{oauth_user.id} as user: #{oauth_user.user_id}"
    @current_oauth_user = oauth_user
    @current_user = oauth_user.user
  end

  private
  def set_auth_token
    return unless defined?(@current_authorized_token) && @current_authorized_token

    token = @current_authorized_token.token
    headers['Auth-Token'] = token
    session[:auth_token] = token
    logger.debug "  =========> Set authorized token #{token}, session is #{session[:token]}"
  end

  def verify_auth_token(auth_token)
    payload = JwtHelper.decode_without_verification(auth_token)
    return unless payload

    begin
      key = payload['sub'].constantize.find_by(id: payload['iss'])&.send payload['column']
      JWT.decode(auth_token, key.to_s, true, 'sub' => payload['sub'], verify_sub: true, verify_expiration: false)
    rescue => e
      session.delete :auth_token
      logger.debug e.full_message(highlight: true, order: :top)
    end
  end

end
