module Backend

using LibPQ
using Tables
using Dates

using DotEnv
DotEnv.config()

# export conn, init_db, get_conn, update_contact_list, get_key, set_key, get_state, set_state

postgres_user=ENV["POSTGRES_USER"]
postgres_password=ENV["POSTGRES_PASSWORD"]
postgres_db=ENV["POSTGRES_DB"]
user_table=ENV["USER_TABLE"]
trip_table=ENV["TRIP_TABLE"]
car_table=ENV["CAR_TABLE"]
key=ENV["TELEGRAM_KEY"]

conn = -1

function update_contact_list(message)
    id = message["message"]["from"]["id"]
    res = execute(conn, "SELECT * from $user_table WHERE id=$id;")
    if length(columntable(res)[1]) == 0
       res = execute(conn, "INSERT INTO $user_table VALUES ($id,0);")
    end
end

function update_trip_list(message)
    id = message["message"]["from"]["id"]
    update_id = message["update_id"]
    id_contac = parse(Int, string(id) * string(update_id))
    datetime = Dates.unix2datetime(message["message"]["date"])
    res = execute(conn, "SELECT * from $trip_table WHERE id=$id_contac;")
    if length(columntable(res)[1]) == 0
       res = execute(conn, "INSERT INTO $trip_table VALUES ($id_contac, $id, '$datetime');")
    end
end

function send_message(params)
    req = HTTP.request("POST",string(url,"bot",key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function get_key(table, id, key)
    if table == "user"
        res = execute(conn, "SELECT * from $user_table WHERE id=$id;")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "state"=>data[2][1], "car"=>data[3][1], "current_trip_id"=>data[4][1])
        return keys[key]
    elseif table == "trip"
        res = execute(conn, "SELECT * from $trip_table WHERE id=$id;")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "user_id"=>data[2][1], "datetime"=>data[3][1], 
        "origin"=>data[4][1], "destination"=>data[5][1])
        return keys[key]
    elseif table == "car"
        res = execute(conn, "SELECT * from $car_table WHERE car_name='$id';")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "car_name"=>data[2][1], "battery_capacity_wh"=>data[3][1], 
        "usable_capacity_share"=>data[4][1])
        return keys[key]
    end 
end

function set_key(table, id, key, value)
    if table == "user"
        res = execute(conn, "UPDATE $user_table SET $(key)='$value' WHERE id=$id;")
    elseif table == "trip"
        res = execute(conn, "UPDATE $trip_table SET $(key)='$value' WHERE id=$id;")
    end
end

function get_state(table, id)
    return get_key(table, id,"state")
end

function set_state(table, id, state)
    set_key(table, id,"state", state)
end

function get_car(table, id)
    return get_key(table, id, "car")
end

function init_db()
    # conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")
    conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password")

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $user_table (
            id integer PRIMARY KEY,
            state  integer,
            car varchar(100),
            current_trip_id bigint
        );
    """)

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $trip_table (
            id bigint PRIMARY KEY,
            user_id integer,
            datetime timestamp,
            origin varchar(200),
            destination varchar(200)
        );
    """)

    result = execute(conn, """
    DROP TABLE IF EXISTS $car_table;    
    CREATE TABLE IF NOT EXISTS $car_table (
            id integer PRIMARY KEY,
            car_name varchar(50),
            battery_capacity_wh integer,
            usable_capacity_share float
        );
        INSERT INTO $car_table VALUES (1, 'Nexon EV Prime', 30200, 0.95);
        INSERT INTO $car_table VALUES (2, 'Nexon EV Max', 40500, 0.95);
        INSERT INTO $car_table VALUES (3, 'Tigor EV', 26000, 0.95);
        INSERT INTO $car_table VALUES (4, 'ZS EV 2021', 43000, 0.95);
        INSERT INTO $car_table VALUES (5, 'ZS EV 2022', 50300, 0.95);
        INSERT INTO $car_table VALUES (6, 'Kona EV', 40500, 0.95);
        INSERT INTO $car_table VALUES (7, 'Tiago EV MR', 19000, 0.95);
        INSERT INTO $car_table VALUES (8, 'Tiago EV LR', 24000, 0.95);
    """)

    close(conn)
end


function get_conn()
    global conn
    if conn == -1
        # conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")
        conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password")
    end
    return conn
end

end