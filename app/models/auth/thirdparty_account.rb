module Auth
  class ThirdpartyAccount < Account
    include Model::Account::ThirdpartyAccount
  end
end unless defined? Auth::ThirdpartyAccount
