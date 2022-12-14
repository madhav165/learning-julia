using JSON
using DataFrames
using CSV
using Plots
using FileIO
using ImageIO

data = JSON.parsefile("response.geojson")

coords = data["features"][1]["geometry"]["coordinates"]
steps = data["features"][1]["properties"]["segments"][1]["steps"]

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

df3 = leftjoin(df, df2, on = :wp)
df3[!, :distance_km] = round.(cumsum(df3[!, :dist_per_wp_m]) / 1000; digits=1)
df3[!, :distance_m] = cumsum(df3[!, :dist_per_wp_m])
df3[!, :elevation_diff_cum] = cumsum(df3[!, :elevation_diff_m])
df3.slope = df3[!,"elevation_diff_cum"] ./ df3[!,"distance_m"]
df3.wh_per_km = 119 .+ (df3[!,"slope"] .* 5)
df3.wh_used = df3[!, "wh_per_km"] .* df3[!, "dist_per_wp_m"] ./ 1000
df3[isnan.(df3.wh_used), :wh_used] .= 0
df3[!, :total_wh_used] = cumsum(df3[!, :wh_used])

df_wh = df3
car_usable_wh = 40500 * 0.95
plot(df_wh[:,:distance_km], df_wh[:,:elevation], markersize = 1, 
xlabel="Distance (km)", ylabel="Elevation (m)", title="Hyderabad to Bengaluru")
plot!(df_wh[:,:distance_km], 100 .* (1 .- (df_wh[:,:total_wh_used] ./ car_usable_wh)), markersize = 1, size=(1497,539), label="SoC")
plot!(df_wh[:,:distance_km], df_wh[:,:wh_per_km], markersize = 1, size=(1497,539), label="Wh per km")
xlabel!("Distance (km)")
title!("Hyderabad to Bengaluru")

# plot(df_wh[:,:lat], df_wh[:,:lng], seriestype = :scatter, title = "My Scatter Plot")

# CSV.write("df3.csv", df3)

# savefig(plot(df3[:,:distance_km], df3[:,:elevation], markersize = 1, size=(1497,539), label="Elevation"), "elevation.png")
# plot(df3[:,:distance_km], df3[:,:total_wh_used], markersize = 1, size=(1497,539), label="Wh used")

# io = IOBuffer(read=true, write=true)
# p = plot(df3[:,:distance_km], df3[:,:elevation], markersize = 1, size=(1497,539), label="Elevation")
# write(io, sprint(show, "image/png", p))
# params = Dict("chat_id"=>id, "photo"=>io)
# params

# Telegram.send_photo(params)

# include("telegram.jl")
# using Main.Telegram
# id = 1783646496
# try
#     open("./elevation.png") do io
#         params = Dict("chat_id"=>id, "photo"=>io)
#         print(params)
#         # Telegram.send_photo(params)
#     end
# catch e
#     @error e
# end
