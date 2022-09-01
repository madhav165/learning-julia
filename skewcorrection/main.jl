module ImageSkewCorrection

    using Images, ImageTransformations

    function get_binary_image(img::Matrix{RGB{N0f8}}, threshold::Float64)
        img_binary = (Gray.(img) .> threshold);
    end

    function find_score(img::Matrix{Int64}, angle::Float64)
        data = imrotate(img, deg2rad(angle))
        hist = sum(data, dims=2)
        score = sum((hist[2:end] .- hist[1:end-1]) .^ 2)
        return hist, score
    end

    function get_scores(angles::StepRange{Int64, Int64}, matrix::Matrix{Int64})
        scores = []
        Threads.@threads for angle in angles
            find_score(matrix, Float64(angle))
            hist, score = find_score(matrix, Float64(angle))
            push!(scores, score)
        end
        return scores
    end

    function correct_img_skew(img)
        # img_path = "./skewcorrection/original.png"
        # img = load(img_path)
        matrix = get_binary_image(img, 0.5)
        matrix = 1 .- matrix
        # save("./skewcorrection/binary_jl.png", Gray.(matrix))
            
        δ = 1
        limit = 5
        angles = -limit:δ:limit    

        scores = get_scores(angles, matrix)
        best_score = maximum(scores)
        best_index = findfirst(x -> x==best_score, scores)
        # best_score, best_index = findmax(scores)
        best_angle = angles[best_index]
        
        print("Best angle: ", -best_angle)

        rotated_img = imrotate(img, deg2rad(best_angle))
        return rotated_img
        # save("./skewcorrection/skew_corrected_jl.png", Gray.(rotated_img))
    end

    # Threads.nthreads()
end