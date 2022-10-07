module ORS

using DotEnv
DotEnv.config()

using HTTP
using JSON

token = ENV["ORS_TOKEN"]

function get_coordinates(place_name::String)
    url = "https://api.openrouteservice.org/geocode/search"
    req = HTTP.request("GET", string(url,"?api_key=", token, "&text=", place_name))
    body = String(req.body)
    result = JSON.Parser.parse(body)
    coordinates = Float64.(result["features"][1]["geometry"]["coordinates"])
    return coordinates
end

function get_directions(origin_coordinates::Vector{Float64}, destination_coordinates::Vector{Float64})
    url = "https://api.openrouteservice.org/v2/directions/driving-car/geojson"
    params = Dict("coordinates" => [origin_coordinates, destination_coordinates],
    "elevation" => "true")
    req = HTTP.request("POST",url,["Content-Type" => "application/json", "Authorization" => token],JSON.json(params))
    body = String(req.body)
    result = JSON.Parser.parse(body)
    res = result["features"][1]["geometry"]["coordinates"]
    return res
end

end
