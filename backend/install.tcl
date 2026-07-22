#!/usr/bin/env tclsh
# ============================================
# TOOTHPASTE DATABASE INSTALLATION SCRIPT
# Drops and recreates the toothpastes database
# ============================================

package require Tk

# ============================================
# Configuration
# ============================================

set DB_HOST "localhost"
set DB_PORT "5432"
set DB_NAME "toothpastes"
set DB_USER "postgres"
set DB_PASS ""
set PG_PATH "C:/Program Files/PostgreSQL/14/bin"  ;# Adjust this path
set SQL_FILE "db.sql"

# ============================================
# Helper Functions
# ============================================

# Check if PostgreSQL is installed
proc check_postgres {} {
    global PG_PATH
    
    # Try to find psql.exe
    set possible_paths [list]
    
    # Add user-specified path
    if {$PG_PATH ne ""} {
        lappend possible_paths $PG_PATH
    }
    
    # Common installation paths
    if {$::tcl_platform(platform) eq "windows"} {
        lappend possible_paths "C:/Program Files/PostgreSQL/14/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/15/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/16/bin"
        lappend possible_paths "C:/Program Files (x86)/PostgreSQL/14/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/13/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/12/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/11/bin"
    } else {
        lappend possible_paths "/usr/bin"
        lappend possible_paths "/usr/local/bin"
        lappend possible_paths "/opt/PostgreSQL/14/bin"
        lappend possible_paths "/opt/PostgreSQL/15/bin"
        lappend possible_paths "/opt/PostgreSQL/13/bin"
    }
    
    # Add PATH environment
    if {[info exists ::env(PATH)]} {
        foreach dir [split $::env(PATH) ";"] {
            if {$dir ne ""} {
                lappend possible_paths $dir
            }
        }
    }
    
    # Look for psql
    foreach dir $possible_paths {
        if {$::tcl_platform(platform) eq "windows"} {
            set psql_exe [file join $dir "psql.exe"]
        } else {
            set psql_exe [file join $dir "psql"]
        }
        
        if {[file exists $psql_exe]} {
            return $psql_exe
        }
    }
    
    # If not found, try which/where
    if {$::tcl_platform(platform) ne "windows"} {
        catch {
            set psql_exe [exec which psql 2>/dev/null]
            if {$psql_exe ne ""} {
                return $psql_exe
            }
        }
    }
    
    return ""
}

# Test PostgreSQL connection
proc test_postgres_connection {} {
    global DB_HOST DB_PORT DB_USER DB_PASS
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        return [list 0 "PostgreSQL client (psql) not found"]
    }
    
    # Try to connect and get version
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    lappend cmd -d postgres
    lappend cmd -c "SELECT version()"
    
    if {$DB_PASS ne ""} {
        set env(PGPASSWORD) $DB_PASS
    }
    
    set result [catch {exec {*}$cmd} output]
    
    if {$result != 0} {
        return [list 0 "Cannot connect to PostgreSQL at $DB_HOST:$DB_PORT\n\nError: $output\n\nPlease check:\n1. PostgreSQL service is running\n2. Host and port are correct\n3. Username and password are correct"]
    }
    
    return [list 1 $output]
}

# Execute PostgreSQL command
proc exec_psql {args} {
    global DB_HOST DB_PORT DB_USER DB_PASS
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        error "PostgreSQL client (psql) not found. Please install PostgreSQL or set PG_PATH."
    }
    
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    
    # Set password via environment variable
    if {$DB_PASS ne ""} {
        set env(PGPASSWORD) $DB_PASS
    } else {
        # Try to use no password
        lappend cmd -w
    }
    
    foreach arg $args {
        lappend cmd $arg
    }
    
    puts "DEBUG: Executing psql with args: [lrange $args 0 end]"
    
    set result [catch {exec {*}$cmd} output]
    
    if {$result != 0} {
        # Check if it's a connection error
        if {[string match "*Connection refused*" $output] || [string match "*could not connect*" $output]} {
            error "PostgreSQL connection failed:\n$output\n\nPlease make sure PostgreSQL is running and accessible."
        }
        error "Command failed: $output"
    }
    
    return $output
}

# ============================================
# Main Installation Script
# ============================================

