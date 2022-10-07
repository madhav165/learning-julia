module GMaps

using DotEnv
DotEnv.config()

using HTTP

apikey = ENV["GMAPS_API_KEY"]

function get_distance(origin, destination)
    origin = replace(origin, " " => "%20")
    destination = replace(destination, " " => "%20")
    url = "https://maps.googleapis.com/maps/api/distancematrix/json"
    req = HTTP.request("GET", string(url,"?origins=", origin, "&destinations=", destination, "&units=metric&key=", apikey))
    return req
end

end
