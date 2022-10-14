module Backend

using LibPQ
using Tables
using Dates

# using DotEnv
# DotEnv.config()

# export conn, init_db, get_conn, update_contact_list, get_key, set_key, get_state, set_state

postgres_user=ENV["POSTGRES_USER"]
postgres_password=ENV["POSTGRES_PASSWORD"]
postgres_db=ENV["POSTGRES_DB"]
user_table=ENV["USER_TABLE"]
trip_table=ENV["TRIP_TABLE"]
car_table=ENV["CAR_TABLE"]
place_table=ENV["PLACE_TABLE"]
charger_table=ENV["CHARGER_TABLE"]
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

function update_place_list(place_name, longitude, latitude)
    try
        res = execute(conn, "SELECT * from $place_table WHERE id='$place_name';")
        if length(columntable(res)[1]) == 0
            res = execute(conn, "INSERT INTO $place_table VALUES ('$place_name', $longitude, $latitude);")
        end
    catch e
        @error e
    end
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
    elseif table == "place"
        res = execute(conn, "SELECT * from $place_table WHERE id='$id';")
        data = Tables.columntable(res)
        keys = Dict("id"=>data[1][1], "latitude"=>data[2][1], "longitude"=>data[3][1])
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

function get_row_count(table)
    if table == "user"
        res = execute(conn, "SELECT COUNT(1) FROM $user_table;")
    elseif table == "trip"
        res = execute(conn, "SELECT COUNT(1) FROM $trip_table;")
    elseif table == "car"
        res = execute(conn, "SELECT COUNT(1) FROM $car_table;")
    elseif table == "place"
        res = execute(conn, "SELECT COUNT(1) FROM $place_table;")
    elseif table == "charger"
        res = execute(conn, "SELECT COUNT(1) FROM $charger_table;")
    end
end

function get_all_rows(table)
    if table == "user"
        res = execute(conn, "SELECT * FROM $user_table;")
    elseif table == "trip"
        res = execute(conn, "SELECT * FROM $trip_table;")
    elseif table == "car"
        res = execute(conn, "SELECT * FROM $car_table;")
    elseif table == "place"
        res = execute(conn, "SELECT * FROM $place_table;")
    elseif table == "charger"
        res = execute(conn, "SELECT * FROM $charger_table;")
    end
    data = Tables.columntable(res)
    return data
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
    # conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password")

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
        CREATE TABLE IF NOT EXISTS $place_table (
            id varchar(200) PRIMARY KEY,
            longitude float,
            latitude float
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

    result = execute(conn, """
    DROP TABLE IF EXISTS $charger_table;    
    CREATE TABLE IF NOT EXISTS $charger_table (
            chager_name varchar(200) PRIMARY KEY,
            charger_company varchar(200),
            power_kw int,
            latitude float,
            longitude float,
            elevation float
        );
        INSERT INTO $charger_table VALUES ('Brigade Orchirds - Devanahalli', 'Kurrent', 25, 13.23724626446745, 77.72430818875233, 906);
        --INSERT INTO $charger_table VALUES ('Hotel Gangothri - Kodikonda', 'LionCharge', 24, 13.834520360801957, 77.74170515906907, 715);
        INSERT INTO $charger_table VALUES ('Exotikka Restaurant - Anantapur', 'LionCharge', 24, 14.65469801672688, 77.58183791508813, 356);
        INSERT INTO $charger_table VALUES ('Hotel Bluemoon Highway - Anantapur', 'Tata Power', 24, 15.027635174374792, 77.62079347109878, 323);
        --INSERT INTO $charger_table VALUES ('Matsya Amazon Kitchens - Kurnool', 'Tata Power', 25, 15.577069934453466, 77.9371242460447, 333);
        INSERT INTO $charger_table VALUES ('Hotel Sasya Pride - Kurnool', 'Tata Power', 30, 15.82489624500939, 78.04032394343133, 283);
        INSERT INTO $charger_table VALUES ('Sri Sai Dhaba - Kothakota', 'Tata Power', 24, 16.417256112587747, 77.94041992427229, 351);
        INSERT INTO $charger_table VALUES ('HPCL - Addakal', 'Fortum', 60, 16.533050370221027, 77.93946932013287, 382);
        INSERT INTO $charger_table VALUES ('Hotel Raibow Continental - Rajapur', 'Zeon', 24, 16.870278867053663, 78.16403875802179, 544);
        INSERT INTO $charger_table VALUES ('Manjira Hotels & Resorts - Jadcherla', 'ChargeGrid', 50, 16.798052209484826, 78.14233020499024, 573);
        INSERT INTO $charger_table VALUES ('Croma - Attapur', 'Tata Power', 30, 17.366850824282807, 78.42847612437755, 510);
    """)

    close(conn)
end


function get_conn()
    global conn
    if conn == -1
        conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password host=database")
        # conn = LibPQ.Connection("dbname=$postgres_db user=$postgres_user password=$postgres_password")
    end
    return conn
end

end