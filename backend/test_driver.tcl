package require tdbc::postgres 1.0.0

set db_host     "localhost"
set db_port     5432
set db_name     "postgres"
set db_user     "postgres"
set db_password "postgres"

puts "Connecting to PostgreSQL db..."

if {[catch {
    tdbc::postgres::connection create db \
        -host $db_host \
        -port $db_port \
        -user $db_user \
        -password $db_password \
        -database $db_name
} err]} {
    puts "Error: $err"
    exit 1
}

puts "Success!"

set sql_create {
    CREATE TABLE IF NOT EXISTS public.driver_users (
        user_id SERIAL PRIMARY KEY,
        username VARCHAR(50) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
}

set sql_insert {
    INSERT INTO public.driver_users (username, email) 
    VALUES ('Hello', 'email@me')
    ON CONFLICT (email) DO NOTHING
}

puts "Creating table 'driver_users'..."

if {[catch {

    set stmt1 [db prepare $sql_create]
    $stmt1 execute
    $stmt1 close
    puts "Table 'driver_users' created successfully!"

    puts "Inserting test data..."
    set stmt2 [db prepare $sql_insert]
    $stmt2 execute
    $stmt2 close
    puts "Data inserted successfully!"

} err]} {
    puts "Error executing SQL: $err"
}

db destroy
puts "Connection closed"
