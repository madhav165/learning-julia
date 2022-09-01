using HTTP

url = "http://localhost:8081"
img_path = "./skewcorrection/original.png"

@time Threads.@threads for i in 1:100
print(i)
open(img_path) do io
    headers = []
    body = HTTP.Form([
        "attachment" => HTTP.Multipart("original.png", io, "image/png")
    ])
    resp = HTTP.post(url, headers, body)
    write("./skewcorrection/skew_corrected_jl_client.png", resp.body)
end
end

HTTP.get("http://localhost:8081")