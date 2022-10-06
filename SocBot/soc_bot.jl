using Printf
using JSON
using Dates

using DotEnv
DotEnv.config()

#include("white_backend.jl")
include("psql_backend.jl")
using Main.Backend

include("telegram.jl")
using Main.Telegram

include("googlemaps.jl")
using Main.GMaps

function send_welcome(contact)
    id = contact["id"]
    name = contact["first_name"]

    params = Dict("chat_id"=>id, "text"=>string("Hi there, ", name, "!
    
I can help estimate the charging needs for your trip so that you can be free of range anxiety.
   
Type /plantrip to get started."))

    Telegram.send_message(params)
end

function ask_car(contact)
    id = contact["id"]
    cars = Backend.get_key("car", 1, "car_name")
    @info cars
    buttons = [Dict("text"=>"Nexon EV Prime"), Dict("text"=>"Nexon EV Max")]
    reply_markup = Dict("keyboard"=>[buttons], "one_time_keyboard"=>true)
    params = Dict("chat_id"=>id, "text"=>"What car do you drive?", "reply_markup"=>reply_markup)
    Telegram.send_message(params)
end

function ask_origin(message, state)
    id = message["from"]["id"]
    if state == 2
        car = message["text"]

        if !(car  in ["Nexon EV Prime" "Nexon EV Max"])
            car = "Nexon EV Prime"
        end

        params = Dict("chat_id"=>id, "text"=>string("Saving your car as ", car))
        Telegram.send_message(params)

        params = Dict("chat_id"=>id, "text"=>string("Where are you starting your journey?"))
        Telegram.send_message(params)
        return car
    end
    params = Dict("chat_id"=>id, "text"=>string("Where are you starting your journey?"))
    Telegram.send_message(params)
end

function ask_destination(message)
    id = message["from"]["id"]
    origin = message["text"]

    params = Dict("chat_id"=>id, "text"=>string("Where are you headed for?"))
    Telegram.send_message(params)
    return origin
end

function finalize_trip(message)
    id = message["from"]["id"]
    destination = message["text"]
    datetime = Dates.unix2datetime(message["date"])
    return datetime, destination
end

function summarize_trip(message)
    id = message["from"]["id"]
    car = Backend.get_key("user", id, "car")
    current_trip_id = Backend.get_key("user", id, "current_trip_id")
    origin = Backend.get_key("trip", current_trip_id, "origin")
    destination = Backend.get_key("trip", current_trip_id, "destination")

    req = GMaps.get_distance(origin, destination)
    body = String(req.body)
    result = JSON.Parser.parse(body)
    if result["status"] == "OK"
        origin_address = result["origin_addresses"][1]
        destination_address = result["destination_addresses"][1]
        distance_text = result["rows"][1]["elements"][1]["distance"]["text"]
        duration_text = result["rows"][1]["elements"][1]["duration"]["text"]
        distance_m = result["rows"][1]["elements"][1]["distance"]["value"]
        duration_min = result["rows"][1]["elements"][1]["duration"]["value"]
    end
    
    params = Dict("chat_id"=>id, "text"=>string("Wish you a happy journey from $origin_address 
to $destination_address in your $car.

The distance of $distance_text can be covered in $duration_text."))
    Telegram.send_message(params)
end

function parse_message(message)
    id = message["message"]["from"]["id"]
    update_id = message["update_id"]
    Backend.update_contact_list(message)
    state = Backend.get_state("user", id)

    if (state == 0) | (message["message"]["text"]=="/start")
        @info "welcoming user"
        send_welcome(message["message"]["from"])
        Backend.set_state("user", id, 1)
    elseif message["message"]["text"]=="/plantrip"
        Backend.update_trip_list(message)
        Backend.set_key("user", id, "current_trip_id", parse(Int, string(id) * string(update_id)))
        if state <= 1
            car = Backend.get_car("user", id)
            if car === missing
                @info "requesting car info"
                ask_car(message["message"]["from"])
                Backend.set_state("user", id, 2)
            else
                @info "car info found and asking for origin"
                ask_origin(message["message"], state)
                Backend.set_state("user", id, 4)
            end
        else
            @info "asking for origin"
            ask_origin(message["message"], state)
            Backend.set_state("user", id, 4)
        end
    elseif state == 2
        @info "saving car info and asking for origin"
        car = ask_origin(message["message"], state)
        Backend.set_state("user", id, 4)
        Backend.set_key("user", id,"car",car)
    elseif state == 3
        @info "asking for origin"
        ask_origin(message["message"], state)
        Backend.set_state("user", id, 4)
    elseif state == 4
        @info "asking for destination"
        origin = ask_destination(message["message"])
        Backend.set_state("user", id, 5)
        current_trip_id = Backend.get_key("user", id, "current_trip_id")
        Backend.set_key("trip", current_trip_id, "origin", origin)
    elseif state == 5
        @info "sharing trip summary"
        datetime, destination = finalize_trip(message["message"])
        current_trip_id = Backend.get_key("user", id, "current_trip_id")
        Backend.set_key("trip", current_trip_id, "datetime", datetime)
        Backend.set_key("trip", current_trip_id, "destination", destination)
        summarize_trip(message["message"])
    end
end

function run()
    offset = -1

    @info "app is ready!"
    while true
        if offset >= 0
            params = Dict("offset"=>offset)
        else
            params = Dict()
        end
        req = Telegram.get_updates(params)
        body = String(req.body)
        result = JSON.Parser.parse(body)

        if length(result["result"]) < 1
            sleep(0.02)
            continue
        end
        offset = result["result"][end]["update_id"] + 1
        for message in result["result"]
           parse_message(message)
        end
        sleep(0.1)
    end
end


Backend.init_db()
conn = Backend.get_conn()

run()

@sync close(conn)