proc install_database {} {
    global SQL_FILE
    
    set w .install
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Toothpaste Database Installation"
    wm geometry $w "700x600"
    wm resizable $w 0 0
    wm protocol $w WM_DELETE_WINDOW {exit}
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 700) / 2}]
    set y [expr {([winfo screenheight .] - 600) / 2}]
    wm geometry $w "+$x+$y"
    
    # Main container
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    # Title
    ttk::label $main.title -text "🧴 Toothpaste Database Installation" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    ttk::label $main.subtitle -text "This script will drop and recreate the 'toothpastes' database" -font {Arial 10} -foreground gray
    pack $main.subtitle -pady 5
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    # Status text
    set status_frame [ttk::frame $main.status]
    pack $status_frame -fill both -expand true -pady 5
    
    ttk::label $status_frame.title -text "Installation Log:" -font {Arial 10 bold}
    pack $status_frame.title -anchor w
    
    set text [text $status_frame.log -wrap word -font {Courier 10} -height 18 -yscrollcommand "$status_frame.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $status_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Progress bar
    set progress [ttk::progressbar $main.progress -mode indeterminate -length 500]
    pack $progress -fill x -pady 10
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.install -text "🚀 Install Database" -command [list install_db_proc $text $progress $w] -padding "10 5"
    pack $btn_frame.install -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.test -text "🔍 Test Connection" -command [list test_connection_proc $text] -padding "10 5"
    pack $btn_frame.test -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.close -text "❌ Close" -command "destroy $w" -padding "10 5"
    pack $btn_frame.close -side right -expand true -fill x -padx 5
    
    # Store references
    set ::install_text $text
    set ::install_progress $progress
}

proc log_message {text msg {color "black"}} {
    $text insert end "$msg\n" $color
    $text see end
    update idletasks
}

proc test_connection_proc {text} {
    log_message $text "🔍 Testing PostgreSQL connection..." 
    log_message $text "========================================" 
    
    set result [test_postgres_connection]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {$status} {
        log_message $text "✅ Connection successful!" 
        log_message $text "$message" 
        tk_messageBox -icon info -title "✅ Connection Successful" \
            -message "Successfully connected to PostgreSQL!\n\n$message"
    } else {
        log_message $text "❌ Connection failed!" 
        log_message $text "$message" 
        tk_messageBox -icon error -title "❌ Connection Failed" \
            -message "PostgreSQL connection test failed.\n\n$message"
    }
}

