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
set DB_PASS "arizona42"
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

# Try to find PostgreSQL installation
proc find_postgres_installation {} {
    global PG_PATH
    
    set found_paths [list]
    
    # Check common paths
    set common_paths [list \
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

# Test PostgreSQL connection with various settings
proc test_postgres_connection {{password ""}} {
    global DB_HOST DB_PORT DB_USER
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        return [list 0 "PostgreSQL client (psql) not found.\n\nPlease install PostgreSQL or set the correct path."]
    }
    
    # Use provided password or global
    if {$password eq ""} {
        global DB_PASS
        set password $DB_PASS
    }
    
    # Try to connect with current settings
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    lappend cmd -d postgres
    lappend cmd -c "SELECT version()"
    
    # Set password via environment variable
    if {$password ne ""} {
        set env(PGPASSWORD) $password
    } else {
        catch {unset env(PGPASSWORD)}
    }
    
    # Add --no-password flag to prevent password prompt
    lappend cmd --no-password
    
    set result [catch {exec {*}$cmd} output]
    
    if {$result != 0} {
        # Check if error contains password prompt message
        if {[string match "*password*" $output]} {
            return [list 0 "Incorrect password.\n\nPlease try a different password."]
        }
        if {[string match "*Connection refused*" $output]} {
            return [list 0 "PostgreSQL is not running on $DB_HOST:$DB_PORT\n\nPlease start PostgreSQL first."]
        }
        if {[string match "*does not exist*" $output]} {
            return [list 0 "Database 'postgres' does not exist.\n\nPlease check your PostgreSQL installation."]
        }
        return [list 0 "Connection failed: $output"]
    }
    
    return [list 1 $output]
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
    wm geometry $w "750x650"
    wm resizable $w 0 0
    wm protocol $w WM_DELETE_WINDOW {exit}
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 750) / 2}]
    set y [expr {([winfo screenheight .] - 650) / 2}]
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
    
    ttk::button $btn_frame.detect -text "🔎 Detect PostgreSQL" -command [list detect_postgres_proc $text] -padding "10 5"
    pack $btn_frame.detect -side left -expand true -fill x -padx 5
    
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

proc detect_postgres_proc {text} {
    log_message $text "🔎 Detecting PostgreSQL installation..." 
    log_message $text "========================================" 
    
    # Find PostgreSQL installations
    set found_paths [find_postgres_installation]
    
    if {[llength $found_paths] > 0} {
        log_message $text "✅ Found PostgreSQL installations:" 
        foreach path $found_paths {
            log_message $text "   - $path" 
        }
    } else {
        log_message $text "❌ No PostgreSQL installations found in common paths!" 
    }
    
    # Check current path
    global PG_PATH
    set psql_exe [check_postgres]
    if {$psql_exe ne ""} {
        log_message $text "✅ Current PostgreSQL client: $psql_exe" 
    } else {
        log_message $text "❌ PostgreSQL client not found at: $PG_PATH" 
    }
    
    # Check if service is running
    if {$::tcl_platform(platform) eq "windows"} {
        catch {
            set output [exec sc query state= all]
            set lines [split $output "\n"]
            set postgres_services [list]
            
            foreach line $lines {
                if {[string match "*postgres*" [string tolower $line]]} {
                    lappend postgres_services [string trim $line]
                }
            }
            
            if {[llength $postgres_services] > 0} {
                log_message $text "✅ PostgreSQL services found:" 
                foreach service $postgres_services {
                    log_message $text "   - $service" 
                }
            } else {
                log_message $text "⚠️ No PostgreSQL services found in services.msc" 
            }
        }
    }
    
    tk_messageBox -icon info -title "Detection Complete" \
        -message "PostgreSQL detection complete.\n\nCheck the log for details.\n\nIf PostgreSQL is installed but not found, please set the correct path in the configuration."
}

