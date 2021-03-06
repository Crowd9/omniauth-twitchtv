require 'omniauth-oauth2'
require 'httpclient'

module OmniAuth
  module Strategies
    class Twitchtv < OmniAuth::Strategies::OAuth2
      class NoAuthorizationCodeError < StandardError; end

      option :client_options, site: 'https://api.twitch.tv',
                              authorize_url: 'https://api.twitch.tv/kraken/oauth2/authorize',
                              token_url: 'https://api.twitch.tv/kraken/oauth2/token'

      option :authorize_params, {}
      option :authorize_options, [:scope, :response_type]
      option :response_type, 'code'

      uid { raw_info['_id'] }

      info do
        prune!(name: raw_info['name'],
               nickname: raw_info['display_name'],
               email: raw_info['email'],
               image: raw_info['logo'],
               description: raw_info['bio'],
               urls: {
                 twitchtv: profile_url,
               },
               partnered: raw_info['partnered'])
      end

      credentials do
        prune!(token: access_token.token,
               secret: access_token.client.secret)
      end

      extra do
        { raw_info: raw_info }
      end

      def request_phase
        super
      end

      def callback_phase
        super
      rescue NoAuthorizationCodeError => e
        fail!(:no_authorization_code, e)
      end

      def raw_info
        get_hash_from_channel = lambda do |token, client_id|
          http_client = HTTPClient.new
          header = { 'Authorization' => "OAuth #{token}", 'Client-ID ' => client_id, 'Accept' => 'application/vnd.twitchtv.v5+json' }
          response = http_client.get(info_url, '', header)
          if response.code.to_i != 200
            raise Omniauth::Twitchtv::TwitchtvError, 'Failed to get user details from Twitch.TV'
          end
          response
        end

        @raw_info ||= JSON.parse(get_hash_from_channel.call(access_token.token, options.client_id).body)
      end

      def info_url
        unless options.scope && (options.scope.index('user_read') || options.scope.index(:user_read)) ||
               options.scope && (options.scope.index('user_read') || options.scope.index(:user_read)) ||
               options.scope.to_sym == :user_read || options.scope.to_sym == :channel_read
          raise Omniauth::Twitchtv::TwitchtvError, 'You must include at least either the channel or user read scope in omniauth-twitchtv initializer.'
        end
        'https://api.twitch.tv/kraken/user'
      end

      def profile_url
        username = raw_info['name']
        "https://www.twitch.tv/#{username}/profile"
      end

      def prune!(hash)
        hash.delete_if do |_, value|
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end

OmniAuth.config.add_camelization 'twitchtv', 'Twitchtv'
