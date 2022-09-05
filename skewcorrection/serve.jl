push!(LOAD_PATH, pwd())
using HTTP, Main.ImageSkewCorrection, Images, Sockets

# function testfun(request::HTTP.Request)
#     try
#         data = request.body
#         write("./skewcorrection/original_serve.png", data)
#         img = load("./skewcorrection/original_serve.png")
#         rotated_img = Main.ImageSkewCorrection.correct_img_skew(img)
#         save("./skewcorrection/skew_corrected_jl_serve.png", Gray.(rotated_img))
#         open("./skewcorrection/skew_corrected_jl_serve.png") do io
#             return HTTP.Response(read(io))
#         end
#     catch e
#         return HTTP.Response(400, "Error: $e")
#     end
# end
function find_score(img::Matrix{Int64}, angle::Float64)
    data = imrotate(img, deg2rad(angle))
    hist = sum(data, dims=2)
    score = sum((hist[2:end] .- hist[1:end-1]) .^ 2)
    return score
end

function get_scores(angles::StepRange{Int64, Int64}, matrix::Matrix{Int64})
    scores = []
    for angle in angles
        score = find_score(matrix, Float64(angle))
        push!(scores, score)
    end
    return scores
end

function testfun(request::HTTP.Request)
    try
        data = request.body
        write("./skewcorrection/original_serve.png", data)
        img = load("./skewcorrection/original_serve.png")
        # rotated_img = Main.ImageSkewCorrection.correct_img_skew(img)
        matrix = 1 .- (Gray.(img) .> 0.5);
        # matrix = get_binary_image(img, 0.5)
        # matrix = 1 .- matrix
        # save("./skewcorrection/binary_jl.png", Gray.(matrix))
            
        δ = 1
        limit = 5
        angles = -limit:δ:limit

        scores = get_scores(angles, matrix)
        best_score = maximum(scores)
        best_index = findfirst(x -> x==best_score, scores)
        # best_score, best_index = findmax(scores)
        best_angle = angles[best_index]
        
        # print("Best angle: ", -best_angle)

        rotated_img = imrotate(img, deg2rad(best_angle))


        save("./skewcorrection/skew_corrected_jl_serve.png", Gray.(rotated_img))
        open("./skewcorrection/skew_corrected_jl_serve.png") do io
            return HTTP.Response(read(io))
        end
    catch e
        return HTTP.Response(400, "Error: $e")
    end
end

const ROUTER = HTTP.Router()

HTTP.register!(ROUTER, "GET", "/", req->HTTP.Response(200, "Hi"))
HTTP.register!(ROUTER, "POST", "/", req->testfun(req))

server = HTTP.serve!(ROUTER, Sockets.localhost, 8081)

close(server)
