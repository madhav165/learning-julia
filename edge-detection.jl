using Images, Statistics, ImageBinarization, FileIO, Plots

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

img_path = "elevation2.png"
img = load(img_path)
img_edge = sujoy(img, four_connectivity=true)
img_edge₀₁ = binarize(img_edge, Otsu()) # or use other binarization methods provided in ImageBinarization

# mosaicview(img, img_edge, img_edge₀₁; nrow = 3)
save("elevation_edges2.png", img_edge₀₁)

img_matrix = Float32.(img_edge₀₁)

x_means = mean(img_matrix, dims=1)
top_xs = last.(Tuple.(findall(x_means.>0.1)))
y_axis_x = maximum(top_xs.*(top_xs./maximum(top_xs).<0.1))


y_means = mean(img_matrix, dims=2)
top_ys = first.(Tuple.(findall(y_means.>0.1)))
x_axis_y = top_ys[1]

inds = Tuple.(findall(!iszero, img_matrix))

inds2 = filter(x -> x[1]>5 && x[1] < x_axis_y-4 && x[2] > y_axis_x+4 && x[2] < maximum(top_xs)-4, inds)

a = last.(filter(x -> x[1] == x_axis_y+1, inds))
a2 = []
for i in 2:length(a)
    append!(a2, a[i] - a[i-1])
end
filter(x -> x > 5, a2)

a = first.(filter(x -> x[2] == y_axis_x-1, inds))
a2 = []
for i in 2:length(a)
    append!(a2, a[i] - a[i-1])
end
filter(x -> x > 2, a2)


x = last.(inds2)
y2 = []
for c in last.(inds2)
    d = filter(x -> x[2]==c, inds2)
    append!(y2, sum(first.(d))/length(first.(d)))
end

# x = x * 20 /141
# y2 = y2 * 100/43


# maximum(last.(inds))
# (1602-110)*20/141
# maximum(first.(inds2))
# 139*100/43

plot(x, -y2, title = "My Scatter Plot")


y = first.(inds)
x = last.(inds)
plot(x, -y, seriestype = :scatter, title = "My Scatter Plot")