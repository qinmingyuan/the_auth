module Auth
  class Panel::OauthUsersController < Panel::BaseController
    before_action :set_oauth_user, only: [:show, :edit, :update, :destroy]

    def index
      q_params = {}
      q_params.merge! params.permit(:user_id, :uid, :appid, :name)

      @oauth_users = OauthUser.includes(:user).default_where(q_params).order(id: :desc).page(params[:page])
    end

    def show
    end

    def edit
    end

    def update
      @oauth_user.assign_attributes(oauth_user_params)

      unless @oauth_user.save
        render :edit, locals: { model: @oauth_user }, status: :unprocessable_entity
      end
    end

    def destroy
      @oauth_user.destroy
    end

    private
    def set_oauth_user
      @oauth_user = OauthUser.find(params[:id])
    end

    def oauth_user_params
      params.fetch(:oauth_user, {}).permit(
        :name
      )
    end

  end
end
