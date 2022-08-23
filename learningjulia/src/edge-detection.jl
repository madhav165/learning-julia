using Images, Statistics, StatsBase, ImageBinarization, FileIO, Plots, DataFrames,
CSV

"""
    edges = sujoy(img; four_connectivity=true)

Compute edges of an image using the Sujoy algorithm.

# Parameters

* `img` (Required): any gray image
* `four_connectivity=true`: if true, kernel is based on 4-neighborhood, else, kernel is based on
   8-neighborhood,

# Returns

* `edges` : gray image
"""
function sujoy(img; four_connectivity=false)
    img_channel = Gray.(img)

    min_val = minimum(img_channel)
    img_channel = img_channel .- min_val
    max_val = maximum(img_channel)

    if max_val == 0
        return img
    end

    img_channel = img_channel./max_val

    if four_connectivity
        krnl_h = centered(Gray{Float32}[0 -1 -1 -1 0; 0 -1 -1 -1 0; 0 0 0 0 0; 0 1 1 1 0; 0 1 1 1 0]./12)
        krnl_v = centered(Gray{Float32}[0 0 0 0 0; -1 -1 0 1 1;-1 -1 0 1 1;-1 -1 0 1 1;0 0 0 0 0 ]./12)
    else
        krnl_h = centered(Gray{Float32}[0 0 -1 0 0; 0 -1 -1 -1 0; 0 0 0 0 0; 0 1 1 1 0; 0 0 1 0 0]./8)
        krnl_v = centered(Gray{Float32}[0 0 0 0 0;  0 -1 0 1 0; -1 -1 0 1 1;0 -1 0 1 0; 0 0 0 0 0 ]./8)
    end

    grad_h = imfilter(img_channel, krnl_h')
    grad_v = imfilter(img_channel, krnl_v')

    grad = (grad_h.^2) .+ (grad_v.^2)

    return grad
end

img_path = "learningjulia/data/elevation3.png"
img = load(img_path)
img_edge = sujoy(img, four_connectivity=true)
img_edge₀₁ = binarize(img_edge, Otsu()) # or use other binarization methods provided in ImageBinarization

# mosaicview(img, img_edge, img_edge₀₁; nrow = 3)
save("learningjulia/data/elevation_edges3.png", img_edge₀₁)

img_matrix = Float32.(img_edge₀₁)
one_tpl = Tuple.(findall(x -> !iszero(x), img_matrix))
one_df = DataFrame(one_tpl)
one_df[:,1] = maximum(one_df[:,1]) .- one_df[:,1]
one_df = rename(one_df, :1 => :y)
one_df = rename(one_df, :2 => :x)
one_df = sort(one_df, [:x, order(:y)])

# plot(one_df[:,:x], one_df[:,:y], seriestype = :scatter)

# y_lag= one_df[2:end,:y]
# pushfirst!(y_lag, 0)
# one_df[!,:y_lag] = y_lag
# plot(one_df[:,:x], one_df[:,:y] - one_df[:,:y_lag], seriestype=:scatter)

y_count = combine(groupby(one_df, :x), nrow => :n)
maximum(y_count[:,:n])
y_axis = y_count[findall(x -> x==maximum(y_count[:,:n]),y_count[:,:n]),:x]

x_count = combine(groupby(one_df, :y), nrow => :n)
maximum(x_count[:,:n])
x_axis = x_count[findall(x -> x==maximum(x_count[:,:n]),x_count[:,:n]),:y]

two_df = one_df[one_df.x .> y_axis, :]
two_df = two_df[two_df.y .> x_axis, :]

# two_df = filter( x -> x[:x] > y_axis && x[:y] > x_axis, one_df)


y_std = combine(groupby(two_df, :x), :y => std)
y_mean = combine(groupby(two_df, :x), :y => mean)
y_mean_std = outerjoin(y_mean, y_std, on = :x)
two_df = leftjoin(two_df, y_mean_std, on = :x)
two_df = filter(x -> !isnan(x[:y_std]) && x[:y] > x[:y_mean] - x[:y_std]
&& x[:y] < x[:y_mean] + x[:y_std], two_df)

two_df = combine(groupby(two_df, :x), :y => min)
two_df = rename!(two_df, :y_min => :y)

# plot(two_df[:,:x], two_df[:,:y], seriestype = :scatter)

# plot(two_df[:,:x], two_df[:,:y], seriestype = :scatter)
# CSV.write("two_df.csv", two_df)
# CSV.write("one_df_y_axis.csv", filter(:x => ==(maximum(y_axis)), one_df))
y_ax_df = filter(:x => ==(maximum(y_axis)), one_df)
y_lag = y_ax_df[2:end,:y]
push!(y_lag, 0)
y_ax_df = hcat(y_ax_df, y_lag)
y_ax_df = rename(y_ax_df, :x1 => :y_lead)
y_ax_df[!,:y_diff] = y_ax_df[:,:y_lead] - y_ax_df[:,:y]
y_diff_mode = mode(filter(:y_diff => >(1), y_ax_df)[:,:y_diff])
y_ax_df = filter(:y_diff => ==(y_diff_mode), y_ax_df)
y_lag = y_ax_df[2:end,:y]
push!(y_lag,0)
y_ax_df = hcat(y_ax_df, y_lag)
y_ax_df = rename(y_ax_df, :x1 => :y_lead_2)
y_ax_df[!,:y_diff_2] = y_ax_df[:,:y_lead_2] - y_ax_df[:,:y]
y_pixel_diff = mode(y_ax_df[:,:y_diff_2])


x_ax_df = filter(:y => ==(maximum(x_axis)), one_df)
x_lag = x_ax_df[2:end,:x]
push!(x_lag, 0)
x_ax_df = hcat(x_ax_df, x_lag)
x_ax_df = rename(x_ax_df, :x1 => :x_lead)
x_ax_df[!,:x_diff] = x_ax_df[:,:x_lead] - x_ax_df[:,:x]
x_diff_mode = mode(filter(:x_diff => >(1), x_ax_df)[:,:x_diff])
x_ax_df = filter(:x_diff => ==(x_diff_mode), x_ax_df)
x_lag = x_ax_df[2:end,:x]
push!(x_lag,0)
x_ax_df = hcat(x_ax_df, x_lag)
x_ax_df = rename(x_ax_df, :x1 => :x_lead_2)
x_ax_df[!,:x_diff_2] = x_ax_df[:,:x_lead_2] - x_ax_df[:,:x]
x_pixel_diff = mode(x_ax_df[:,:x_diff_2])

chart_x = 50
chart_y = 100

x = (two_df[:,:x] .- x_axis) .* (chart_x/x_pixel_diff)
y = (two_df[:,:y] .- y_axis) .* (chart_y/y_pixel_diff)

plot(x, y, seriestype = :scatter)

res_df = DataFrame(x = x,y = y)
CSV.write("res.csv", res_df)
