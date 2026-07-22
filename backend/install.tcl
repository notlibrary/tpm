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
set DB_PASS ""               ;# Will be read from entry
set PG_PATH "C:/Program Files/PostgreSQL/14/bin"
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
        lappend possible_paths "C:/Program Files/PostgreSQL/17/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/18/bin"
        lappend possible_paths "C:/Program Files (x86)/PostgreSQL/14/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/13/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/12/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/11/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/10/bin"
        lappend possible_paths "C:/Program Files/PostgreSQL/9.6/bin"
        lappend possible_paths "C:/Program Files (x86)/PostgreSQL/9.6/bin"
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
    
    return ""
}

# Find PostgreSQL installation
proc find_postgres_installation {} {
    set found_paths [list]
    
    set common_paths [list \
        "C:/Program Files/PostgreSQL/18/bin" \
        "C:/Program Files/PostgreSQL/17/bin" \
        "C:/Program Files/PostgreSQL/16/bin" \
        "C:/Program Files/PostgreSQL/15/bin" \
        "C:/Program Files/PostgreSQL/14/bin" \
        "C:/Program Files/PostgreSQL/13/bin" \
        "C:/Program Files/PostgreSQL/12/bin" \
        "C:/Program Files/PostgreSQL/11/bin" \
        "C:/Program Files/PostgreSQL/10/bin" \
        "C:/Program Files (x86)/PostgreSQL/14/bin" \
        "C:/Program Files (x86)/PostgreSQL/13/bin" \
    ]
    
    foreach path $common_paths {
        set psql_exe [file join $path "psql.exe"]
        if {[file exists $psql_exe]} {
            lappend found_paths $path
        }
    }
    
    return $found_paths
}

# Test PostgreSQL connection with provided password
proc test_postgres_connection {{password ""}} {
    global DB_HOST DB_PORT DB_USER
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        return [list 0 "PostgreSQL client (psql) not found.\n\nPlease install PostgreSQL or set the correct path."]
    }
    
    if {$password eq ""} {
        return [list 0 "No password provided.\n\nPlease enter a password."]
    }
    
    set password [string trim $password]
    
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    lappend cmd -d postgres
    lappend cmd -c "SELECT version()"
    lappend cmd --no-password
    
    set ::env(PGPASSWORD) $password
    set ::env(pgpassword) $password
    
    # Merge stderr to stdout for full error capture
    set result [catch {exec {*}$cmd 2>@1} output]
    
    if {$result != 0} {
        if {[string match "*password*" $output]} {
            return [list 0 "Incorrect password.\n\nPlease try a different password."]
        }
        if {[string match "*Connection refused*" $output]} {
            return [list 0 "PostgreSQL is not running on $DB_HOST:$DB_PORT\n\nPlease start PostgreSQL first."]
        }
        return [list 0 "Connection failed: $output"]
    }
    
    return [list 1 $output]
}

# Execute PostgreSQL command - enhanced error handling
proc exec_psql {args} {
    global DB_HOST DB_PORT DB_USER DB_PASS
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        error "PostgreSQL client (psql) not found."
    }
    
    set password [string trim $DB_PASS]
    if {$password eq ""} {
        error "Password not set. Please enter a password."
    }
    
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    lappend cmd -v ON_ERROR_STOP=1   ;# Stop on first SQL error
    lappend cmd --no-password
    
    foreach arg $args {
        lappend cmd $arg
    }
    
    set ::env(PGPASSWORD) $password
    set ::env(pgpassword) $password
    
    puts "DEBUG: Executing: [lrange $cmd 0 end]"
    
    # Merge stderr into stdout to capture all output
    set result [catch {exec {*}$cmd 2>@1} output]
    
    if {$result != 0} {
        # Check if the output contains an actual ERROR (case-insensitive)
        if {[regexp -nocase {ERROR:} $output]} {
            error "Command failed: $output"
        } else {
            # Non-zero exit but no ERROR: likely just notices/warnings
            puts "DEBUG: psql returned non-zero but no ERROR found. Output: $output"
            return $output
        }
    }
    
    return $output
}

# ============================================
# Main Installation Window
# ============================================

