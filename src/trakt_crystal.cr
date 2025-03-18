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
      "code"          => auth_code,
      "client_id"     => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri"  => @redirect_uri,
      "grant_type"    => "authorization_code",
    }

    headers = HTTP::Headers{
      "Content-Type" => "application/json",
    }

    return HTTP::Client.post(@access_token_url, headers: headers, body: body.to_json)
  end

  def refresh_access_token(refresh_token : String)
    body = {
      "refresh_token" => refresh_token,
      "client_id"     => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri"  => @redirect_uri,
      "grant_type"    => "refresh_token",
    }

    headers = HTTP::Headers{
      "Content-Type" => "application/json",
    }

    return HTTP::Client.post(@access_token_url, headers: headers, body: body.to_json)
  end
end

enum CommonHeaders
  Authorization
  Pagination
end

class Trakt
  property num_of_pages = 1
  property num_of_results_per_page = 10

  def initialize(@credentials : AuthCredentials)
    @headers = HTTP::Headers{
      "Content-Type"      => "application/json",
      "trakt-api-version" => "2",
      "trakt-api-key"     => @credentials.client_id,
    }

    @base_url = "https://api.trakt.tv"
    @base_list_url = "#{@base_url}/lists"
    @base_movies_url = "#{@base_url}/movies"
  end

  def add_authorization_header(headers : HTTP::Headers) : HTTP::Headers
    headers_cpy = headers.dup
    headers_cpy["Authorization"] = "Bearer #{@credentials.access_token}"
    return headers_cpy
  end

  def headers_with(key : String, value : String) : HTTP::Headers
    headers_cpy = @headers.dup
    headers_cpy[key] = value
    return headers_cpy
  end

  def add_pagination_header(headers : HTTP::Headers) : HTTP::Headers
    headers_cpy = headers.dup
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
    return HTTP::Client.get(trending_url, headers: @headers)
  end

  def get_popular_lists(pagination : Bool = false)
    if !pagination
      popular_url = "#{@base_list_url}/popular"
    else
      popular_url = "#{@base_list_url}/popular?page=#{num_of_pages}&limit=#{num_of_results_per_page}"
    end
    return HTTP::Client.get(popular_url, headers: @headers)
  end

  def get_list_by_id(id : Int64)
    list_url = "#{@base_list_url}/#{id}"
    return HTTP::Client.get(list_url, headers: @headers)
  end

  def get_users_that_like_list_by_id(id : Int64, pagination : Bool = false)
    likes = "#{@base_list_url}/#{id}/likes"
    return HTTP::Client.get(list_url, headers: @headers)
  end

  def like_a_list_by_id(id : Int64)
    like_a_list_url = "#{@base_list_url}/#{id}/like"
    return HTTP::Client.post(like_a_list_url, headers: @headers_with_token)
  end

  def unlike_a_list_by_id(id : Int64)
    unlike_a_list_url = "#{@base_list_url}/#{id}/like"
    return HTTP::Client.delete(unlike_a_list_url, headers: headers_with_token())
  end

  def get_items_on_a_list_by_id(id : Int64, type : String = "", sorting_by : String = "", sorting_how : String = "")
    items_on_a_list_url = "#{@base_list_url}/#{id}/items/#{type}"
    headers = sorting_by.empty? ? @headers : headers_with("X-Sort-By", sorting_by)
    headers = sorting_how.empty? ? @headers : headers_with("X-Sort-How", sorting_how)
    return HTTP::Client.get(items_on_a_list_url, headers: headers)
  end

  def get_all_list_comments_by_list_id(id : Int64, sorting_by : String = "", pagination : Bool = false)
    list_comments_url = "#{@base_list_url}/#{id}/comments/#{sorting_by}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(list_comments_url, add_authorization_header(@headers))
  end

  def get_trending_movies(pagination : Bool = false)
    trending_movies_url = "#{@base_movies_url}/trending"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(trending_movies_url, headers)
  end

  def get_popular_movies(pagination : Bool = false)
    popular_movies_url = "#{@base_movies_url}/popular"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(popular_movies_url, headers)
  end

  def get_the_most_favourited_movies(pagination : Bool = false, period : String = "")
    most_favourited_movies_url = "#{@base_movies_url}/favorited/#{period}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(most_favourited_movies_url, headers)
  end

  def get_the_most_played_movies(pagination : Bool = false, period : String = "")
    most_played_movies_url = "#{@base_movies_url}/played/#{period}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(most_played_movies_url, headers)
  end

  def get_the_most_watched_movies(pagination : Bool = false, period : String = "")
    most_watched_movies_url = "#{@base_movies_url}/watched/#{period}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(most_watched_movies_url, headers)
  end

  def get_the_most_collected_movies(pagination : Bool = false, period : String = "")
    most_collected_movies_url = "#{@base_movies_url}/collected/#{period}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(most_collected_movies_url, headers)
  end

  def get_the_most_anticipated_movies(pagination : Bool = false)
    most_anticipated_movies_url = "#{@base_movies_url}/anticipated"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(most_anticipated_movies_url, headers)
  end

  def get_the_boxoffice_movies
    boxoffice_movies_url = "#{@base_movies_url}/boxoffice"
    return HTTP::Client.get(boxoffice_movies_url, @headers)
  end

  def get_movie_details(id : Int64)
    movie_summary_url = "#{@base_movies_url}/#{id}"
    return HTTP::Client.get(movie_summary_url, @headers)
  end

  def get_all_movie_aliases(id : Int64)
    movie_aliases_url = "#{@base_movies_url}/#{id}"
    return HTTP::Client.get(movie_aliases_url, @headers)
  end

  def get_all_movie_comments(id : Int64, pagination : Bool = false, sorting_by : String = "")
    movie_comments_url = "#{@base_movies_url}/#{id}/comments/#{sorting_by}"
    headers_p = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(movie_comments_url, add_authorization_header(@headers))
  end

  def get_all_lists_containing_movie(id : Int64, pagination : Bool = false, type : String = "", sorting_by : String = "")
    lists_url = "#{@base_movies_url}/#{id}/lists/#{type}/#{sorting_by}"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(lists_url, headers)
  end

  def get_all_people_of_movie(id : Int64)
    people_url = "#{@base_movies_url}/#{id}/people"
    return HTTP::Client.get(people_url, @headers)
  end

  def get_movie_rating(id : Int64 | String)
    rating_url = "#{@base_movies_url}/#{id}/ratings"
    return HTTP::Client.get(rating_url, @headers)
  end

  def get_related_movies_to(id : Int64 | String)
    related_url = "#{@base_movies_url}/#{id}/related"
    return HTTP::Client.get(related_url, @headers)
  end

  def get_movie_stats(id : Int64 | String)
    movie_stats_url = "#{@base_movies_url}/#{id}/stats"
    return HTTP::Client.get(movie_stats_url, @headers)
  end

  def get_movie_studios(id : Int64 | String)
    movie_studio_url = "#{@base_movies_url}/#{id}/studios"
    return HTTP::Client.get(movie_studio_url, @headers)
  end

  def get_users_watching_movie(id : Int64 | String)
    movie_users_url = "#{@base_movies_url}/#{id}/watching"
    return HTTP::Client.get(movie_users_url, @headers)
  end

  def get_all_videos_concerned_with_movie(id : Int64 | String)
    movie_videos_url = "#{@base_movies_url}/#{id}/videos"
    return HTTP::Client.get(movie_videos_url, @headers)
  end

  def get_all_networks(pagination : Bool = false)
    network_url = "#{@base_url}/networks"
    headers = pagination ? add_pagination_header(@headers) : @headers
    return HTTP::Client.get(network_url, headers)
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

  # list_id = 20388873
  # puts trakt.get_all_movie_comments(1).body.to_pretty_json
  # puts trakt.get_all_lists_containing_movie(1, pagination: true).body
  movie = "tron-legacy-2010"
  puts trakt.get_all_networks(pagination: true).body
end

main()
