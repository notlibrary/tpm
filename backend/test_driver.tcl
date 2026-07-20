package require tdbc::postgres

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

set sql_query {
    CREATE TABLE IF NOT EXISTS hello (
        id INT
    )
}

puts "Creating table 'hello'..."

if {[catch {
    set statement [db prepare $sql_query]
    $statement execute
    $statement close
    puts "Table 'hello' created successfully!"
} err]} {
    puts "Error creating table: $err"
}

db close
puts "Connection closed"