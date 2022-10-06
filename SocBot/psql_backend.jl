module Backend

using LibPQ
using Tables

using DotEnv
DotEnv.config()

# export conn, init_db, get_conn, update_contact_list, get_key, set_key, get_state, set_state

postgres_user=ENV["POSTGRES_USER"]
postgres_password=ENV["POSTGRES_PASSWORD"]
postgres_db=ENV["POSTGRES_DB"]
user_table=ENV["USER_TABLE"]
trip_table=ENV["TRIP_TABLE"]
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
    id = parse(Int, string(id) * string(update_id))
    @info "SELECT * from $trip_table WHERE id=$id;"
    res = execute(conn, "SELECT * from $trip_table WHERE id=$id;")
    if length(columntable(res)[1]) == 0
       res = execute(conn, "INSERT INTO $trip_table VALUES ($id,0);")
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
        keys = Dict("id"=>data[1][1], "state"=>data[2][1], "car"=>data[3][1], "current_trip_id"=>data[4][1])
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
            current_trip_id varchar(50)
        );
    """)

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $trip_table (
            id bigint PRIMARY KEY,
            datetime timestamp,
            origin varchar(200),
            destination varchar(200)
        );
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