proc test_connection_proc {text} {
    global DB_PASS DB_USER DB_HOST DB_PORT
    
    log_message $text "🔍 Testing PostgreSQL connection..." 
    log_message $text "========================================" 
    log_message $text "   Host: $DB_HOST" 
    log_message $text "   Port: $DB_PORT" 
    log_message $text "   User: $DB_USER" 
    
    # If no password set, ask for it
    if {$DB_PASS eq ""} {
        set DB_PASS [get_password_dialog "Enter PostgreSQL Password" "Please enter the password for user '$DB_USER':\n\nIf you don't know the password, try:\n- Empty (no password)\n- postgres\n- The password you set during installation"]
        if {$DB_PASS eq ""} {
            log_message $text "⚠️ No password entered. Trying empty password..." 
        }
    }
    
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {$status} {
        log_message $text "✅ Connection successful!" 
        log_message $text "$message" 
        tk_messageBox -icon info -title "✅ Connection Successful" \
            -message "Successfully connected to PostgreSQL!\n\n$message\n\nPassword works!"
    } else {
        log_message $text "❌ Connection failed!" 
        log_message $text "$message" 
        
        # Try common passwords
        log_message $text "   Trying common passwords..." 
        set common_passwords [list "" "postgres" "admin" "password" "123456" "root"]
        
        foreach pwd $common_passwords {
            if {$pwd eq $DB_PASS} continue
            log_message $text "   Trying password: '$pwd'" 
            set result [test_postgres_connection $pwd]
            set status [lindex $result 0]
            if {$status} {
                log_message $text "✅ Found working password: '$pwd'" 
                set DB_PASS $pwd
                tk_messageBox -icon info -title "Password Found" \
                    -message "✅ Found working password!\n\nPassword: '$pwd'\n\nThis password works for user '$DB_USER'."
                return
            }
        }
        
        # If we get here, none of the common passwords worked
        set DB_PASS ""
        tk_messageBox -icon error -title "❌ Connection Failed" \
            -message "PostgreSQL connection test failed.\n\n$message\n\nTried common passwords but none worked.\n\nPlease check:\n1. PostgreSQL is running\n2. Host and port are correct\n3. Username is correct\n4. Password is correct\n\nYou may need to reset your PostgreSQL password."
    }
}

proc get_password_dialog {title message} {
    set w .password_dialog
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w $title
    wm geometry $w "450x200"
    wm resizable $w 0 0
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 450) / 2}]
    set y [expr {([winfo screenheight .] - 200) / 2}]
    wm geometry $w "+$x+$y"
    
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    ttk::label $main.message -text $message -font {Arial 10} -wraplength 400 -justify left
    pack $main.message -pady 5
    
    set pass_entry [ttk::entry $main.password -width 30 -show "*" -font {Arial 10}]
    pack $pass_entry -pady 10 -fill x
    
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 5
    
    ttk::button $btn_frame.ok -text "OK" -command [list set ::password_result [$pass_entry get]] -padding "10 5"
    pack $btn_frame.ok -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.cancel -text "Cancel" -command [list set ::password_result ""] -padding "10 5"
    pack $btn_frame.cancel -side right -expand true -fill x -padx 5
    
    ttk::button $btn_frame.empty -text "Try Empty" -command [list set ::password_result ""] -padding "10 5"
    pack $btn_frame.empty -side right -expand true -fill x -padx 5
    
    bind $w <Return> [list set ::password_result [$pass_entry get]]
    focus $pass_entry
    
    # Wait for the dialog to close
    tkwait window $w
    
    # Return the password
    if {[info exists ::password_result]} {
        set result $::password_result
        unset ::password_result
        return $result
    }
    return ""
}