proc install_database {} {
    global SQL_FILE DB_PASS
    
    set w .install
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Toothpaste Database Installation"
    wm geometry $w "750x750"
    wm resizable $w 0 0
    wm protocol $w WM_DELETE_WINDOW {exit}
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 750) / 2}]
    set y [expr {([winfo screenheight .] - 750) / 2}]
    wm geometry $w "+$x+$y"
    
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    # Title
    ttk::label $main.title -text "🧴 Toothpaste Database Installation" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    ttk::label $main.subtitle -text "Enter connection details and click Install" -font {Arial 10} -foreground gray
    pack $main.subtitle -pady 5
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    # Connection Settings Frame
    set conn_frame [ttk::labelframe $main.conn -text "Connection Settings" -padding "10 10 10 10"]
    pack $conn_frame -fill x -pady 5
    
    # Host
    set host_frame [ttk::frame $conn_frame.host]
    pack $host_frame -fill x -pady 2
    ttk::label $host_frame.lbl -text "Host:" -width 12
    pack $host_frame.lbl -side left
    ttk::entry $host_frame.entry -textvariable ::DB_HOST -width 30
    pack $host_frame.entry -side left -expand true -fill x
    
    # Port
    set port_frame [ttk::frame $conn_frame.port]
    pack $port_frame -fill x -pady 2
    ttk::label $port_frame.lbl -text "Port:" -width 12
    pack $port_frame.lbl -side left
    ttk::entry $port_frame.entry -textvariable ::DB_PORT -width 30
    pack $port_frame.entry -side left -expand true -fill x
    
    # Database
    set db_frame [ttk::frame $conn_frame.db]
    pack $db_frame -fill x -pady 2
    ttk::label $db_frame.lbl -text "Database:" -width 12
    pack $db_frame.lbl -side left
    ttk::entry $db_frame.entry -textvariable ::DB_NAME -width 30
    pack $db_frame.entry -side left -expand true -fill x
    
    # Username
    set user_frame [ttk::frame $conn_frame.user]
    pack $user_frame -fill x -pady 2
    ttk::label $user_frame.lbl -text "Username:" -width 12
    pack $user_frame.lbl -side left
    ttk::entry $user_frame.entry -textvariable ::DB_USER -width 30
    pack $user_frame.entry -side left -expand true -fill x
    
    # Password
    set pass_frame [ttk::frame $conn_frame.pass]
    pack $pass_frame -fill x -pady 2
    ttk::label $pass_frame.lbl -text "Password:" -width 12
    pack $pass_frame.lbl -side left
    
    set pass_entry [ttk::entry $pass_frame.entry -width 25 -show "*" -font {Arial 10}]
    pack $pass_entry -side left -expand true -fill x
    bind $pass_entry <KeyRelease> [list update_password $pass_entry]
    
    ttk::button $pass_frame.show -text "👁" -width 3 -command [list toggle_password $pass_entry]
    pack $pass_frame.show -side left -padx 2
    
    set ::password_entry $pass_entry
    
    # PostgreSQL Path
    set path_frame [ttk::frame $conn_frame.path]
    pack $path_frame -fill x -pady 2
    ttk::label $path_frame.lbl -text "PG Path:" -width 12
    pack $path_frame.lbl -side left
    ttk::entry $path_frame.entry -textvariable ::PG_PATH -width 30
    pack $path_frame.entry -side left -expand true -fill x
    
    ttk::separator $main.sep2 -orient horizontal
    pack $main.sep2 -fill x -pady 10
    
    # Status Log
    set status_frame [ttk::frame $main.status]
    pack $status_frame -fill both -expand true -pady 5
    
    ttk::label $status_frame.title -text "Installation Log:" -font {Arial 10 bold}
    pack $status_frame.title -anchor w
    
    set text [text $status_frame.log -wrap word -font {Courier 10} -height 15 -yscrollcommand "$status_frame.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $status_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Progress bar
    set progress [ttk::progressbar $main.progress -mode indeterminate -length 500]
    pack $progress -fill x -pady 10
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.test -text "🔍 Test Connection" -command [list test_connection_proc $text] -padding "10 5"
    pack $btn_frame.test -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.detect -text "🔎 Detect PostgreSQL" -command [list detect_postgres_proc $text] -padding "10 5"
    pack $btn_frame.detect -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.install -text "🚀 Install Database" -command [list install_db_proc $text $progress $w] -padding "10 5"
    pack $btn_frame.install -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.close -text "❌ Close" -command "destroy $w" -padding "10 5"
    pack $btn_frame.close -side right -expand true -fill x -padx 5
    
    set ::install_text $text
    set ::install_progress $progress
    
    focus $pass_entry
}

# ============================================
# GUI Helper Procedures
# ============================================

proc update_password {entry} {
    global DB_PASS
    set DB_PASS [$entry get]
    puts "DEBUG: Password updated (length: [string length $DB_PASS])"
}

proc toggle_password {entry} {
    if {[$entry cget -show] eq "*"} {
        $entry configure -show ""
    } else {
        $entry configure -show "*"
    }
}

proc log_message {text msg {color "black"}} {
    $text insert end "$msg\n" $color
    $text see end
    update idletasks
}

# ============================================
# Button Callbacks
# ============================================

