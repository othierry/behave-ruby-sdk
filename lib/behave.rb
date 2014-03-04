require 'httparty'
require 'json'

module Behave

  include HTTParty

  base_uri 'http://api.behave.io'
  format :json
  headers 'Content-Type' => 'application/json'

  def self.init(token)
    headers 'X-Behave-Api-Token' => token
  end 

  def self.api(path, method=:get, options={})
    # Convert body object to JSON string as the API only accepts JSON body
    options[:body] = options[:body].to_json if options.has_key? :body
    result = self.send method, path, options
    raise Error.new(result.code), result.message if result.code != 200
    # Empty response
    return {} unless result.parsed_response["data"]
    #
    # @TODO: refactor - ugly hack we use Utils.symbolize_keys to change the type of the keys (string -> symbol)
    #
    # If response is a single object (Hash)
    if result.parsed_response["data"].kind_of? Hash
      return Utils.symbolize_keys result.parsed_response["data"]
    # If response is an array of Hash
    elsif result.parsed_response["data"].kind_of? Array
      return result.parsed_response["data"].map {|h| Utils.symbolize_keys h}     
    end
  end

  def self.track(playerId, event, context={})
    result = api "/players/#{playerId}/track", :post, 
      body: {
        verb: event,
        context: context
      }
    yield result if block_given?
    result
  end

  def self.identify(playerId, traits={})
    api "/players/#{playerId}/identify", :post,
      body: {
        traits: traits
      }
  end

  class Player

    # Fetch player's rank on a specific leaderboard
    def self.rank(playerId, leaderboardId)
      res = ranks playerId, leaderboards: [leaderboardId]
      res[0]
    end

    # Fetch player's ranks on leaderboards is in
    def self.ranks(playerId, options={})
      options[:player_id] = playerId
      Behave.api "/leaderboards/player-results", :post, body: options
    end

    # Fetch player's unlocked badges
    def self.badges(playerId)
      Behave.api "/players/#{playerId}/badges"
    end

    # Fetch player's locked badges
    def self.lockedBadges(playerId)
      Behave.api "/players/#{playerId}/badges/todo"
    end

    # Add an identity to the player (facebook, twitter, ...)
    def self.addIdentity(playerId, identity, provider)
      Behave.api "/players/#{playerId}/identities", :post, 
        body: {
          reference_id: identity,
          provider: provider
        }
    end

    # Remove an identity from the player
    def self.removeIdentity(playerId, provider)
      Behave.api "/players/#{playerId}/identities/#{provider}", :delete
    end

  end

  class Badge

    # Remove a badge
    def self.delete(badgeId)
      Behave.api "/badges/#{badgeId}", :delete
    end

  end

  class Leaderboard

    module Config
      TYPE_SCORE       = 0
      TYPE_BEHAVIOURAL = 1

      TIME_ALLTIME     = 0
      TIME_DAILY       = 1
      TIME_WEEKLY      = 2
      TIME_MONTHLY     = 3

      SCORE_MAX        = 0
      SCORE_SUM        = 1
    end

    # Create a new leaderboard
    def self.create(name, referenceId, attrs={})
      attrs[:name] = name
      attrs[:reference_id] = referenceId
      Behave.api "/leaderboards", :post, body: attrs
    end

    # Remove a leaderboard
    def self.delete(leaderboardId)
      Behave.api "/leaderboards/#{leaderboardId}", :delete
    end

    # Fetch leaderboard results
    def self.results(leaderboardId, options={})
      options[:limit] ||= 1000
      options[:max] ||= 0
      options[:page] ||= 1
      begin
        options[:offset] = (options[:page] - 1) * options[:limit]
        res = Behave.api "/leaderboards/#{leaderboardId}/results", :post, body: options
        count = res.count
        # Get total fetched since start of iteration
        total = (options[:page] - 1) * options[:limit] + count
        # If above, keep only needed elements
        res = res[0..(count - (total - options[:max]))] if options[:max] > 0 && total > options[:max]
        return res unless block_given?
        yield res, options[:page]
        options[:page] += 1
      # Continue wgile still need to fetch more results
      end while count > 0 && count == options[:limit] && (options[:max] == 0 || total < options[:max])
    end
  end

  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
    end
  end

  class Utils
    def self.symbolize_keys(hash)
      hash.inject({}) do |memo, (k,v)|
        if v.kind_of? Hash
          memo[k.to_sym] = symbolize_keys v
        elsif v.kind_of? Array
          memo[k.to_sym] = v.map {|x| x.kind_of?(Hash) ? symbolize_keys(x) : x}
        else
          memo[k.to_sym] = v
        end
        memo
      end
    end

    def self.symbolize_keys!(hash)
      hash.each_key do |key|
        val = hash[key]
        if val.kind_of? Hash
          symbolize_keys! val
        elsif val.kind_of? Array
          val.each {|x| symbolize_keys!(x) if x.kind_of?(Hash) }
        else
          hash[key.to_sym] = hash.delete[key]
        end     
      end
    end
  end

end
