using Images, ImageTransformations

function get_binary_image(img, threshold::Float64)
    img_binary = (Gray.(img) .> threshold);
end

function find_score(img::Matrix{Int64}, angle::Float64)
    data = imrotate(img, deg2rad(angle))
    hist = sum(data, dims=2)
    score = sum((hist[2:end] .- hist[1:end-1]) .^ 2)
    return hist, score
end

@time for i in 1:100
    img_path = "./skewcorrection/original.png"
    img = load(img_path)
    matrix = get_binary_image(img, 0.5)
    matrix = 1 .- matrix
    save("./skewcorrection/binary_jl.png", Gray.(matrix))

    δ = 1
    limit = 5
    angles = -limit:δ:limit
    scores = []
    for angle in angles
        find_score(matrix, Float64(angle))
        hist, score = find_score(matrix, Float64(angle))
        push!(scores, score)
    end

    best_score = maximum(scores)
    best_index = findfirst(x -> x==best_score, scores)
    best_angle = angles[best_index]
    print("Best angle: ", -best_angle)

    rotated_img = imrotate(img, deg2rad(best_angle))
    save("./skewcorrection/skew_corrected_jl.png", Gray.(rotated_img))
end


# RotMatrix{size(matrix)[1], size(matrix)[2]}(matrix)
# size(matrix)
# sum(matrix, dims=1)
# # (Xc2*cosd(α) - sind(α)*Yc2, Xc2*sind(α) + cosd(α)*Yc2)
# matrix[1,1]
# α = -5

# one_mat = Tuple.(findall(matrix.==1))
# x = first.(one_mat)
# y = last.(one_mat)

# rot = (a, b) -> (round(a*cosd(α) - b*sind(α),4), round(a*sind(α) + b* cosd(α),4))

# res = map(rot, first.(one_mat), last.(one_mat))

# res

# one_mat

