module Telegram

using HTTP
using JSON

url = "https://api.telegram.org/"
key=ENV["TELEGRAM_KEY"]

function send_message(params)
    req = HTTP.request("POST",string(url,"bot",key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function get_updates(params)
    req = HTTP.request("GET", string(url,"bot",key,"/getUpdates"), ["Content-Type" => "application/json"],JSON.json(params))
end

end