using Printf
using JSON
using Dates
using Plots
using Geodesy
using DataFrames
using CSV

using DotEnv
DotEnv.config()

#include("white_backend.jl")
include("psql_backend.jl")
using Main.Backend

include("telegram.jl")
using Main.Telegram

include("ors.jl")
using Main.ORS

function send_welcome(contact)
    id = contact["id"]
    name = contact["first_name"]

    params = Dict("chat_id"=>id, "text"=>string("Hi there, ", name, "!
    
I can help estimate the charging needs for your trip so that you can be free of range anxiety.
   
Click on /plantrip to get started."))

    Telegram.send_message(params)
end

function clean_str(str::String)
    str = strip(str)
    str = replace(str, "," => " ", r"\s+" => " ")
    str = join(map((x) -> uppercasefirst(x), split(str, " ")), " ")
    return str
end

function ask_car(contact)
    id = contact["id"]
    cars = Backend.get_key("car", 1, "car_name")
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
    origin = clean_str(origin)

    params = Dict("chat_id"=>id, "text"=>string("Where are you headed?"))
    Telegram.send_message(params)
    return origin
end

function finalize_trip(message)
    id = message["from"]["id"]
    destination = message["text"]
    destination = clean_str(destination)

    datetime = Dates.unix2datetime(message["date"])
    return datetime, destination
end

function summarize_trip(message)
    id = message["from"]["id"]
    car = Backend.get_key("user", id, "car")
    car_total_wh = Backend.get_key("car", car, "battery_capacity_wh")
    car_usable_capacity_share = Backend.get_key("car", car, "usable_capacity_share")
    car_usable_wh = car_total_wh * car_usable_capacity_share
    current_trip_id = Backend.get_key("user", id, "current_trip_id")
    origin = Backend.get_key("trip", current_trip_id, "origin")
    destination = Backend.get_key("trip", current_trip_id, "destination")

    origin_latitude = Backend.get_key("place", origin, "latitude")
    if origin_latitude === missing
        try
            @info "Querying API for origin coordinates"
            origin_coordinates = ORS.get_coordinates(origin)
            Backend.update_place_list(origin, origin_coordinates[1], origin_coordinates[2])
        catch e
            @error e
        end
    else
        origin_longitude = Backend.get_key("place", origin, "longitude")
        origin_coordinates = [origin_latitude, origin_longitude]
    end

    destination_latitude = Backend.get_key("place", destination, "latitude")
    if destination_latitude === missing
        try
            @info "Querying API for destination coordinates"
            destination_coordinates = ORS.get_coordinates(destination)
            Backend.update_place_list(destination, destination_coordinates[1], destination_coordinates[2])
        catch e
            @error e
        end
    else
        destination_longitude = Backend.get_key("place", destination, "longitude")
        destination_coordinates = [destination_latitude, destination_longitude]
    end

    try
        # origin_coordinates = ORS.get_coordinates(origin)
        # destination_coordinates = ORS.get_coordinates(destination)
        @info "origin_coordinates: $origin_coordinates"
        @info "destination_coordinates: $destination_coordinates"

        distance_text, duration_text, total_ascent, total_descent, df_wh = ORS.get_directions(origin_coordinates, destination_coordinates)
        # CSV.write("df_wh.csv", df_wh)
        # distance_text = "573.2 km"
        # duration_text = "11 h 51 min"
        # total_ascent = 2143.2
        # total_descent = 2548.8
        # df_wh = DataFrame(CSV.File("df_wh.csv"))

        wh_used = sum(df_wh[!, "wh_used"])
        soc_used = round((wh_used / car_usable_wh) * 100; digits=1)
        savefig(plot(df_wh[:,:distance_km], df_wh[:,:elevation], markersize = 1, 
        xlabel="Distance (km)", ylabel="Elevation (m)", label="", title="$origin to $destination\n(Elevation)"), "elevation_$current_trip_id.png")
        savefig(plot(df_wh[:,:distance_km], 100 .* (df_wh[:,:total_wh_used] ./ car_usable_wh), markersize = 1, 
        xlabel="Distance (km)", ylabel="SoC (%)", label="", title="$origin to $destination\n(SoC%)"), "soc_$current_trip_id.png")
        savefig(plot(df_wh[:,:distance_km], df_wh[:,:wh_per_km], markersize = 1, 
        xlabel="Distance (km)", ylabel="Wh per km", label="", title="$origin to $destination\n(Wh/km)"), "wh_per_km_$current_trip_id.png")

        params = Dict("chat_id"=>id, "text"=>string("The distance of $distance_text from $origin to $destination can be covered in $duration_text.

The route has a total elevation gain of $total_ascent m and elevation loss of $total_descent m."))

        Telegram.send_message(params)

        charger_data = Backend.get_all_rows("charger")
        charger_names = charger_data[1]
        charger_companies = charger_data[2]
        charger_powers = charger_data[3]
        charger_lat = charger_data[4]
        charger_lon = charger_data[5]
        charger_ele = charger_data[6]

        way_points = hcat(df_wh[:,:lat], df_wh[:,:lng], df_wh[:,:elevation])
        charger_points = hcat(charger_lon, charger_lat, charger_ele)
        point_to_lla = x -> Geodesy.LLA(x[2], x[1], x[3])

        way_point_lla = [point_to_lla(r) for r in eachrow(way_points)]
        charger_point_lla = [point_to_lla(r) for r in eachrow(charger_points)]

        distance_between_lla = (x, y) -> Geodesy.euclidean_distance(x, y)

        charger_arr = []
        push!(charger_arr, [origin, 0.0, 0.0])
        for (i, c) in enumerate(charger_point_lla)
            dist = df_wh[argmin([distance_between_lla(r[1], c) for r in eachrow(way_point_lla)]), :distance_km]
            charge_used = df_wh[argmin([distance_between_lla(r[1], c) for r in eachrow(way_point_lla)]), :total_wh_used]
            charge_used = round((charge_used / car_usable_wh) * 100; digits=1)
            # @info charger_names[i], dist, charge_used
            # push!(charger_arr, [charger_names[i], dist, charge_used])
            if minimum([distance_between_lla(r[1], c) for r in eachrow(way_point_lla)]) < 30000
                push!(charger_arr, [charger_names[i], dist, charge_used])
            end
        end

        charger_arr = mapreduce(permutedims, vcat, charger_arr)
        charger_arr = charger_arr[sortperm(charger_arr[:, 2]), :]

        charger_string = x -> "$(x[1]) at $(x[2]) km, needs $(x[3])% SoC\n"
        charger_string_total = join(charger_string.(eachrow(charger_arr)), "\n")

        params = Dict("chat_id"=>id, "text"=>string("The different chargers along the route are\n\n$charger_string_total"))

        Telegram.send_message(params)

        # ----

        target_destination_soc = 0.3
        target_charger_soc = 0.2

        if (soc_used < target_destination_soc)
            charging_msg = "Start at $origin with 100% SoC.\nReach $destination with $(trunc(Int, 100 - soc_used))% SoC remaining."
        else
            charging_msg_arr = ["$distance_text: Reach $destination with $(trunc(Int, target_destination_soc*100))% SoC remaining"]

            starting_soc = (soc_used .- charger_arr[:,3]) .+ (target_destination_soc * 100)
            
            while starting_soc[1] > 100
                charger_index = findfirst(x -> x==maximum(starting_soc[starting_soc.<90]), starting_soc)
                charger = charger_arr[charger_index, :]
                charging_msg = "$(charger[2]) km: Reach $(charger[1]) with $(trunc(Int, target_charger_soc * 100))% SoC and charge to $(trunc(Int, starting_soc[charger_index]))% SoC."
                push!(charging_msg_arr, charging_msg)
                old_starting_soc = starting_soc
                starting_soc = (charger_arr[charger_index, 3] .- charger_arr[:,3]) .+ (target_charger_soc * 100)
                if old_starting_soc == starting_soc
                    break
                end
                @info "old_starting_soc=$old_starting_soc, starting_soc=$starting_soc"
            end

            charging_msg = "$(charger_arr[1,2]) km: Start at $origin with $(trunc(Int, starting_soc[1] + charger_arr[1,3]))% SoC."
            push!(charging_msg_arr, charging_msg)

            reverse!(charging_msg_arr)

            charging_msg = join(charging_msg_arr, "\n\n")
            @info charging_msg
        end


        params = Dict("chat_id"=>id, "text"=>string(charging_msg))
        Telegram.send_message(params)

        params = Dict("chat_id"=>id, "text"=>string("Total estimated SoC for the drive is $(trunc(Int, soc_used))%."))
        Telegram.send_message(params)

        # ----

        params = Dict("chat_id"=>id, "text"=>string("Elevation profile"))
        Telegram.send_message(params)

        open("elevation_$current_trip_id.png") do io
            params = Dict("chat_id"=>id, "photo"=>io)
            Telegram.send_photo(params)
        end
        rm("elevation_$current_trip_id.png")

        # params = Dict("chat_id"=>id, "text"=>string("SoC profile"))
        # Telegram.send_message(params)

        open("soc_$current_trip_id.png") do io
            params = Dict("chat_id"=>id, "photo"=>io)
            Telegram.send_photo(params)
        end
        rm("soc_$current_trip_id.png")

        # params = Dict("chat_id"=>id, "text"=>string("Wh per km profile"))
        # Telegram.send_message(params)

        open("wh_per_km_$current_trip_id.png") do io
            params = Dict("chat_id"=>id, "photo"=>io)
            Telegram.send_photo(params)
        end
        rm("wh_per_km_$current_trip_id.png")

    catch e
        @error e
        params = Dict("chat_id"=>id, "text"=>string("I could not estimate your travel SoC needs this time.
        
Please try again with a different name for origin or destination by clicking on /plantrip."))
        Telegram.send_message(params)
    end
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
