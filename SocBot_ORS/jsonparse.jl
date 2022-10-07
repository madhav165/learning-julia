using JSON
using DataFrames
using CSV
using Plots

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
df3.slope = df3[!,"elevation_diff_m"]./df3[!,"dist_per_wp_m"]
df3.wh_per_km = 119 .+ (df3[!,"slope"] .* 5)
df3.wh_used = df3[!, "wh_per_km"] .* df3[!, "dist_per_wp_m"] ./ 1000
df3[isnan.(df3.wh_used), :wh_used] .= 0
sum(df3[!, "wh_used"])
df3[!, :distance_km] = round.(cumsum(df3[!, :dist_per_wp_m]) / 1000; digits=1)
df3[!, :total_wh_used] = cumsum(df3[!, :wh_used])
# CSV.write("df3.csv", df3)

plot(df3[:,:distance_km], df3[:,:elevation], markersize = 1, size=(1497,539), label="Elevation")
plot(df3[:,:distance_km], df3[:,:total_wh_used], markersize = 1, size=(1497,539), label="Wh used")