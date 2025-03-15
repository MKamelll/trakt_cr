require "dotenv"
require "http/client"
require "json"

class RedirectedUriCannotBeEmpty < Exception
end

class AuthCodeCannotBeEmpty < Exception
end

class AccessTokenInvalid < Exception
end

class AuthCredentials
  property client_id
  property client_secret
  property access_token
  property refresh_token

  def initialize(@client_id : String, @client_secret : String, access_token : String, refresh_token : String)
  end
end

class Auth
  property base_url = "https://api.trakt.tv"
  property redirect_uri = "http://localhost:8080"
  property auth_code = ""
  property access_token = ""
  property refresh_token = ""
  
  def initialize(@client_id : String, @client_secret : String, @access_token : String ="", @refresh_token : String = "")
  end

  def authorize : Auth
    auth_code_url = "#{@base_url}/oauth/authorize?response_type=code&client_id=#{@client_id}&redirect_uri=#{@redirect_uri}&state=%20"
    puts "Please visit this url and paste the redircted url you receive."
    puts auth_code_url
    print "> "
    
    if redirected_uri = gets
      auth_code = redirected_uri.chomp.sub("#{@redirect_uri}/?code=", "")
      @auth_code = auth_code
      return self
    end
      raise RedirectedUriCannotBeEmpty.new
  end

  def get_access_token : Auth
    access_token_url = "#{@base_url}/oauth/token"

    if @auth_code.empty?
      raise AuthCodeCannotBeEmpty.new
    end
    
    body = {
      "code" => @auth_code,
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri" => @redirect_uri,
      "grant_type" => "authorization_code"
    }

    headers = HTTP::Headers{
      "Content-Type" => "application/json"
    }

    response = HTTP::Client.post(access_token_url, headers: headers, body: body.to_json)
    if response.status_code == 200
      response_js = JSON.parse(response.body)
      @access_token = response_js["access_token"].as_s
      @refresh_token = response_js["refresh_token"].as_s
    end

    return self
  end
end

class Trakt
  property num_of_pages = 1
  property num_of_results_per_page = 10

  def initialize(@credentials : AuthCredentials)
    @headers = HTTP::Headers {
      "Content-Type" => "application/json",
      "trakt-api-version" => "2",
      "trakt-api-key" => @credentials.client_id
    }
    @base_list_url = "https://api.trakt.tv/lists"
  end

  def get_trending_lists(pagination : Bool = false)
    if !pagination
      trending_url = "#{@base_list_url}/trending"
    else
      trending_url = "#{@base_list_url}/trending?page=#{num_of_pages}&limit=#{num_of_results_per_page}"
    end
    response = HTTP::Client.get(trending_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return JSON.parse(response.body)
  end

  def get_popular_lists(pagination : Bool = false)
    if !pagination
      popular_url = "#{@base_list_url}/popular"
    else
      popular_url = "#{@base_list_url}/popular?page=#{num_of_pages}&limit=#{num_of_results_per_page}"
    end
    response = HTTP::Client.get(popular_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return JSON.parse(response.body)
  end

  def get_list_by_id(id : Int64)
    list_url = "#{@base_list_url}/#{id}"
    response = HTTP::Client.get(list_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return JSON.parse(response.body)
  end

  def get_items_of_list_by_id(id : Int64)
    list_url = "#{@base_list_url}/#{id}/items"
    response = HTTP::Client.get(list_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return JSON.parse(response.body)
  end

  def get_users_that_like_list_by_id(id : Int64, pagination : Bool = false)
    likes = "#{@base_list_url}/#{id}/likes"
    response = HTTP::Client.get(list_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return JSON.parse(response.body)
  end
end

def main
  Dotenv.load
  client_id = ENV["client_id"]
  client_secret = ENV["client_secret"]
  access_token = ENV["access_token"]
  refresh_token = ENV["refresh_token"]

#  auth = Auth.new(client_id, client_secret).authorize.get_access_token

#  puts auth.access_token
#  puts auth.refresh_token

  credentials = AuthCredentials.new(client_id, client_secret, access_token, refresh_token)
  trakt = Trakt.new(credentials)

  puts trakt.get_trending_lists(pagination=true)
end

main()