proc install_db_proc {text progress w} {
    # Disable install button
    $w.main.buttons.install configure -state disabled
    $progress start
    
    log_message $text "🚀 Starting database installation..." 
    log_message $text "========================================" 
    
    # Check if password is set
    global DB_PASS DB_USER DB_HOST DB_PORT
    
    # If no password set, ask for it
    if {$DB_PASS eq ""} {
        set DB_PASS [get_password_dialog "Enter PostgreSQL Password" "Please enter the password for user '$DB_USER':\n\nIf you don't know the password, try:\n- Empty (no password)\n- postgres\n- The password you set during installation"]
        if {$DB_PASS eq ""} {
            log_message $text "⚠️ No password entered. Trying empty password..." 
        }
    }
    
    # Step 0: Test connection first
    log_message $text "\n📌 Step 0: Testing PostgreSQL connection..." 
    set conn_test [test_postgres_connection $DB_PASS]
    set conn_status [lindex $conn_test 0]
    set conn_message [lindex $conn_test 1]
    
    if {!$conn_status} {
        log_message $text "❌ PostgreSQL connection failed!" 
        log_message $text "$conn_message" 
        $progress stop
        $w.main.buttons.install configure -state normal
        
        # Try common passwords
        log_message $text "   Trying common passwords..." 
        set common_passwords [list "" "postgres" "admin" "password" "123456" "root"]
        set found_pwd 0
        
        foreach pwd $common_passwords {
            if {$pwd eq $DB_PASS} continue
            log_message $text "   Trying password: '$pwd'" 
            set result [test_postgres_connection $pwd]
            set status [lindex $result 0]
            if {$status} {
                log_message $text "✅ Found working password: '$pwd'" 
                set DB_PASS $pwd
                set found_pwd 1
                break
            }
        }
        
        if {$found_pwd} {
            tk_messageBox -icon info -title "Password Found" \
                -message "✅ Found working password!\n\nPassword: '$DB_PASS'\n\nContinuing with installation..."
            # Continue with installation
        } else {
            set DB_PASS ""
            tk_messageBox -icon error -title "Connection Error" \
                -message "Cannot connect to PostgreSQL.\n\n$conn_message\n\nPlease check:\n1. PostgreSQL is installed and running\n2. The connection settings are correct\n3. The password is correct\n\nYou may need to reset your PostgreSQL password."
            return
        }
    } else {
        log_message $text "✅ PostgreSQL connection successful" 
    }
    
    # Check PostgreSQL client
    log_message $text "\n📌 Step 1: Checking PostgreSQL client..."
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        log_message $text "❌ ERROR: PostgreSQL client (psql) not found!" 
        log_message $text "   Please set the correct path in the configuration." 
        $progress stop
        $w.main.buttons.install configure -state normal
        tk_messageBox -icon error -title "Error" \
            -message "PostgreSQL client (psql) not found.\n\nPlease set the correct path in the configuration."
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
        if {[string match "*password*" $errorMsg]} {
            log_message $text "❌ Password error!" 
            log_message $text "$errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            set DB_PASS ""
            tk_messageBox -icon error -title "Password Error" \
                -message "Password required or incorrect.\n\n$errorMsg"
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
        if {[string match "*password*" $errorMsg]} {
            log_message $text "❌ Password error!" 
            log_message $text "$errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            set DB_PASS ""
            tk_messageBox -icon error -title "Password Error" \
                -message "Password required or incorrect.\n\n$errorMsg"
            return
        }
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
        if {[string match "*password*" $errorMsg]} {
            log_message $text "❌ Password error!" 
            log_message $text "$errorMsg" 
            $progress stop
            $w.main.buttons.install configure -state normal
            set DB_PASS ""
            tk_messageBox -icon error -title "Password Error" \
                -message "Password required or incorrect.\n\n$errorMsg"
            return
        }
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
    }
    
    # Summary
    log_message $text "\n========================================" 
    log_message $text "✅ INSTALLATION COMPLETE!" 
    log_message $text "========================================" 
    log_message $text "\n📋 Database: $::DB_NAME" 
    log_message $text "📋 Host: $::DB_HOST:$::DB_PORT" 
    log_message $text "📋 User: $::DB_USER" 
    log_message $text "📋 Password: $::DB_PASS" 
    log_message $text "\n🔐 Default admin login:" 
    log_message $text "   Username: admin" 
    log_message $text "   Password: admin" 
    log_message $text "\n⚠️ Please change the admin password after first login!" 
    
    $progress stop
    $w.main.buttons.install configure -state normal
    
    tk_messageBox -icon info -title "Installation Complete" \
        -message "✅ Database installation completed successfully!\n\nDatabase: $::DB_NAME\nHost: $::DB_HOST:$::DB_PORT\nUser: $::DB_USER\nPassword: $::DB_PASS\n\nDefault admin login:\nUsername: admin\nPassword: admin"
}

