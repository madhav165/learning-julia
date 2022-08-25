module EdgeDetector

using Images, Statistics, StatsBase, ImageBinarization, FileIO, Plots, DataFrames,
CSV, ImageMagick

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

function getdata(img, x_start, y_start, x_end, y_end, way, bat_cap, x_end_return, img_return)

    
    # img_path = "learningjulia/data/elevation4.png"
    # img = load(img_path)
    img_edge = sujoy(img, four_connectivity=true)
    img_edge₀₁ = binarize(img_edge, Otsu()) # or use other binarization methods provided in ImageBinarization

    img_matrix = Float32.(img_edge₀₁)
    one_tpl = Tuple.(findall(x -> !iszero(x), img_matrix))
    one_df = DataFrame(one_tpl)
    one_df[:,1] = maximum(one_df[:,1]) .- one_df[:,1]
    one_df = rename(one_df, :1 => :y)
    one_df = rename(one_df, :2 => :x)
    one_df = sort(one_df, [:x, order(:y)])

    y_count = combine(groupby(one_df, :x), nrow => :n)
    maximum(y_count[:,:n])
    y_axis = y_count[findfirst(x -> x==maximum(y_count[:,:n]),y_count[:,:n]),:x]

    x_count = combine(groupby(one_df, :y), nrow => :n)
    maximum(x_count[:,:n])
    x_axis = x_count[findfirst(x -> x==maximum(x_count[:,:n]),x_count[:,:n]),:y]

    two_df = filter(row -> row.x > maximum(y_axis)+5 
                && row.y > maximum(x_axis)+5, one_df)

    y_std = combine(groupby(two_df, :x), :y => std)
    y_mean = combine(groupby(two_df, :x), :y => mean)
    y_mean_std = outerjoin(y_mean, y_std, on = :x)
    two_df = leftjoin(two_df, y_mean_std, on = :x)
    two_df = filter(x -> !isnan(x[:y_std]) && x[:y] > x[:y_mean] - x[:y_std]
    && x[:y] < x[:y_mean] + x[:y_std], two_df)

    two_df = combine(groupby(two_df, :x), :y => minimum)
    two_df = rename!(two_df, :y_minimum => :y)

    x_slope = (x_end - x_start)/(last(two_df[:,:x]) - first(two_df[:,:x]))
    y_slope = (y_end - y_start)/(last(two_df[:,:y]) - first(two_df[:,:y]))
    x_intercept = x_end - (x_slope * last(two_df[:,:x]))
    y_intercept = y_end - (y_slope * last(two_df[:,:y]))

    x = ((two_df[:,:x]) .* (x_slope)) .+ x_intercept
    y = ((two_df[:,:y]) .* (y_slope)) .+ y_intercept

    res_df = DataFrame(x = x,y = y)
    onward_len = size(res_df,1)

    if way == 2
        img_edge = sujoy(img_return, four_connectivity=true)
        img_edge₀₁ = binarize(img_edge, Otsu()) # or use other binarization methods provided in ImageBinarization

        img_matrix = Float32.(img_edge₀₁)
        one_tpl = Tuple.(findall(x -> !iszero(x), img_matrix))
        one_df = DataFrame(one_tpl)
        one_df[:,1] = maximum(one_df[:,1]) .- one_df[:,1]
        one_df = rename(one_df, :1 => :y)
        one_df = rename(one_df, :2 => :x)
        one_df = sort(one_df, [:x, order(:y)])

        y_count = combine(groupby(one_df, :x), nrow => :n)
        maximum(y_count[:,:n])
        y_axis = y_count[findfirst(x -> x==maximum(y_count[:,:n]),y_count[:,:n]),:x]

        x_count = combine(groupby(one_df, :y), nrow => :n)
        maximum(x_count[:,:n])
        x_axis = x_count[findfirst(x -> x==maximum(x_count[:,:n]),x_count[:,:n]),:y]

        two_df = filter(row -> row.x > maximum(y_axis)+5 
                    && row.y > maximum(x_axis)+5, one_df)

        y_std = combine(groupby(two_df, :x), :y => std)
        y_mean = combine(groupby(two_df, :x), :y => mean)
        y_mean_std = outerjoin(y_mean, y_std, on = :x)
        two_df = leftjoin(two_df, y_mean_std, on = :x)
        two_df = filter(x -> !isnan(x[:y_std]) && x[:y] > x[:y_mean] - x[:y_std]
        && x[:y] < x[:y_mean] + x[:y_std], two_df)

        two_df = combine(groupby(two_df, :x), :y => minimum)
        two_df = rename!(two_df, :y_minimum => :y)

        
        if img == img_return
            two_df[:,:y] = reverse(two_df[:,:y])
            x_slope = (x_end_return - x_start)/(last(two_df[:,:x]) - first(two_df[:,:x]))
            y_slope = (y_start - y_end)/(last(two_df[:,:y]) - first(two_df[:,:y]))
            x_intercept = x_end_return - (x_slope * last(two_df[:,:x]))
            y_intercept = y_start - (y_slope * last(two_df[:,:y]))
            x = ((two_df[:,:x]) .* (x_slope)) .+ x_intercept
            y = ((two_df[:,:y]) .* (y_slope)) .+ y_intercept
            x = x .+ maximum(res_df[:,:x])
        else
            # two_df[:,:y] = reverse(two_df[:,:y])
            x_slope = (x_end_return - x_start)/(last(two_df[:,:x]) - first(two_df[:,:x]))
            y_slope = (y_start - y_end)/(last(two_df[:,:y]) - first(two_df[:,:y]))
            x_intercept = x_end_return - (x_slope * last(two_df[:,:x]))
            y_intercept = y_start - (y_slope * last(two_df[:,:y]))
            x = ((two_df[:,:x]) .* (x_slope)) .+ x_intercept
            y = ((two_df[:,:y]) .* (y_slope)) .+ y_intercept
            x = x .+ maximum(res_df[:,:x])
            # reverse!(y)
        end

        
        res_return_df = DataFrame(x = x,y = y)
        res_df = vcat(res_df, res_return_df)
    end

    
    # res_df = res_df[3:end,:]
    y_lag = res_df[1:end-1,:y]
    pushfirst!(y_lag,first(res_df[:,:y]))
    res_df[!,:y_diff] = res_df[:,:y] .- y_lag
    x_lag = res_df[1:end-1,:x]
    pushfirst!(x_lag,first(res_df[:,:x]))
    res_df[!,:x_diff] = res_df[:,:x] .- x_lag
    res_df[!, :cumulative_sum_y_diff] = cumsum(res_df[!, :y_diff])
    res_df[!, :cumulative_sum_x_diff] = cumsum(res_df[!, :x_diff])
    res_df[!,:slope] = res_df[:,:cumulative_sum_y_diff] ./ res_df[:,:cumulative_sum_x_diff]
    res_df[1,:slope] = 0
    res_df[!,:wh_per_km] = 119 .+ 5*(res_df[:,:slope])
    res_df[!,:soc_used] = (res_df[:,:cumulative_sum_x_diff] .* res_df[:,:wh_per_km]) ./ (bat_cap * 0.95)

    # CSV.write("res.csv",res_df)
    return res_df, onward_len
    
end

end