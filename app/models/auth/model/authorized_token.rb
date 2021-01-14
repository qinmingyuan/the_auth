require 'jwt'
##
# Usually used for access api request
#--
# this not docs
#++
# test
module Auth
  module Model::AuthorizedToken
    extend ActiveSupport::Concern

    included do
      attribute :token, :string, index: { unique: true }
      attribute :expire_at, :datetime
      attribute :session_key, :string, comment: '目前在小程序下用到'
      attribute :access_counter, :integer, default: 0
      attribute :mock_member, :boolean, default: false
      attribute :mock_user, :boolean, default: false
      attribute :identity, :string, index: true

      belongs_to :user, optional: true
      belongs_to :oauth_user, optional: true
      belongs_to :account, foreign_key: :identity, primary_key: :identity, optional: true
      has_many :members, foreign_key: :identity, primary_key: :identity

      scope :valid, -> { where('expire_at >= ?', Time.current).order(expire_at: :desc) }
      validates :token, presence: true

      before_validation :sync_user, if: -> { oauth_user_id_changed? || identity_changed? }
      before_validation :update_token, if: -> { new_record? }
    end

    def sync_user
      if oauth_user
        self.identity = oauth_user.account&.identity
      end
      if account
        self.user_id = account.user_id
      else
        self.user_id = nil
      end

      #self.mock_member = true if user_id != member.user_id
    end

    def verify_token?(now = Time.current)
      return false if self.expire_at.blank?
      if now > self.expire_at
        self.errors.add(:token, 'The token has expired')
        return false
      end

      true
    end

    def update_token
      self.expire_at = 1.weeks.since
      self.token = generate_token
      self
    end

    def update_token!
      update_token
      save
      self
    end

    # iss(issuer) 比如鉴权唯一标识 id,  AppID
    # key 比如 password_digest, AppSecret
    # sub: 'User'
    # column: 'password_digest'
    # exp: auth_token_expire_at, should be int
    # algorithm: 默认HS256
    def generate_token
      if user
        if user.password_digest
          payload = { iss: user_id, sub: 'Auth::User', column: 'password_digest' }
          key = user.password_digest
        else
          payload = { iss: user_id, sub: 'Auth::User', column: 'id' }
          key = user_id
        end
      elsif oauth_user
        payload = { iss: oauth_user_id,  sub: 'Auth::OauthUser', column: 'access_token' }
        key = oauth_user.access_token
      else
        payload = { iss: identity, sub: 'Auth::Account', column: 'identity' }
        key = identity
      end
      payload.merge! exp_float: expire_at.to_f, exp: expire_at.to_i

      JWT.encode(payload, key.to_s)
    end

  end
end