# Execute PostgreSQL command
proc exec_psql {args} {
    global DB_HOST DB_PORT DB_USER DB_PASS
    
    set psql_exe [check_postgres]
    if {$psql_exe eq ""} {
        error "PostgreSQL client (psql) not found."
    }
    
    set cmd [list $psql_exe]
    lappend cmd -h $DB_HOST
    lappend cmd -p $DB_PORT
    lappend cmd -U $DB_USER
    
    # Set password via environment variable
    if {$DB_PASS ne ""} {
        set env(PGPASSWORD) $DB_PASS
    } else {
        catch {unset env(PGPASSWORD)}
    }
    
    # Add --no-password flag to prevent password prompt
    lappend cmd --no-password
    
    foreach arg $args {
        lappend cmd $arg
    }
    
    puts "DEBUG: Executing psql with args: [lrange $args 0 end]"
    
    set result [catch {exec {*}$cmd} output]
    
    if {$result != 0} {
        if {[string match "*password*" $output]} {
            error "Password required or incorrect."
        }
        if {[string match "*Connection refused*" $output] || [string match "*could not connect*" $output]} {
            error "PostgreSQL connection failed:\n$output"
        }
        error "Command failed: $output"
    }
    
    return $output
}

# ============================================
# Configuration Dialog
# ============================================

proc show_config_dialog {} {
    set w .config
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Database Configuration"
    wm geometry $w "550x550"
    wm resizable $w 0 0
    
    # Center the window
    set x [expr {([winfo screenwidth .] - 550) / 2}]
    set y [expr {([winfo screenheight .] - 550) / 2}]
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
    
    # Detect button
    ttk::button $check_frame.detect -text "🔎 Find PostgreSQL" -command [list detect_config] -padding "8 4"
    pack $check_frame.detect -side left -padx 5
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 15
    
    ttk::button $btn_frame.save -text "✅ Save & Continue" -command [list save_config] -padding "10 5"
    pack $btn_frame.save -side left -expand true -fill x -padx 5
    
    ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "10 5"
    pack $btn_frame.cancel -side right -expand true -fill x -padx 5
    
    # Store the entries array in global scope
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
        
        # Try to find it
        set found_paths [find_postgres_installation]
        if {[llength $found_paths] > 0} {
            tk_messageBox -icon warning -title "PostgreSQL Not Found at Path" \
                -message "PostgreSQL not found at the specified path.\n\nFound PostgreSQL in these locations:\n[join $found_paths "\n"]\n\nPlease update the path accordingly."
        } else {
            tk_messageBox -icon warning -title "PostgreSQL Not Found" \
                -message "PostgreSQL client (psql) not found.\n\nPlease install PostgreSQL or set the correct path."
        }
    }
}

proc detect_config {} {
    global config_entries
    
    # Find PostgreSQL installations
    set found_paths [find_postgres_installation]
    
    if {[llength $found_paths] > 0} {
        # Use the first found path
        set dir [lindex $found_paths 0]
        $config_entries(pgpath) delete 0 end
        $config_entries(pgpath) insert 0 $dir
        
        tk_messageBox -icon info -title "PostgreSQL Found" \
            -message "Found PostgreSQL at:\n$dir\n\nPath has been updated."
    } else {
        tk_messageBox -icon warning -title "PostgreSQL Not Found" \
            -message "No PostgreSQL installations found in common paths.\n\nPlease install PostgreSQL or set the path manually.\n\nDownload from:\nhttps://www.postgresql.org/download/"
    }
}

