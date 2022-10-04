using LibPQ

conn = LibPQ.Connection("dbname=botdatabase user=bot password=pizza")

result = execute(conn, """
        CREATE TABLE IF NOT EXISTS pizza_bot (
            id    integer PRIMARY KEY,
            state   integer,
            program varchar(10)
        );
    """)

println(result)