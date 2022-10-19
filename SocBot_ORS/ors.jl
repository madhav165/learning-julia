module ORS

using DotEnv
DotEnv.config()

using HTTP
using JSON
using DataFrames
using CSV

token = ENV["ORS_TOKEN"]

function get_coordinates(place_name::String)
    url = "https://api.openrouteservice.org/geocode/search"
    place_name = replace(place_name, " " => "%20")
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

    total_ascent = result["features"][1]["properties"]["ascent"]
    total_descent = result["features"][1]["properties"]["descent"]
    distance_m = result["features"][1]["properties"]["segments"][1]["distance"]
    distance_text = string(round(distance_m/1000; digits=1)) * " km"
    duration_s = result["features"][1]["properties"]["segments"][1]["duration"]
    duration_s = duration_s * 1.67
    duration_text = string(trunc(Int, div(duration_s, 3600))) * " h " * string(trunc(Int, div(mod(duration_s, 3600),60))) * " min"

    coords = result["features"][1]["geometry"]["coordinates"]
    steps = result["features"][1]["properties"]["segments"][1]["steps"]
    
    f_dist_per_wp_m = x -> x["distance"]/(x["way_points"][2] - x["way_points"][1])
    f_range = x -> range(x["way_points"][1] + 2, x["way_points"][2] + 1)
    
    dist_per_wpm = f_dist_per_wp_m.(steps)
    range_wp = f_range.(steps)
    
    df = DataFrame(lat=Float64[], lng=Float64[], elevation=Float64[])
    for row in coords
        push!(df, row)
    end
    df.wp = rownumber.(eachrow(df))
    
    mydiff(v::AbstractVector) = @views v[(begin+1):end] .- v[begin:(end-1)]
    elevation_diff = mydiff(df[!,"elevation"])
    pushfirst!(elevation_diff, 0)
    df.elevation_diff_m = elevation_diff
    
    df2 = DataFrame(wp=Int64[], dist_per_wp_m=Float64[])
    push!(df2, [1, 0.0])
    for (i, r) in enumerate(range_wp)
        for v in r
            push!(df2, [v, dist_per_wpm[i]])
        end
    end
    
    df_wh = leftjoin(df, df2, on = :wp)
    df_wh[!, :distance_m] = cumsum(df_wh[!, :dist_per_wp_m])
    df_wh[!, :distance_km] = round.(df_wh[!, :distance_m] ./ 1000; digits=1)
    df_wh[!, :elevation_diff_cum] = cumsum(df_wh[!, :elevation_diff_m])

    # df_wh.slope = df_wh[!,"elevation_diff_cum"] ./ df_wh[!,"distance_m"]
    # df_wh.wh_per_km = 130 .+ (df_wh[!, "slope"] .* 5000)

    df_wh.slope = df_wh[!,"elevation_diff_m"] ./ df_wh[!,"dist_per_wp_m"]
    df_wh.wh_per_km = ifelse.(df_wh[!,"slope"] .< 0, 47, 99 .+ df_wh[!,"slope"] .* 4355) #60 kmph
    # df_wh.wh_per_km = ifelse.(df_wh[!,"slope"] .< 0, 64, 116 .+ df_wh[!,"slope"] .* 4355) #70 kmph
    # df_wh.wh_per_km = ifelse.(df_wh[!,"slope"] .< 0, 83, 135 .+ df_wh[!,"slope"] .* 4355) #80 kmph
    # df_wh.wh_per_km = ifelse.(df_wh[!,"slope"] .< 0, 105, 157 .+ df_wh[!,"slope"] .* 4355) #90 kmph
    # df_wh.wh_per_km = ifelse.(df_wh[!,"slope"] .< 0, 130, 182 .+ df_wh[!,"slope"] .* 4355) #100 kmph

    df_wh.wh_used = df_wh[!, "wh_per_km"] .* df_wh[!, "dist_per_wp_m"] ./ 1000
    df_wh[isnan.(df_wh.wh_used), :wh_used] .= 0
    df_wh[!, :total_wh_used] = cumsum(df_wh[!, :wh_used])

    CSV.write("df_wh2.csv", df_wh)

    return distance_text, duration_text, total_ascent, total_descent, df_wh
end

end