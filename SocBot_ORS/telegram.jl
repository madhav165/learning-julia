module Telegram

using HTTP
using JSON

# using DotEnv
# DotEnv.config()

url = "https://api.telegram.org/"
key=ENV["TELEGRAM_KEY"]

function send_message(params)
    req = HTTP.request("POST",string(url,"bot",key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function send_document(params)
    query = Dict("chat_id" => params["chat_id"])
    req = HTTP.request("POST",string(url,"bot",key,"/sendDocument"), query=query, body=HTTP.Form(params))
end

function send_photo(params)
    query = Dict("chat_id" => params["chat_id"])
    req = HTTP.request("POST",string(url,"bot",key,"/sendPhoto"), query=query, body=HTTP.Form(params))
end

function get_updates(params)
    req = HTTP.request("GET", string(url,"bot",key,"/getUpdates"), ["Content-Type" => "application/json"],JSON.json(params))
end

end