proc detect_postgres_proc {text} {
    log_message $text "🔎 Detecting PostgreSQL installation..." 
    log_message $text "========================================" 
    
    set psql_exe [check_postgres]
    if {$psql_exe ne ""} {
        log_message $text "✅ Found PostgreSQL client: $psql_exe" 
        set dir [file dirname $psql_exe]
        log_message $text "   Path: $dir" 
        global PG_PATH
        set PG_PATH $dir
    } else {
        log_message $text "❌ PostgreSQL client not found!" 
        set found_paths [find_postgres_installation]
        if {[llength $found_paths] > 0} {
            log_message $text "Found installations:" 
            foreach path $found_paths {
                log_message $text "   - $path" 
            }
        }
    }
    
    tk_messageBox -icon info -title "Detection Complete" \
        -message "Detection finished. Check the log for details."
}

proc test_connection_proc {text} {
    global DB_PASS DB_USER DB_HOST DB_PORT
    
    if {[info exists ::password_entry]} {
        set DB_PASS [$::password_entry get]
    }
    
    log_message $text "🔍 Testing PostgreSQL connection..." 
    log_message $text "========================================" 
    log_message $text "   Host: $DB_HOST" 
    log_message $text "   Port: $DB_PORT" 
    log_message $text "   User: $DB_USER" 
    if {$DB_PASS ne ""} {
        log_message $text "   Password: [string repeat "*" [string length $DB_PASS]]" 
        puts "DEBUG: Test with password length: [string length $DB_PASS]"
    } else {
        log_message $text "   Password: (empty)" 
    }
    
    if {$DB_PASS eq ""} {
        log_message $text "❌ No password entered!" 
        tk_messageBox -icon warning -title "Password Required" \
            -message "Please enter a password."
        return
    }
    
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {$status} {
        log_message $text "✅ Connection successful!" 
        log_message $text "$message" 
        tk_messageBox -icon info -title "✅ Connection Successful" \
            -message "Successfully connected!\n\n$message"
    } else {
        log_message $text "❌ Connection failed!" 
        log_message $text "$message" 
        tk_messageBox -icon error -title "❌ Connection Failed" \
            -message "Connection failed.\n\n$message"
    }
}