proc install_db_proc {text progress w} {
    # Disable install button
    $w.main.buttons.install configure -state disabled
    $progress start
    
    log_message $text "🚀 Starting database installation..." 
    log_message $text "========================================" 
    
    # Step 0: Test connection first
    log_message $text "\n📌 Step 0: Testing PostgreSQL connection..." 
    set conn_test [test_postgres_connection]
    set conn_status [lindex $conn_test 0]
    set conn_message [lindex $conn_test 1]
    
    if {!$conn_status} {
        log_message $text "❌ PostgreSQL connection failed!" 
        log_message $text "$conn_message" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Connection Error" \
            -message "Cannot connect to PostgreSQL.\n\n$conn_message\n\nPlease make sure:\n1. PostgreSQL is installed and running\n2. The connection settings are correct\n3. The service is accessible"
        return
    }
    log_message $text "✅ PostgreSQL connection successful" 
    
    # Check PostgreSQL client
    log_message $text "\n📌 Step 1: Checking PostgreSQL client..."
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        log_message $text "❌ ERROR: PostgreSQL client (psql) not found!" 
        log_message $text "   Please set PG_PATH in the script or install PostgreSQL." 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "PostgreSQL client (psql) not found.\n\nPlease install PostgreSQL or set PG_PATH in the script."
        return
    }
    log_message $text "✅ Found PostgreSQL client: $psql_exe" 
    
    # Check SQL file
    global SQL_FILE
    if {![file exists $SQL_FILE]} {
        log_message $text "❌ ERROR: SQL file '$SQL_FILE' not found!" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "SQL file '$SQL_FILE' not found.\n\nPlease make sure db.sql is in the current directory."
        return
    }
    log_message $text "✅ Found SQL file: $SQL_FILE" 
    
    # Step 1: Drop database if exists
    log_message $text "\n📌 Step 2: Dropping existing database (if any)..." 
    
    if {[catch {
        exec_psql -d postgres -c "DROP DATABASE IF EXISTS $::DB_NAME;"
    } errorMsg]} {
        # Check if error is about connection
        if {[string match "*Connection refused*" $errorMsg] || [string match "*could not connect*" $errorMsg]} {
            log_message $text "❌ PostgreSQL connection error!" 
            log_message $text "$errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            tk_messageBox -icon error -title "Connection Error" \
                -message "PostgreSQL connection error.\n\n$errorMsg\n\nPlease check your PostgreSQL service."
            return
        }
        log_message $text "⚠️ Warning: Could not drop database: $errorMsg" 
        log_message $text "   Continuing with create..." 
    } else {
        log_message $text "✅ Database dropped successfully (if it existed)" 
    }
    
    # Step 2: Create database
    log_message $text "\n📌 Step 3: Creating new database..." 
    
    if {[catch {
        exec_psql -d postgres -c "CREATE DATABASE $::DB_NAME WITH OWNER = $::DB_USER ENCODING = 'UTF8';"
    } errorMsg]} {
        log_message $text "❌ ERROR creating database: $errorMsg" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "Failed to create database!\n\nError: $errorMsg"
        return
    }
    log_message $text "✅ Database '$::DB_NAME' created successfully" 
    
    # Step 3: Run schema creation
    log_message $text "\n📌 Step 4: Running schema creation..." 
    log_message $text "   This may take a few moments..." 
    
    if {[catch {
        exec_psql -d $::DB_NAME -f $SQL_FILE
    } errorMsg]} {
        log_message $text "❌ ERROR running schema: $errorMsg" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "Failed to create schema!\n\nError: $errorMsg"
        return
    }
    log_message $text "✅ Schema created successfully" 
    
    # Step 4: Verify installation
    log_message $text "\n📌 Step 5: Verifying installation..." 
    
    if {[catch {
        set result [exec_psql -d $::DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"]
        set result [string trim $result]
        log_message $text "✅ Tables found: $result" 
    } errorMsg]} {
        log_message $text "⚠️ Could not verify tables: $errorMsg" 
    } else {
        # Check for specific tables
        set tables [list "persons_roles" "persons" "formulations" "production_batches" "qc_tests" "users"]
        foreach table $tables {
            if {[catch {
                set count [exec_psql -d $::DB_NAME -t -c "SELECT COUNT(*) FROM $table"]
                set count [string trim $count]
                if {$count ne "" && $count != "0"} {
                    log_message $text "   - $table: $count rows" 
                } elseif {$count == "0"} {
                    log_message $text "   - $table: empty (created)" 
                } else {
                    log_message $text "   - $table: created" 
                }
            } errorMsg]} {
                log_message $text "   - $table: NOT FOUND" 
            }
        }
    }
    
    # Step 5: Check admin user
    log_message $text "\n📌 Step 6: Checking admin user..." 
    
    if {[catch {
        set count [exec_psql -d $::DB_NAME -t -c "SELECT COUNT(*) FROM users WHERE username = 'admin'"]
        set count [string trim $count]
        if {$count > 0} {
            log_message $text "✅ Admin user found (username: admin, password: admin)" 
        } else {
            log_message $text "⚠️ Admin user not found. Please check the schema." 
        }
    } errorMsg]} {
        log_message $text "⚠️ Could not check admin user: $errorMsg" 
    }
    
    # Summary
    log_message $text "\n========================================" 
    log_message $text "✅ INSTALLATION COMPLETE!" 
    log_message $text "========================================" 
    log_message $text "\n📋 Database: $::DB_NAME" 
    log_message $text "📋 Host: $::DB_HOST:$::DB_PORT" 
    log_message $text "📋 User: $::DB_USER" 
    log_message $text "\n🔐 Default admin login:" 
    log_message $text "   Username: admin" 
    log_message $text "   Password: admin" 
    log_message $text "\n⚠️ Please change the admin password after first login!" 
    
    $progress stop
    $w.main.buttons.install configure -state normal
    
    tk_messageBox -icon info -title "Installation Complete" \
        -message "✅ Database installation completed successfully!\n\nDatabase: $::DB_NAME\nHost: $::DB_HOST:$::DB_PORT\nUser: $::DB_USER\n\nDefault admin login:\nUsername: admin\nPassword: admin"
}

# ============================================
# Configuration Dialog
# ============================================

