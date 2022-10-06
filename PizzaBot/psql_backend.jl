module Backend

using LibPQ
using Tables

# export conn, init_db, get_conn, update_contact_list, get_key, set_key, get_state, set_state

postgres_user=ENV["POSTGRES_USER"]
postgres_password=ENV["POSTGRES_PASSWORD"]
postgres_db=ENV["POSTGRES_DB"]
postgres_table=ENV["POSTGRES_TABLE"]
key=ENV["TELEGRAM_KEY"]

conn = -1

function update_contact_list(message)
    id = message["message"]["from"]["id"]
    res = execute(conn, "SELECT * from $postgres_table WHERE id=$id;")
    if length(columntable(res)[1]) == 0
       res = execute(conn, "INSERT INTO $postgres_table VALUES ($id,0);")
    end
end

function send_message(params)
    req = HTTP.request("POST",string(url,"bot",key,"/sendMessage"),["Content-Type" => "application/json"],JSON.json(params))
end

function get_key(id, key)
    res = execute(conn, "SELECT * from $postgres_table WHERE id=$id;")
    data = Tables.columntable(res)
    keys = Dict("id"=>data[1][1], "state"=>data[2][1], "program"=>data[3][1])
    return keys[key]
end

function set_key(id, key, value)
    res = execute(conn, "UPDATE $postgres_table SET $(key)='$value' WHERE id=$id;")
end

function get_state(id)
    return get_key(id,"state")
end

function set_state(id, state)
    set_key(id,"state", state)
end

function init_db()
    conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")

    result = execute(conn, """
        CREATE TABLE IF NOT EXISTS $postgres_table (
            id    integer PRIMARY KEY,
            state   integer,
            program varchar(10)
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