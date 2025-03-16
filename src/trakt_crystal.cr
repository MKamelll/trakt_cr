require "dotenv"
require "http/client"
require "json"

class RedirectedUriCannotBeEmpty < Exception
end

class AuthCodeCannotBeEmpty < Exception
end

class AuthCredentials
  property client_id
  property client_secret
  property access_token
  property refresh_token

  def initialize(@client_id : String, @client_secret : String, @access_token : String, @refresh_token : String)
  end
end

class Auth
  property base_url = "https://api.trakt.tv"
  property redirect_uri = "http://localhost:8080"
  
  def initialize(@client_id : String, @client_secret : String)
    @access_token_url = "#{@base_url}/oauth/token"
  end

  def get_auth_code
    auth_code_url = "#{@base_url}/oauth/authorize?response_type=code&client_id=#{@client_id}&redirect_uri=#{@redirect_uri}&state=%20"
    puts "Please visit this url and paste the redircted url you receive."
    puts auth_code_url
    print "> "
    
    redirected_uri = gets
    
    return (redirected_uri || "").chomp.sub("#{@redirect_uri}/?code=", "")
  end

  def get_access_token(auth_code : String)
    
    body = {
      "code" => auth_code,
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri" => @redirect_uri,
      "grant_type" => "authorization_code"
    }

    headers = HTTP::Headers{
      "Content-Type" => "application/json"
    }

    return HTTP::Client.post(@access_token_url, headers: headers, body: body.to_json)
  end

  def refresh_access_token(refresh_token : String)
    body = {
      "refresh_token" => refresh_token,
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri" => @redirect_uri,
      "grant_type" => "refresh_token"
    }

    headers = HTTP::Headers{
      "Content-Type" => "application/json"
    }

    return HTTP::Client.post(@access_token_url, headers: headers, body: body.to_json)
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
    @base_movies_url = "https://api.trakt.tv/movies"
  end

  def headers_with_token : HTTP::Headers
    headers_cpy = @headers.dup
    headers_cpy["Authorization"] = "Bearer #{@credentials.access_token}"
    return headers_cpy
  end

  def headers_with(key : String, value : String) : HTTP::Headers
    headers_cpy = @headers.dup
    headers_cpy[key] = value
    return headers_cpy
  end

  def headers_with_pagination : HTTP::Headers
    headers_cpy = @headers.dup
    headers_cpy["X-Pagination-Page"] = "#{num_of_pages}"
    headers_cpy["X-Pagination-Limit"] = "#{num_of_results_per_page}"
    return headers_cpy
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

    return response
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

    return response
  end

  def get_list_by_id(id : Int64)
    list_url = "#{@base_list_url}/#{id}"
    response = HTTP::Client.get(list_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return response
  end

  def get_users_that_like_list_by_id(id : Int64, pagination : Bool = false)
    likes = "#{@base_list_url}/#{id}/likes"
    response = HTTP::Client.get(list_url, headers: @headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return response
  end

  def like_a_list_by_id(id : Int64)
    like_a_list_url = "#{@base_list_url}/#{id}/like"
    response = HTTP::Client.post(like_a_list_url, headers: @headers_with_token)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return response
  end

  def unlike_a_list_by_id(id : Int64)
    unlike_a_list_url = "#{@base_list_url}/#{id}/like"
    response = HTTP::Client.delete(unlike_a_list_url, headers: headers_with_token())
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return response
  end
  
  def get_items_on_a_list_by_id(id : Int64, type : String = "", sorting_by : String = "", sorting_how : String = "")
    items_on_a_list_url = "#{@base_list_url}/#{id}/items/#{type}"
    headers = sorting_by.empty? ? @headers : headers_with("X-Sort-By", sorting_by)
    headers = sorting_how.empty? ? @headers : headers_with("X-Sort-How", sorting_how)
    
    response = HTTP::Client.get(items_on_a_list_url, headers: headers)
    if response.status_code >= 400
      raise AccessTokenInvalid.new
    end

    return response
  end

  def get_all_list_comments_by_list_id(id : Int64, sorting_by : String = "", pagination : Bool = false)
    list_comments_url = "#{@base_list_url}/#{id}/comments/#{sorting_by}"
    headers = pagination ? headers_with_pagination() : headers_with_token()
    return HTTP::Client.get(list_comments_url, headers: headers)
  end

  def get_trending_movies(pagination : Bool = false)
    trending_movies_url = "#{@base_movies_url}/trending"
    headers = pagination ? headers_with_pagination() : @headers
    return HTTP::Client.get(trending_movies_url, headers)
  end

  def get_popular_movies(pagination : Bool = false)
    popular_movies_url = "#{@base_movies_url}/popular"
    headers = pagination ? headers_with_pagination() : @headers
    return HTTP::Client.get(popular_movies_url, headers)
  end

  def get_the_most_favourited_movies(pagination : Bool = false, period : String = "")
    most_favourited_movies_url = "#{@base_movies_url}/favorited/#{period}"
    headers = pagination ? headers_with_pagination() : @headers
    return HTTP::Client.get(most_favourited_movies_url, headers)
  end
end

def main
  Dotenv.load
  client_id = ENV["client_id"]
  client_secret = ENV["client_secret"]
  access_token = ENV["access_token"]
  refresh_token = ENV["refresh_token"]
  auth_code = ENV["auth_code"]

#  auth = Auth.new(client_id, client_secret).authorize.get_access_token

#  puts auth.access_token
#  puts auth.refresh_token

  credentials = AuthCredentials.new(client_id, client_secret, access_token, refresh_token)
  trakt = Trakt.new(credentials)

  list_id = 20388873
  #puts trakt.unlike_a_list_by_id(20388873).status_code
  #puts trakt.get_items_on_a_list_by_id(list_id, sorting_by: "title").body.to_pretty_json
  #auth = Auth.new(client_id, client_secret)
  #puts auth.refresh_access_token(refresh_token).body.to_json
  #puts auth.get_auth_code
  #puts auth.get_access_token(auth_code).body.to_pretty_json
  
  #puts trakt.get_all_list_comments_by_list_id(list_id, sorting_by: "newest").body.to_pretty_json
  #puts trakt.get_trending_movies(pagination: true).body
  #puts trakt.get_popular_movies(pagination: true).body
  puts trakt.get_the_most_favourited_movies(pagination: true).body
end

main()