proc test_connection_config {} {
    global config_entries DB_HOST DB_PORT DB_USER DB_PASS PG_PATH
    
    # Get values from the configuration dialog
    set DB_HOST [$config_entries(host) get]
    set DB_PORT [$config_entries(port) get]
    set DB_USER [$config_entries(user) get]
    set DB_PASS [$config_entries(pass) get]
    set PG_PATH [$config_entries(pgpath) get]
    
    # If password is empty, ask for it
    if {$DB_PASS eq ""} {
        set DB_PASS [get_password_dialog "Enter PostgreSQL Password" "Please enter the password for user '$DB_USER':\n\nCommon passwords to try:\n- (empty)\n- postgres\n- admin\n- The password you set during installation"]
        if {$DB_PASS ne ""} {
            $config_entries(pass) insert 0 $DB_PASS
        }
    }
    
    # Test the connection
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    set message [lindex $result 1]
    
    if {$status} {
        # Extract just the PostgreSQL version
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
            -message "Successfully connected to PostgreSQL!\n\n$version\n\nConnection Details:\nHost: $DB_HOST\nPort: $DB_PORT\nUser: $DB_USER\nPassword: $DB_PASS"
    } else {
        # Try common passwords
        set common_passwords [list "" "postgres" "admin" "password" "123456" "root"]
        set found_pwd 0
        
        foreach pwd $common_passwords {
            if {$pwd eq $DB_PASS} continue
            set result [test_postgres_connection $pwd]
            set status [lindex $result 0]
            if {$status} {
                set DB_PASS $pwd
                $config_entries(pass) delete 0 end
                $config_entries(pass) insert 0 $pwd
                set found_pwd 1
                break
            }
        }
        
        if {$found_pwd} {
            tk_messageBox -icon info -title "✅ Password Found" \
                -message "Found working password: '$DB_PASS'\n\nPassword has been updated in the configuration."
        } else {
            tk_messageBox -icon error -title "❌ Connection Failed" \
                -message "PostgreSQL connection test failed.\n\n$message\n\nTried common passwords but none worked.\n\nPlease check:\n1. PostgreSQL is running\n2. Host and port are correct\n3. Username is correct\n4. Password is correct"
        }
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
    
    # If password is empty, ask for it
    if {$DB_PASS eq ""} {
        set DB_PASS [get_password_dialog "Enter PostgreSQL Password" "Please enter the password for user '$DB_USER':\n\nIf you don't know the password, try:\n- Empty (no password)\n- postgres\n- The password you set during installation"]
        if {$DB_PASS ne ""} {
            $config_entries(pass) insert 0 $DB_PASS
        }
    }
    
    # Test connection first
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    
    if {!$status} {
        set message [lindex $result 1]
        tk_messageBox -icon warning -title "Connection Warning" \
            -message "Cannot connect to PostgreSQL.\n\n$message\n\nPlease fix the connection settings and try again."
        return
    }
    
    destroy .config
    install_database
}

# ============================================
# Main Entry Point
# ============================================

# Check if running with GUI or command line
if {[info exists ::argv] && [lsearch -exact $::argv "--cli"] != -1} {
    # Command line mode
    puts "🚀 Toothpaste Database Installation (Command Line)"
    puts "================================================"
    puts ""
    
    # Ask for password
    puts -nonewline "Enter PostgreSQL password for user 'postgres' (press Enter for empty): "
    flush stdout
    if {$::tcl_platform(platform) ne "windows"} {
        exec stty -echo
        gets stdin DB_PASS
        exec stty echo
        puts ""
    } else {
        gets stdin DB_PASS
    }
    
    # Test connection with the provided password
    puts "📋 Testing connection..."
    set result [test_postgres_connection $DB_PASS]
    set status [lindex $result 0]
    
    if {!$status} {
        puts "❌ Connection failed: [lindex $result 1]"
        exit 1
    }
    
    puts "✅ Connection successful!"
    
    # Check if db.sql exists
    if {![file exists $SQL_FILE]} {
        puts "❌ ERROR: SQL file '$SQL_FILE' not found!"
        exit 1
    }
    
    # Install database
    puts "\n📌 Creating database..."
    if {[catch {exec_psql -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8';"} errorMsg]} {
        puts "❌ ERROR: $errorMsg"
        exit 1
    }
    puts "✅ Database created"
    
    puts "\n📌 Creating schema..."
    if {[catch {exec_psql -d $DB_NAME -f $SQL_FILE} errorMsg]} {
        puts "❌ ERROR: $errorMsg"
        exit 1
    }
    puts "✅ Schema created"
    
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
} else {
    # GUI mode
    if {[catch {package require Tk}]} {
        puts "Tk not available. Running in command line mode..."
        # Run command line mode
        puts "🚀 Toothpaste Database Installation (Command Line)"
        puts "================================================"
        puts ""
        puts -nonewline "Enter PostgreSQL password for user 'postgres' (press Enter for empty): "
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
        puts "✅ Connection successful!"
        
        if {[file exists $SQL_FILE]} {
            if {[catch {exec_psql -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8';"} errorMsg]} {
                puts "❌ ERROR: $errorMsg"
                exit 1
            }
            puts "✅ Database created"
            
            if {[catch {exec_psql -d $DB_NAME -f $SQL_FILE} errorMsg]} {
                puts "❌ ERROR: $errorMsg"
                exit 1
            }
            puts "✅ Schema created"
            
            puts "\n✅ INSTALLATION COMPLETE!"
        } else {
            puts "❌ SQL file not found!"
        }
    } else {
        # Show configuration dialog first
        show_config_dialog
        vwait forever
    }
}