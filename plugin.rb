# name: auth0-mozilla
# about: Authenticate with auth0 (for mozilla)
# version: 2.0.2
# authors: Jose Romaniello, Leo McArdle
# url: https://github.com/mozilla/discourse-auth0-mozilla

class Auth0Authenticator < ::Auth::Authenticator

  def name
    'auth0'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    oauth2_uid = auth_token[:uid]
    data = auth_token[:info]
    result.email = email = data[:email]
    result.name = name = data[:name]

    result.extra_data = {
      uid: oauth2_uid,
      provider: 'Auth0',
      name: name,
      email: email,
    }

    result.user = User.find_by_email(email)
    result.email_valid = data[:email] && data[:email_verified]

    result
  end

  def register_middleware(omniauth)
    omniauth.provider :auth0,
          :setup => lambda { |env|
            strategy = env["omniauth.strategy"]
            strategy.options[:client_id] = SiteSetting.auth0_client_id
            strategy.options[:client_secret] = SiteSetting.auth0_client_secret

            domain = SiteSetting.auth0_domain

            strategy.options[:domain] = domain
            strategy.options[:client_options].site          = "https://#{domain}"
            strategy.options[:client_options].authorize_url = "https://#{domain}/authorize"
            strategy.options[:client_options].token_url     = "https://#{domain}/oauth/token"
            strategy.options[:client_options].userinfo_url  = "https://#{domain}/userinfo"
          }

  end
end

require 'omniauth-oauth2'
class OmniAuth::Strategies::Auth0 < OmniAuth::Strategies::OAuth2
  PASSTHROUGHS = %w[
    connection
    redirect_uri
  ]

  option :name, "auth0"
  option :domain, nil
  option :provider_ignores_state, true
  option :connection, ""

  def authorize_params
    super.tap do |param|
      param[:connection] = options.connection
      PASSTHROUGHS.each do |p|
        param[p.to_sym] = request.params[p] if request.params[p]
      end
    end
  end

  uid { raw_info["user_id"] }

  extra do
    { :raw_info => raw_info }
  end

  info do
    {
      :name => raw_info["name"],
      :email => raw_info["email"],
      :nickname => raw_info["nickname"],
      :first_name => raw_info["given_name"],
      :last_name => raw_info["family_name"],
      :location => raw_info["locale"],
      :image => raw_info["picture"],
      :email_verified => raw_info["email_verified"]
    }
  end

  def raw_info
    @raw_info ||= access_token.get(options.client_options.userinfo_url).parsed
  end
end

register_asset "stylesheets/auth0.scss"

auth_provider :title => 'Auth0',
    :message => 'Log in via Auth0',
    :authenticator => Auth0Authenticator.new,
    :full_screen_login => true
