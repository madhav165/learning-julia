module Backend

using LibPQ
using Tables

# export conn, init_db, get_conn, update_contact_list, get_key, set_key, get_state, set_state

postgres_user=ENV["POSTGRES_USER"]
postgres_password=ENV["POSTGRES_PASSWORD"]
postgres_db=ENV["POSTGRES_DB"]
user_table=ENV["USER_TABLE"]
travel_table=ENV["TRAVEL_TABLE"]
key=ENV["TELEGRAM_KEY"]

conn = -1

function update_contact_list(message)
    id = message["message"]["from"]["id"]
    res = execute(conn, "SELECT * from $user_table WHERE id=$id;")
    if length(columntable(res)[1]) == 0
       res = execute(conn, "INSERT INTO $user_table VALUES ($id,0);")
    end
end

function send_message(params)
    req = HTTP.request("POST",string(url,"bot",key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function get_key(table, id, key)
    if table == "user"
        res = execute(conn, "SELECT * from $user_table WHERE id=$id;")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "state"=>data[2][1], "car"=>data[3][1])
        return keys[key]
    elseif table == "travel"
        res = execute(conn, "SELECT * from $travel_table WHERE id=$id;")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "state"=>data[2][1], "car"=>data[3][1])
        return keys[key]
    end 
end

function set_key(table, id, key, value)
    if table == "user"
        res = execute(conn, "UPDATE $user_table SET $(key)='$value' WHERE id=$id;")
    elseif table == "travel"
        res = execute(conn, "UPDATE $travel_table SET $(key)='$value' WHERE id=$id;")
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
    conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $user_table (
            id integer PRIMARY KEY,
            state  integer,
            car varchar(100)
        );
    """)
    println(Tables.columntable(result))

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $travel_table (
            id integer PRIMARY KEY,
            origin varchar(200),
            destination varchar(200)
        );
    """)
    println(Tables.columntable(result))

    close(conn)
end


function get_conn()
    global conn
    if conn == -1
        conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")
    end
    return conn
end

end