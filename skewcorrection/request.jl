using HTTP


function get_time()
    url = "http://localhost:8081"
    img_path = "./skewcorrection/original.png"
    for i in 1:100
    open(img_path) do io
        resp = HTTP.post(url, [], io)
        write("./skewcorrection/skew_corrected_jl_client.png", resp.body)
    end
    end
end

@time get_time()

HTTP.get("http://localhost:8081")