proc show_config_dialog {} {
    set w .config
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Database Configuration"
    wm geometry $w "550x500"
    wm resizable $w 0 0
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 550) / 2}]
    set y [expr {([winfo screenheight .] - 500) / 2}]
    wm geometry $w "+$x+$y"
    
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "⚙️ Database Configuration" -font {Arial 14 bold}
    pack $main.title -pady 10
    
    ttk::label $main.subtitle -text "Configure PostgreSQL connection settings" -font {Arial 10} -foreground gray
    pack $main.subtitle -pady 5
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    # Configuration fields
    set fields [list \
        "Host:" "host" "localhost" \
        "Port:" "port" "5432" \
        "Database:" "db" "toothpastes" \
        "Username:" "user" "postgres" \
        "Password:" "pass" "" \
        "PostgreSQL Path:" "pgpath" "C:/Program Files/PostgreSQL/14/bin" \
    ]
    
    # Create entries array
    array set entries {}
    
    for {set i 0} {$i < [llength $fields]} {incr i 3} {
        set label [lindex $fields $i]
        set var [lindex $fields [expr {$i + 1}]]
        set default [lindex $fields [expr {$i + 2}]]
        
        set f [ttk::frame $main.f_$var]
        pack $f -fill x -pady 4
        
        ttk::label $f.lbl -text $label -width 18 -anchor e -font {Arial 10}
        pack $f.lbl -side left -padx 5
        
        if {$var eq "pass"} {
            set entry [ttk::entry $f.entry -width 30 -show "*" -font {Arial 10}]
        } else {
            set entry [ttk::entry $f.entry -width 30 -font {Arial 10}]
        }
        pack $entry -side left -expand true -fill x
        $entry insert 0 $default
        set entries($var) $entry
    }
    
    # Check PostgreSQL button
    set check_frame [ttk::frame $main.check]
    pack $check_frame -fill x -pady 10
    
    ttk::button $check_frame.check -text "🔍 Check PostgreSQL" -command [list check_postgres_path] -padding "8 4"
    pack $check_frame.check -side left -padx 5
    
    ttk::label $check_frame.status -text "" -font {Arial 9}
    pack $check_frame.status -side left -padx 10
    
    # Connection test button
    ttk::button $check_frame.test -text "🔌 Test Connection" -command [list test_connection_config] -padding "8 4"
    pack $check_frame.test -side left -padx 5
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 15
    
    ttk::button $btn_frame.save -text "✅ Save & Continue" -command [list save_config] -padding "10 5"
    pack $btn_frame.save -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "10 5"
    pack $btn_frame.cancel -side right -expand true -fill x -padx 5
    
    # Store the entries array in global scope for access by other procs
    global config_entries
    array set config_entries [array get entries]
}

proc check_postgres_path {} {
    global config_entries PG_PATH
    
    set path [$config_entries(pgpath) get]
    set PG_PATH $path
    
    set psql_exe [check_postgres]
    if {$psql_exe ne ""} {
        set status .config.main.check.status
        $status configure -text "✅ Found PostgreSQL at: $psql_exe" -foreground green
        tk_messageBox -icon info -title "PostgreSQL Found" \
            -message "Found PostgreSQL client at:\n$psql_exe"
    } else {
        set status .config.main.check.status
        $status configure -text "❌ PostgreSQL not found. Please check the path." -foreground red
        tk_messageBox -icon warning -title "PostgreSQL Not Found" \
            -message "PostgreSQL client (psql) not found.\n\nPlease check the path and try again."
    }
}

proc test_connection_config {} {
    global config_entries DB_HOST DB_PORT DB_USER DB_PASS
    
    # Get values from the configuration dialog
    set DB_HOST [$config_entries(host) get]
    set DB_PORT [$config_entries(port) get]
    set DB_USER [$config_entries(user) get]
    set DB_PASS [$config_entries(pass) get]
    
    # Test the connection
    set result [test_postgres_connection]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {$status} {
        # Extract just the PostgreSQL version from the output
        set version ""
        foreach line [split $message "\n"] {
            if {[string match "*PostgreSQL*" $line]} {
                set version [string trim $line]
                break
            }
        }
        if {$version eq ""} {
            set version "PostgreSQL server is running and accessible"
        }
        
        tk_messageBox -icon info -title "✅ Connection Successful" \
            -message "Successfully connected to PostgreSQL!\n\n$version\n\nConnection Details:\nHost: $DB_HOST\nPort: $DB_PORT\nUser: $DB_USER"
    } else {
        # Show detailed error message with troubleshooting tips
        set error_msg "❌ Connection Failed!\n\nError Details:\n$message\n\n─────────────────────────────\n\nTroubleshooting Tips:\n"
        append error_msg "• Make sure PostgreSQL service is running\n"
        append error_msg "  (Windows: Check Services - services.msc)\n"
        append error_msg "  (Linux/Mac: sudo systemctl status postgresql)\n"
        append error_msg "• Verify host and port are correct\n"
        append error_msg "  (Default: localhost:5432)\n"
        append error_msg "• Check username and password\n"
        append error_msg "  (Default user: postgres)\n"
        append error_msg "• Make sure PostgreSQL accepts connections\n"
        append error_msg "  (Check pg_hba.conf configuration)\n"
        append error_msg "• Verify PostgreSQL is installed correctly"
        
        tk_messageBox -icon error -title "❌ Connection Failed" \
            -message $error_msg
    }
}

