push!(LOAD_PATH, pwd())
using HTTP, Main.ImageSkewCorrection, Images, Sockets

function testfun(request::HTTP.Request)
    try
        data = read(HTTP.parse_multipart_form(request)[1].data)
        write("./skewcorrection/original_serve_jl.png", data)
        img = load("./skewcorrection/original_serve_jl.png")
        rotated_img = Main.ImageSkewCorrection.correct_img_skew(img)
        save("./skewcorrection/skew_corrected_jl_serve.png", Gray.(rotated_img))
        return HTTP.Response(200, body=HTTP.Form(Dict("result image" => open("./skewcorrection/skew_corrected_jl_serve.png"))))
    catch e
        return HTTP.Response(400, "Error: $e")
    end
end

const ROUTER = HTTP.Router()

HTTP.register!(ROUTER, "GET", "/", req->HTTP.Response(200, "Hi"))
HTTP.register!(ROUTER, "POST", "/", req->testfun(req))
# HTTP.register!(ROUTER, "POST", "/", req->HTTP.Response(200, "Hi"))

server = HTTP.serve!(ROUTER, Sockets.localhost, 8081, reuseaddr=true)

close(server)