proc install_db_proc {text progress w} {
    global DB_PASS
    
    if {[info exists ::password_entry]} {
        set DB_PASS [$::password_entry get]
    }
    
    if {$DB_PASS eq ""} {
        tk_messageBox -icon warning -title "Password Required" \
            -message "Please enter a password."
        return
    }
    
    $w.main.buttons.install configure -state disabled
    $progress start
    
    log_message $text "🚀 Starting database installation..." 
    log_message $text "========================================" 
    log_message $text "   Password length: [string length $DB_PASS]" 
    puts "DEBUG: Install with password length: [string length $DB_PASS]"
    
    # Step 0: Test connection first
    log_message $text "\n📌 Step 0: Testing connection..." 
    set conn_test [test_postgres_connection $DB_PASS]
    set conn_status [lindex $conn_test 0]
    set conn_message [lindex $conn_test 1]
    
    if {!$conn_status} {
        log_message $text "❌ Connection failed!" 
        log_message $text "$conn_message" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Connection Error" \
            -message "Cannot connect.\n\n$conn_message"
        return
    }
    log_message $text "✅ Connection successful" 
    
    # Check SQL file
    global SQL_FILE
    if {![file exists $SQL_FILE]} {
        log_message $text "❌ ERROR: SQL file '$SQL_FILE' not found!" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "SQL file not found: $SQL_FILE"
        return
    }
    log_message $text "✅ Found SQL file: $SQL_FILE" 
    
    # Drop database if exists
    log_message $text "\n📌 Dropping existing database..." 
    if {[catch {
        exec_psql -d postgres -c "DROP DATABASE IF EXISTS $::DB_NAME;"
    } errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            log_message $text "❌ Error dropping: $errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            tk_messageBox -icon error -title "Drop Error" \
                -message "Failed to drop database.\n\n$errorMsg"
            return
        }
        log_message $text "⚠️ Could not drop: $errorMsg" 
    } else {
        log_message $text "✅ Dropped (if existed)" 
    }
    
    # Create database
    log_message $text "\n📌 Creating database..." 
    if {[catch {
        exec_psql -d postgres -c "CREATE DATABASE $::DB_NAME WITH OWNER = $::DB_USER ENCODING = 'UTF8';"
    } errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            log_message $text "❌ Error creating: $errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            tk_messageBox -icon error -title "Create Error" \
                -message "Failed to create database.\n\n$errorMsg"
            return
        }
        log_message $text "❌ Unexpected error: $errorMsg" 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "Failed to create database.\n\n$errorMsg"
        return
    }
    log_message $text "✅ Database created" 
    
    # Test connection to new database
    log_message $text "\n📌 Testing connection to new database..." 
    if {[catch {
        exec_psql -d $::DB_NAME -c "SELECT 1"
    } errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            log_message $text "❌ Cannot connect to new DB: $errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            tk_messageBox -icon error -title "Connection Error" \
                -message "Cannot connect to the newly created database.\n\n$errorMsg"
            return
        }
        log_message $text "⚠️ Connection test warning: $errorMsg" 
    } else {
        log_message $text "✅ Connection to new database successful" 
    }
    
    # Run schema
    log_message $text "\n📌 Creating schema..." 
    if {[catch {
        exec_psql -d $::DB_NAME -f $SQL_FILE
    } errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            log_message $text "❌ ERROR creating schema:" 
            log_message $text "$errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            tk_messageBox -icon error -title "Schema Error" \
                -message "Failed to create schema.\n\n$errorMsg"
            return
        }
        # Non-error case: log as success
        log_message $text "✅ Schema created (with warnings/notices)" 
        log_message $text "$errorMsg" 
    } else {
        log_message $text "✅ Schema created" 
    }
    
    # Verify
    log_message $text "\n📌 Verifying..." 
    if {[catch {
        set result [exec_psql -d $::DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"]
        set result [string trim $result]
        log_message $text "✅ Tables found: $result" 
    } errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            log_message $text "⚠️ Could not verify: $errorMsg" 
        } else {
            log_message $text "⚠️ Could not verify: $errorMsg" 
        }
    }
    
    log_message $text "\n========================================" 
    log_message $text "✅ INSTALLATION COMPLETE!" 
    log_message $text "========================================" 
    log_message $text "\n📋 Database: $::DB_NAME" 
    log_message $text "📋 Host: $::DB_HOST:$::DB_PORT" 
    log_message $text "📋 User: $::DB_USER" 
    log_message $text "📋 Password: [string repeat "*" [string length $DB_PASS]]" 
    log_message $text "\n🔐 Default admin login:" 
    log_message $text "   Username: admin" 
    log_message $text "   Password: admin" 
    log_message $text "\n⚠️ Change admin password after first login!" 
    
    $progress stop
    $w.main.buttons.install configure -state normal
    
    tk_messageBox -icon info -title "Installation Complete" \
        -message "✅ Database installation completed!\n\nDatabase: $::DB_NAME\nHost: $::DB_HOST:$::DB_PORT\nUser: $::DB_USER\n\nDefault admin login:\nUsername: admin\nPassword: admin"
}

# ============================================
# Main Entry Point
# ============================================

if {[info exists ::argv] && [lsearch -exact $::argv "--cli"] != -1} {
    # Command line mode
    puts "🚀 Toothpaste Database Installation (Command Line)"
    puts "================================================"
    puts ""
    puts -nonewline "Enter PostgreSQL password for user 'postgres': "
    flush stdout
    if {$::tcl_platform(platform) ne "windows"} {
        exec stty -echo
        gets stdin DB_PASS
        exec stty echo
        puts ""
    } else {
        gets stdin DB_PASS
    }
    
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    if {!$status} {
        puts "❌ Connection failed: [lindex $result 1]"
        exit 1
    }
    puts "✅ Connection successful"
    
    if {![file exists $SQL_FILE]} {
        puts "❌ SQL file not found!"
        exit 1
    }
    
    puts "\n📌 Creating database..."
    if {[catch {exec_psql -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8';"} errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            puts "❌ ERROR: $errorMsg"
            exit 1
        } else {
            puts "⚠️ Warning: $errorMsg"
        }
    }
    puts "✅ Database created"
    
    puts "\n📌 Creating schema..."
    if {[catch {exec_psql -d $DB_NAME -f $SQL_FILE} errorMsg]} {
        if {[regexp -nocase {ERROR:} $errorMsg]} {
            puts "❌ ERROR: $errorMsg"
            exit 1
        } else {
            puts "✅ Schema created (with warnings/notices)"
        }
    } else {
        puts "✅ Schema created"
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
    exit 0
} else {
    # GUI mode
    if {[catch {package require Tk}]} {
        puts "Tk not available. Running in command line mode..."
        # Fallback command line...
        puts -nonewline "Enter PostgreSQL password for user 'postgres': "
        flush stdout
        gets stdin DB_PASS
        set result [test_postgres_connection $DB_PASS]
        set status [lindex $result 0]
        if {!$status} {
            puts "❌ Connection failed: [lindex $result 1]"
            exit 1
        }
        if {[file exists $SQL_FILE]} {
            exec_psql -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8';"
            exec_psql -d $DB_NAME -f $SQL_FILE
            puts "✅ Installation complete!"
        } else {
            puts "❌ SQL file not found!"
        }
    } else {
        install_database
        vwait forever
    }
}