proc save_config {} {
    global config_entries DB_HOST DB_PORT DB_NAME DB_USER DB_PASS PG_PATH
    
    set DB_HOST [$config_entries(host) get]
    set DB_PORT [$config_entries(port) get]
    set DB_NAME [$config_entries(db) get]
    set DB_USER [$config_entries(user) get]
    set DB_PASS [$config_entries(pass) get]
    set PG_PATH [$config_entries(pgpath) get]
    
    # Test connection first
    set result [test_postgres_connection]
    set status [lindex $result 0]
    
    if {!$status} {
        set message [lindex $result 1]
        tk_messageBox -icon warning -title "Connection Warning" \
            -message "Cannot connect to PostgreSQL at $DB_HOST:$DB_PORT\n\n$message\n\nPlease fix the connection settings and try again."
        return
    }
    
    destroy .config
    install_database
}

# ============================================
# Command-line mode
# ============================================

proc run_command_line {} {
    global DB_HOST DB_PORT DB_NAME DB_USER DB_PASS PG_PATH SQL_FILE
    
    puts "🚀 Toothpaste Database Installation (Command Line)"
    puts "================================================"
    puts ""

    # Test connection first
    puts "📋 Testing PostgreSQL connection..."
    set result [test_postgres_connection]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {!$status} {
        puts "❌ $message"
        puts ""
        puts "Please check:"
        puts "1. PostgreSQL service is running"
        puts "2. Host and port are correct"
        puts "3. Username and password are correct"
        puts "4. PostgreSQL is accepting connections"
        exit 1
    }
    puts "✅ PostgreSQL connection successful"
    
    # Check PostgreSQL client
    puts "📋 Checking PostgreSQL client..."
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        puts "❌ ERROR: PostgreSQL client (psql) not found!"
        puts "   Please install PostgreSQL or set PG_PATH."
        exit 1
    }
    puts "✅ Found PostgreSQL client: $psql_exe"
    
    # Check SQL file
    if {![file exists $SQL_FILE]} {
        puts "❌ ERROR: SQL file '$SQL_FILE' not found!"
        exit 1
    }
    puts "✅ Found SQL file: $SQL_FILE"
    
    # Drop database
    puts "\n📌 Dropping existing database..."
    if {[catch {exec_psql -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"} errorMsg]} {
        puts "⚠️ Warning: $errorMsg"
    } else {
        puts "✅ Database dropped (if it existed)"
    }
    
    # Create database
    puts "\n📌 Creating new database..."
    if {[catch {exec_psql -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8';"} errorMsg]} {
        puts "❌ ERROR: $errorMsg"
        exit 1
    }
    puts "✅ Database created"
    
    # Run schema
    puts "\n📌 Creating schema..."
    if {[catch {exec_psql -d $DB_NAME -f $SQL_FILE} errorMsg]} {
        puts "❌ ERROR: $errorMsg"
        exit 1
    }
    puts "✅ Schema created"
    
    # Verify
    puts "\n📌 Verifying installation..."
    if {[catch {set result [exec_psql -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"]} errorMsg]} {
        puts "⚠️ Could not verify tables: $errorMsg"
    } else {
        puts "✅ Tables found: [string trim $result]"
    }
    
    puts "\n✅ INSTALLATION COMPLETE!"
    puts "================================================"
    puts "📋 Database: $DB_NAME"
    puts "📋 Host: $DB_HOST:$DB_PORT"
    puts "📋 User: $DB_USER"
    puts ""
    puts "🔐 Default admin login:"
    puts "   Username: admin"
    puts "   Password: admin"
    puts "================================================"
}

# ============================================
# Main Entry Point
# ============================================

# Check if running with GUI or command line
if {[info exists ::argv] && [lsearch -exact $::argv "--cli"] != -1} {
    # Command line mode
    run_command_line
} else {
    # GUI mode
    if {[catch {package require Tk}]} {
        puts "Tk not available. Running in command line mode..."
        run_command_line
    } else {
        # Show configuration dialog first
        show_config_dialog
        
        # Enter Tk event loop
        vwait forever
    }
}