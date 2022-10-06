using Printf
using JSON

#include("white_backend.jl")
include("psql_backend.jl")
using Main.Backend

include("telegram.jl")
using Main.Telegram

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
    buttons = [Dict("text"=>"Tata Nexon EV Prime"), Dict("text"=>"Tata Nexon EV Max"), 
    Dict("text"=>"Tata Tigor EV"), Dict("text"=>"MG ZS EV")]
    reply_markup = Dict("keyboard"=>[buttons], "one_time_keyboard"=>true)
    params = Dict("chat_id"=>id, "text"=>"What car do you drive?", "reply_markup"=>reply_markup)
    Telegram.send_message(params)
end

function ask_origin(message, state)
    id = message["from"]["id"]
    if state == 2
        car = message["text"]

        if !(car  in ["Tata Nexon EV Prime" "Tata Nexon EV Max" "Tata Tigor EV" "MG ZS EV"])
            car = "Tata Nexon EV Prime"
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
end

function read_people(message, state)
    id = message["from"]["id"]
    people = message["text"]
    program = Backend.get_key("user", id, "program")
    try
        people = parse(Int, people)
        if people <= 0
            throw("too few people")
        end
        send_recipe(message, people)
        return state + 1
    catch
        params = Dict("chat_id"=>id, "text"=>string("I have not understood. For how many people?"))
        Telegram.send_message(params)
        return state
    end
end

function send_recipe(message, people)
    id = message["from"]["id"]
    program = Backend.get_key("user", id, "program")
    if program == "pizza"
        send_pizza(id, people)
    elseif program == "focaccia"
        send_focaccia(id, people)
    end
end

function send_pizza(id, people)
    pizza_recipe = [1000 100 500]
    recipe = pizza_recipe / 4. * people
    params = Dict("chat_id"=>id, "text"=>string("Here are the doses for $(people) people:\n
    $(@sprintf("%.1f", recipe[1]/1000)) Kg of flour\n
    $(@sprintf("%.1f", recipe[2])) ml of oil\n
    $(@sprintf("%.1f", recipe[3])) ml of water\n
    yeast to taste\n
    salt to taste\n"))
    Telegram.send_message(params)
end

function send_focaccia(id, people)
    focaccia_recipe = [660 50 440]
    recipe = focaccia_recipe / 4. * people

    number, rectangular_str, circular_str, rectangular, circular = get_teglia(sum(recipe))


    params = Dict("chat_id"=>id, "text"=>string("Here are the doses for $(people) people:\n
    $(@sprintf("%.3f", recipe[1]/1000)) Kg of Manitoba flour (W = 280)\n
    $(@sprintf("%.1f", recipe[2])) g of oil\n
    $(@sprintf("%.1f", recipe[3])) ml of water\n
    yeast to taste\n
    salt to taste\n\n
    You can use $(circular_str) in diameter: $(@sprintf("%.1f", circular))cm\n
    or $(rectangular_str) $(@sprintf("%.1f", rectangular[1])) cm X $(@sprintf("%.1f", rectangular[2])) cm"))
    Telegram.send_message(params)
end

function get_teglia(impasto)
    area = impasto / 0.60
    rapp = 42 / 35
    area_max = 42 * 35
    number = Int(round(floor(area/area_max) + 1))

    area = area / number # area singola teglia

    h = sqrt(area / rapp)
    b = area / h
    rectangular = [b h]
    circular = sqrt(area/pi)*2

    if number > 1
        rectangular_str = "$(@sprintf("%d", number)) rectangular trays"
        circular_str = "$(@sprintf("%d", number)) circular trays"
    else
        rectangular_str = "a rectangular pan"
        circular_str = "a circular pan"
    end

    return (number, rectangular_str, circular_str, rectangular, circular)
end

function send_bye(contact)
    id = contact["id"]
    name = contact["first_name"]
    if "language_code" in keys(contact)
        lc = contact["language_code"]
    else
        lc = "en"
    end
    if lc=="en"
        params = Dict("chat_id"=>id, "text"=>string("Enjoy your meal ", name, "!"))
    end
    Telegram.send_message(params)
end

function parse_message(message)
    id = message["message"]["from"]["id"]
    Backend.update_contact_list(message)
    state = Backend.get_state("user", id)

    if (state == 0) | (message["message"]["text"]=="/start")
        @info "welcoming user"
        send_welcome(message["message"]["from"])
        Backend.set_state("user", id, 1)
    elseif message["message"]["text"]=="/plantrip"
        if state == 1
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
        # Backend.set_key("travel", id,"origin",origin)
    end
    # elseif state == 3
    #     new_state = read_people(message["message"], 3)
    #     state = new_state
    #     Backend.set_state(id, state)
    # end

    # if state == 4
    #     send_bye(message["message"]["from"])
    #     Backend.set_state(id, 1)
    # end
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