push!(LOAD_PATH, pwd())
using HTTP, Main.ImageSkewCorrection, Images, Sockets

function testfun(request::HTTP.Request)
    try
        data = read(HTTP.parse_multipart_form(request)[1].data)
        write("./skewcorrection/original_serve.png", data)
        img = load("./skewcorrection/original_serve.png")
        rotated_img = Main.ImageSkewCorrection.correct_img_skew(img)
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
