$: << File.expand_path('edam', File.dirname(__FILE__))

gem 'thrift_client'
require 'thrift_client'

require 'set'
require 'errors_types'
require 'errors_constants'
require 'limits_constants'
require 'limits_types'
require 'note_store'
require 'note_store_constants'
require 'note_store_types'
require 'types_constants'
require 'types_types'
require 'user_store'
require 'user_store_constants'
require 'user_store_types'

module Evernote
  def self.config=(config)
    @config = config.is_a?(Config) ? config : Config.new(config)
  end

  def self.config
    @config || Config.new
  end

  def self.client(klass, url, options)
    ThriftClient.new(klass, url, {:transport => Thrift::HTTPClientTransport}.merge(options))
  end
  
  class Config
    attr_reader :username, :password, :consumer_key, :consumer_secret
    
    def initialize(options = {})
      @endpoint = options[:endpoint] || 'https://sandbox.evernote.com/edam'
      @username = options[:username]
      @password = options[:password]
      @consumer_key = options[:consumer_key]
      @consumer_secret = options[:consumer_secret]
    end
    
    def endpoint(path = '')
      File.join(@endpoint, path)
    end
  end
  
  class UserStore
    Path = '/user'
    ClientName = Evernote::EDAM::UserStore::UserStore::Client
    
    attr_reader :token, :user
    
    def initialize(options = {})
      @token = nil
      @user = nil 
      @client = Evernote.client(
        Evernote::EDAM::UserStore::UserStore::Client,
        Evernote.config.endpoint(Path),
        options
      )     
    end
    
    def method_missing(method, *args, &block)
      @client.send(method, *args, &block)
    end
    
    def authenticate!
      config = Evernote.config
      result = @client.authenticate(config.username, config.password, config.consumer_key, config.consumer_secret)
      @token = result.authenticationToken
      @user = result.user      
      self
    end    
  end
  
  class NoteStore
    Path = '/note/%s'
    
    attr_reader :shard_id
    
    def initialize(user_or_shard_id, options = {})
      @shard_id = user_or_shard_id.is_a?(Evernote::EDAM::Type::User) ? user_or_shard_id.shardId : user_or_shard_id
      @client = Evernote.client(
        Evernote::EDAM::NoteStore::NoteStore::Client,
        Evernote.config.endpoint(Path % @shard_id),
        options
      )
    end
    
    def method_missing(method, *args, &block)
      @client.send(method, *args, &block)
    end
  end
end