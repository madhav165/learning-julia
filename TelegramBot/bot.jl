using Printf
using HTTP
using JSON

using DotEnv
DotEnv.config()

#include("white_backend.jl")
include("psql_backend.jl")
using Main.Backend

url = "https://api.telegram.org/"
key=ENV["TELEGRAM_KEY"]

function send_message(params)
    req = HTTP.request("POST",string(url,"bot", key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function send_welcome(contact)
    id = contact["id"]
    name = contact["first_name"]

    if "language_code" in keys(contact)
        lc = contact["language_code"]
    else
        lc = "en"
    end
    if lc=="en"
        params = Dict("chat_id"=>id, "text"=>string("Hello ", name, "! I'm Pizzabot 
        I'll help you prepare fabulous pizzas and focaccias!
        Type /letscook to get started and then follow the instructions.
        Good job and good appetite !!"))
    else
        params = Dict("chat_id"=>id, "text"=>string("Welcome ", name, " \nClick /letscook to begin.."))
    end
    send_message(params)
end

function ask_program(contact)
    id = contact["id"]
    buttons = [Dict("text"=>"pizza"), Dict("text"=>"focaccia")]
    reply_markup = Dict("keyboard"=>[buttons], "one_time_keyboard"=>true)
    params = Dict("chat_id"=>id, "text"=>"What do you want to cook? (pizza or focaccia)", "reply_markup"=>reply_markup)
    send_message(params)
end

function ask_people(message)
    id = message["from"]["id"]
    program = message["text"]

    if !(program  in ["pizza" "focaccia"])
        program = "pizza"
    end

    params = Dict("chat_id"=>id, "text"=>string("Well then I'll give you instructions to do the ", program))
    send_message(params)
    params = Dict("chat_id"=>id, "text"=>string("For how many people do you want to do the ", program, "?"))
    send_message(params)
    return program
end

function read_people(message, state)
    id = message["from"]["id"]
    people = message["text"]
    program = Backend.get_key(id, "program")
    try
        people = parse(Int, people)
        if people <= 0
            throw("too few people")
        end
        send_recipe(message, people)
        return state + 1
    catch
        params = Dict("chat_id"=>id, "text"=>string("I have not understood. For how many people?"))
        send_message(params)
        return state
    end
end

function send_recipe(message, people)
    id = message["from"]["id"]
    program = Backend.get_key(id, "program")
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
    send_message(params)
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
    send_message(params)
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
    send_message(params)
end

function parse_message(message)
    id = message["message"]["from"]["id"]
    Backend.update_contact_list(message)
    state = Backend.get_state(id)

    if (state == 0) | (message["message"]["text"]=="/start")
        send_welcome(message["message"]["from"])
        Backend.set_state(id, 1)
    elseif (state == 1) | (message["message"]["text"]=="/letscook")
        ask_program(message["message"]["from"])
        Backend.set_state(id, 2)
    elseif state == 2
        program = ask_people(message["message"])
        Backend.set_state(id, 3)
        Backend.set_key(id,"program",program)
    elseif state == 3
        new_state = read_people(message["message"], 3)
        state = new_state
        Backend.set_state(id, state)
    end

    if state == 4
        send_bye(message["message"]["from"])
        Backend.set_state(id, 1)
    end
end

function run()
    offset = -1

    println("ready!")
    while true
    #for i in 1:100
        if offset >= 0
            params = Dict("offset"=>offset)
        else
            params = Dict()
        end
        req = HTTP.request("GET", string(url,"bot", key,"/getUpdates"), ["Content-Type" => "application/json"],JSON.json(params))
        body = String(req.body)
        result = JSON.Parser.parse(body)

        if length(result["result"]) < 1
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