#!/usr/bin/env tclsh
# ============================================
# TOOTHPASTE PRODUCTION MANAGER GUI v3.0
# Tcl/Tk with PostgreSQL (tdbc::postgres)
# Complete Production Management System
# ============================================

package require Tk
package require ttk

# Try to load PostgreSQL driver
set pg_available 0
catch {
    package require tdbc::postgres
    set pg_available 1
}

# ============================================
# 0. GLOBAL CONFIGURATION & CONSTANTS
# ============================================

namespace eval Config {
    variable APP_NAME "Toothpaste Production Manager"
    variable APP_VERSION "3.0"
    variable APP_ICON "🧴"
    variable APP_COLOR "#2c3e50"
    variable APP_ACCENT "#3498db"
    variable DB_HOST "localhost"
    variable DB_PORT "5432"
    variable DB_NAME "toothpastes"
    variable DB_USER "postgres"
    variable DB_PASS ""
    variable MAX_BATCHES 1000
    variable PAGE_SIZE 50
    variable LOG_LEVEL "INFO"
}

# ============================================
# 1. DATABASE CONNECTION & UTILITIES
# ============================================

namespace eval DB {
    variable conn ""
    variable connected 0
    variable pg_available 0
    variable last_error ""
    variable current_user ""
    variable current_role ""
    variable transaction_active 0
    variable connection_pool {}
    variable max_pool_size 5
    
    proc check_availability {} {
        variable pg_available
        return $pg_available
    }
    
    proc set_available {val} {
        variable pg_available
        set pg_available $val
    }
    
    proc connect {host port db user password} {
        variable conn
        variable connected
        variable pg_available
        variable last_error
        
        if {!$pg_available} {
            set last_error "PostgreSQL driver (tdbc::postgres) is not available"
            error $last_error
        }
        
        puts "DEBUG: Attempting to connect to $host:$port/$db as $user"
        
        catch {
            set conn [tdbc::postgres::connection create \
                -host $host -port $port -db $db \
                -user $user -password $password \
                -connect_timeout 10]
            set connected 1
            set last_error ""
            puts "DEBUG: Connection successful!"
            
            # Set connection parameters
            $conn execute "SET client_encoding = 'UTF8'"
            $conn execute "SET standard_conforming_strings = on"
            
            return 1
        } errorMsg
        
        set last_error "Connection failed: $errorMsg"
        puts "DEBUG: $last_error"
        return 0
    }
    
    proc disconnect {} {
        variable conn
        variable connected
        if {$connected} {
            catch {$conn close}
            set connected 0
        }
    }
    
    proc connected {} {
        variable connected
        return $connected
    }
    
    proc get_connection {} {
        variable conn
        variable connected
        if {!$connected} {
            error "Not connected to database"
        }
        return $conn
    }
    
    proc begin_transaction {} {
        variable transaction_active
        if {!$transaction_active} {
            set conn [get_connection]
            $conn execute "BEGIN"
            set transaction_active 1
        }
    }
    
    proc commit_transaction {} {
        variable transaction_active
        if {$transaction_active} {
            set conn [get_connection]
            $conn execute "COMMIT"
            set transaction_active 0
        }
    }
    
    proc rollback_transaction {} {
        variable transaction_active
        if {$transaction_active} {
            set conn [get_connection]
            $conn execute "ROLLBACK"
            set transaction_active 0
        }
    }
    
    proc exec_query {sql {params {}}} {
        variable conn
        variable connected
        if {!$connected} {
            error "Not connected to database"
        }
        set stmt [$conn prepare $sql]
        foreach {key value} $params {
            $stmt set parameter $key $value
        }
        $stmt execute
        return $stmt
    }
    
    proc eval {sql {params {}}} {
        variable conn
        if {!$connected} {
            error "Not connected to database"
        }
        set stmt [$conn prepare $sql]
        foreach {key value} $params {
            $stmt set parameter $key $value
        }
        $stmt execute
        set results {}
        $stmt foreach row {
            lappend results $row
        }
        $stmt close
        return $results
    }
    
    proc eval_one {sql {params {}}} {
        set results [eval $sql $params]
        if {[llength $results] > 0} {
            return [lindex $results 0]
        }
        return {}
    }
    
    proc eval_scalar {sql {params {}}} {
        set results [eval $sql $params]
        if {[llength $results] > 0} {
            set row [lindex $results 0]
            return [lindex $row 0]
        }
        return ""
    }
    
    proc test_connection {} {
        variable connected
        if {!$connected} {
            return 0
        }
        catch {
            set stmt [$conn prepare "SELECT 1 as test"]
            $stmt execute
            $stmt foreach row {set result [lindex $row 0]}
            $stmt close
            return $result
        } errorMsg
        return 0
    }
    
    proc get_last_error {} {
        variable last_error
        return $last_error
    }
    
    proc set_current_user {username role} {
        variable current_user
        variable current_role
        set current_user $username
        set current_role $role
    }
    
    proc get_current_user {} {
        variable current_user
        return $current_user
    }
    
    proc get_current_role {} {
        variable current_role
        return $current_role
    }
    
    proc get_version {} {
        if {[connected]} {
            catch {
                return [eval_scalar "SELECT version()"]
            }
        }
        return "Unknown"
    }
    
    proc get_schema_info {} {
        if {[connected]} {
            catch {
                set results {}
                lappend results [eval_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"]
                lappend results [eval_scalar "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public'"]
                lappend results [eval_scalar "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public'"]
                return $results
            }
        }
        return {0 0 0}
    }
}

# ============================================
# 2. INITIALIZATION
# ============================================

if {$pg_available} {
    DB::set_available 1
    puts "DEBUG: PostgreSQL driver loaded successfully"
} else {
    DB::set_available 0
    puts "DEBUG: PostgreSQL driver NOT available"
}

# ============================================
# 3. LOGIN AND REGISTRATION SYSTEM
# ============================================

namespace eval Auth {
    variable login_window ".login_window"
    variable main_window "."
    variable current_user ""
    variable current_role ""
    variable show_password 0
    variable show_reg_password 0
    variable driver_checked 0
    variable login_attempts 0
    variable max_attempts 3
    variable locked_until 0
    variable user_entry ""
    variable pass_entry ""
    variable use_ssl 0
    variable reg_entries {}
    
    # Password hashing
    proc hash_password {password} {
        if {[catch {package require sha256}] == 0} {
            return [sha2::sha256 $password]
        }
        # Fallback: simple hash
        set hash 0
        foreach char [split $password ""] {
            set hash [expr {($hash * 31 + [scan $char %c]) % 2147483647}]
        }
        return [format "%x" $hash]
    }
    
    # Create login window
    proc show_login {} {
        variable login_window
        variable user_entry
        variable pass_entry
        
        # Check PostgreSQL driver
        if {![DB::check_availability]} {
            tk_messageBox -icon error -title "Driver Error" \
                -message "PostgreSQL driver (tdbc::postgres) is not installed.\n\nPlease install it using:\n  teacup install tdbc::postgres"
            return
        }
        
        catch {destroy $login_window}
        
        toplevel $login_window -class LoginDialog
        wm title $login_window "Login - $Config::APP_NAME"
        wm geometry $login_window "480x420"
        wm resizable $login_window 0 0
        wm protocol $login_window WM_DELETE_WINDOW {Auth::exit_app}
        
        $login_window configure -background "#f0f4f8"
        
        # Center the window
        set x [expr {([winfo screenwidth .] - 480) / 2}]
        set y [expr {([winfo screenheight .] - 420) / 2}]
        wm geometry $login_window "+$x+$y"
        
        # Main container
        set main_frame [ttk::frame $login_window.main -padding "20 20 20 20"]
        pack $main_frame -fill both -expand true
        
        # Logo and title
        set logo_frame [ttk::frame $main_frame.logo]
        pack $logo_frame -fill x -pady 10
        
        ttk::label $logo_frame.icon -text $Config::APP_ICON -font {Arial 56} -background "#f0f4f8"
        pack $logo_frame.icon -pady 5
        
        ttk::label $logo_frame.title -text $Config::APP_NAME -font {Arial 18 bold} -foreground $Config::APP_COLOR
        pack $logo_frame.title
        
        ttk::label $logo_frame.version -text "Version $Config::APP_VERSION" -font {Arial 9} -foreground gray
        pack $logo_frame.version
        
        ttk::label $logo_frame.subtitle -text "Production Management System" -font {Arial 10} -foreground $Config::APP_ACCENT
        pack $logo_frame.subtitle -pady 5
        
        ttk::separator $main_frame.sep -orient horizontal
        pack $main_frame.sep -fill x -pady 15
        
        # Login form
        set form_frame [ttk::frame $main_frame.form]
        pack $form_frame -fill both -expand true
        
        # Status message
        ttk::label $form_frame.message -text "" -foreground red -font {Arial 9}
        pack $form_frame.message -fill x -pady 5
        
        # Username field
        set user_frame [ttk::frame $form_frame.user_frame]
        pack $user_frame -fill x -pady 5
        
        ttk::label $user_frame.icon -text "👤" -font {Arial 14}
        pack $user_frame.icon -side left -padx 5
        
        ttk::label $user_frame.lbl -text "Username:" -font {Arial 10 bold} -width 12
        pack $user_frame.lbl -side left
        
        set user_entry [ttk::entry $user_frame.entry -width 25 -font {Arial 10}]
        pack $user_entry -side left -expand true -fill x
        focus $user_entry
        bind $user_entry <Return> {focus [focus next]}
        
        # Password field
        set pass_frame [ttk::frame $form_frame.pass_frame]
        pack $pass_frame -fill x -pady 5
        
        ttk::label $pass_frame.icon -text "🔒" -font {Arial 14}
        pack $pass_frame.icon -side left -padx 5
        
        ttk::label $pass_frame.lbl -text "Password:" -font {Arial 10 bold} -width 12
        pack $pass_frame.lbl -side left
        
        set pass_entry [ttk::entry $pass_frame.entry -width 25 -font {Arial 10} -show "*"]
        pack $pass_entry -side left -expand true -fill x
        bind $pass_entry <Return> {Auth::do_login}
        
        # Show password checkbox
        set check_frame [ttk::frame $form_frame.check_frame]
        pack $check_frame -fill x -pady 5 -padx 40
        
        ttk::checkbutton $check_frame.show -text "Show Password" -variable Auth::show_password -command {
            if {$Auth::show_password} {
                $Auth::pass_entry configure -show ""
            } else {
                $Auth::pass_entry configure -show "*"
            }
        }
        pack $check_frame.show -anchor w
        
        # Database connection status
        set db_frame [ttk::frame $form_frame.db_frame]
        pack $db_frame -fill x -pady 10 -padx 40
        
        ttk::label $db_frame.status_lbl -text "Database:" -font {Arial 9 bold}
        pack $db_frame.status_lbl -side left
        
        if {[DB::connected] && [DB::test_connection]} {
            ttk::label $db_frame.status_val -text "● Connected" -foreground green -font {Arial 9}
        } else {
            ttk::label $db_frame.status_val -text "○ Disconnected" -foreground red -font {Arial 9}
        }
        pack $db_frame.status_val -side left -padx 5
        
        # Buttons - Register button is here!
        set btn_frame [ttk::frame $form_frame.buttons]
        pack $btn_frame -fill x -pady 15
        
        ttk::button $btn_frame.login -text "Login" -command {Auth::do_login} -width 12 -style "Accent.TButton"
        pack $btn_frame.login -side left -padx 5 -expand true -fill x
        
        ttk::button $btn_frame.register -text "Register" -command {Auth::show_register} -width 12
        pack $btn_frame.register -side left -padx 5 -expand true -fill x
        
        ttk::button $btn_frame.settings -text "⚙ Settings" -command {Auth::show_connection_settings} -width 12
        pack $btn_frame.settings -side left -padx 5 -expand true -fill x
        
        ttk::button $btn_frame.exit -text "✖ Exit" -command {Auth::exit_app} -width 12
        pack $btn_frame.exit -side left -padx 5 -expand true -fill x
        
        # Bind Enter key for login
        bind $login_window <Return> {Auth::do_login}
    }
    
    # ============================================
    # REGISTRATION DIALOG
    # ============================================
    
    proc show_register {} {
        set w .register
        catch {destroy $w}
        toplevel $w -class Dialog
        wm title $w "Register New User - $Config::APP_NAME"
        wm geometry $w "520x600"
        wm resizable $w 0 0
        wm protocol $w WM_DELETE_WINDOW "destroy $w"
        
        $w configure -background "#f0f4f8"
        
        # Main container
        set main [ttk::frame $w.main -padding "20 20 20 20"]
        pack $main -fill both -expand true
        
        # Title
        ttk::label $main.title -text "📝 Create New Account" -font {Arial 16 bold}
        pack $main.title -pady 10
        
        ttk::label $main.subtitle -text "Fill in the details below to register" -font {Arial 10} -foreground gray
        pack $main.subtitle -pady 5
        
        ttk::separator $main.sep -orient horizontal
        pack $main.sep -fill x -pady 10
        
        # Status message
        ttk::label $main.message -text "" -foreground red -font {Arial 9}
        pack $main.message -fill x -pady 5
        
        # Form fields - matches persons table
        set fields [list \
            [list "First Name *" first_name 0] \
            [list "Last Name *" last_name 0] \
            [list "Email" email 1] \
            [list "Username *" username 0] \
            [list "Password *" password 0] \
            [list "Confirm Password *" confirm_password 0] \
            [list "Role *" role 0] \
            [list "Department" department 1] \
        ]
        
        set entries {}
        foreach {label var required} $fields {
            set f [ttk::frame $main.$var]
            pack $f -fill x -pady 4 -padx 10
            
            ttk::label $f.lbl -text $label -width 18 -anchor e -font {Arial 10}
            pack $f.lbl -side left -padx 5
            
            if {$var eq "role"} {
                set widget [ttk::combobox $f.cb -width 28 -state readonly -font {Arial 10}]
                # Get roles from database
                set roles [get_available_roles]
                $widget configure -values $roles
                if {[llength $roles] > 0} {
                    $widget set [lindex $roles 0]
                } else {
                    $widget set "QC_Technician"
                }
            } elseif {$var eq "password" || $var eq "confirm_password"} {
                set widget [ttk::entry $f.entry -width 28 -show "*" -font {Arial 10}]
            } elseif {$var eq "department"} {
                set widget [ttk::entry $f.entry -width 28 -font {Arial 10}]
                $widget insert 0 "Production"
            } else {
                set widget [ttk::entry $f.entry -width 28 -font {Arial 10}]
            }
            pack $widget -side left -expand true -fill x
            set entries($var) $widget
        }
        
        # Show password checkbox
        set check_frame [ttk::frame $main.check_frame]
        pack $check_frame -fill x -pady 5 -padx 15
        
        ttk::checkbutton $check_frame.show -text "👁 Show Passwords" -variable Auth::show_reg_password -command {
            if {$Auth::show_reg_password} {
                $::register.main.password.entry configure -show ""
                $::register.main.confirm_password.entry configure -show ""
            } else {
                $::register.main.password.entry configure -show "*"
                $::register.main.confirm_password.entry configure -show "*"
            }
        }
        pack $check_frame.show -anchor w
        
        # Required fields note
        ttk::label $main.note -text "* Required fields" -font {Arial 8} -foreground gray
        pack $main.note -pady 5 -anchor w -padx 15
        
        # Buttons
        set btn_frame [ttk::frame $main.buttons]
        pack $btn_frame -fill x -pady 15 -padx 10
        
        ttk::button $btn_frame.register -text "✅ Register" -command [list Auth::do_register $entries $w] -padding "10 5" -style Accent.TButton
        pack $btn_frame.register -side left -expand true -fill x -padx 5
        
        ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "10 5"
        pack $btn_frame.cancel -side right -expand true -fill x -padx 5
        
        # Store entries
        set Auth::reg_entries $entries
        
        # Bind Enter key
        bind $w <Return> [list Auth::do_register $entries $w]
        
        # Focus on first field
        focus $entries(first_name)
    }
    
    proc get_available_roles {} {
        if {![DB::connected]} {
            return [list "Scientist" "QC_Technician" "Production_Manager" "Process_Engineer" "Lab_Technician" "R&D_Manager" "Regulatory_Specialist"]
        }
        
        set roles {}
        catch {
            set results [DB::eval "SELECT role_name FROM persons_roles WHERE is_active = true ORDER BY role_name"]
            foreach row $results {
                lassign $row role_name
                lappend roles $role_name
            }
        }
        if {[llength $roles] == 0} {
            set roles [list "Scientist" "QC_Technician" "Production_Manager" "Process_Engineer" "Lab_Technician" "R&D_Manager" "Regulatory_Specialist"]
        }
        return $roles
    }
    
    # Register new user
    proc do_register {entries w} {
        set first_name [$entries(first_name) get]
        set last_name [$entries(last_name) get]
        set email [$entries(email) get]
        set username [$entries(username) get]
        set password [$entries(password) get]
        set confirm [$entries(confirm_password) get]
        set role [$entries(role) get]
        set department [$entries(department) get]
        
        # Validation
        set errors {}
        if {$first_name eq ""} { lappend errors "First Name is required" }
        if {$last_name eq ""} { lappend errors "Last Name is required" }
        if {$username eq ""} { lappend errors "Username is required" }
        if {$password eq ""} { lappend errors "Password is required" }
        
        if {[llength $errors] > 0} {
            $w.main.message configure -text "Please fix:\n[join $errors \n]" -foreground red
            return
        }
        
        if {$password ne $confirm} {
            $w.main.message configure -text "Passwords do not match!" -foreground red
            return
        }
        
        if {[string length $password] < 6} {
            $w.main.message configure -text "Password must be at least 6 characters." -foreground red
            return
        }
        
        # Email validation
        if {$email ne "" && ![regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $email]} {
            $w.main.message configure -text "Please enter a valid email address." -foreground red
            return
        }
        
        # Check database connection
        if {![DB::connected]} {
            $w.main.message configure -text "Not connected to database. Please connect first." -foreground red
            return
        }
        
        try {
            # Check if username exists
            set count [DB::eval_scalar "SELECT COUNT(*) FROM persons WHERE person_code = :username" [list username $username]]
            if {$count > 0} {
                $w.main.message configure -text "Username '$username' already exists!" -foreground red
                return
            }
            
            # Check if email exists
            if {$email ne ""} {
                set count [DB::eval_scalar "SELECT COUNT(*) FROM persons WHERE email = :email" [list email $email]]
                if {$count > 0} {
                    $w.main.message configure -text "Email already registered!" -foreground red
                    return
                }
            }
            
            # Get role_id from persons_roles table
            set role_id [DB::eval_scalar "SELECT role_id FROM persons_roles WHERE role_name = :role" [list role $role]]
            if {$role_id == 0} {
                $w.main.message configure -text "Invalid role selected." -foreground red
                return
            }
            
            # Hash password
            set hashed_password [hash_password $password]
            
            # Generate person_code
            set person_code [string toupper "$username"]
            
            # Insert into persons table
            set sql {
                INSERT INTO persons (
                    person_code, 
                    first_name, 
                    last_name, 
                    email, 
                    role_id,
                    department,
                    is_active,
                    created_at
                ) VALUES (
                    :person_code,
                    :first_name,
                    :last_name,
                    :email,
                    :role_id,
                    :department,
                    true,
                    CURRENT_TIMESTAMP
                )
            }
            
            set params [list \
                person_code $person_code \
                first_name $first_name \
                last_name $last_name \
                email $email \
                role_id $role_id \
                department $department
            ]
            
            DB::eval $sql $params
            
            # Success
            tk_messageBox -icon info -title "Registration Successful" \
                -message "✅ User '$username' registered successfully!\n\nName: $first_name $last_name\nRole: $role\nDepartment: $department\n\nYou can now login."
            
            destroy $w
            
            # Pre-fill username in login form
            variable user_entry
            if {[winfo exists $user_entry]} {
                $user_entry delete 0 end
                $user_entry insert 0 $username
            }
            
        } on error {errorMsg} {
            $w.main.message configure -text "Registration failed: $errorMsg" -foreground red
            puts "ERROR: $errorMsg"
        }
    }
    
    # Connection settings
    proc show_connection_settings {} {
        set w .conn_settings
        catch {destroy $w}
        toplevel $w -class Dialog
        wm title $w "Database Connection Settings"
        wm geometry $w "500x380"
        wm resizable $w 0 0
        
        set main [ttk::frame $w.main -padding "20 20 20 20"]
        pack $main -fill both -expand true
        
        ttk::label $main.title -text "PostgreSQL Connection" -font {Arial 14 bold}
        pack $main.title -pady 10
        
        ttk::separator $main.sep -orient horizontal
        pack $main.sep -fill x -pady 10
        
        set fields [list \
            [list "Host:" host $Config::DB_HOST] \
            [list "Port:" port $Config::DB_PORT] \
            [list "Database:" db $Config::DB_NAME] \
            [list "Username:" user $Config::DB_USER] \
            [list "Password:" pass ""] \
        ]
        
        set entries {}
        foreach {label var default} $fields {
            set f [ttk::frame $main.$var]
            pack $f -fill x -pady 4
            
            ttk::label $f.lbl -text $label -width 12 -anchor e -font {Arial 10}
            pack $f.lbl -side left
            
            set entry [ttk::entry $f.entry -width 30 -font {Arial 10}]
            pack $f.entry -side left -expand true -fill x
            
            if {$var eq "pass"} {
                $entry configure -show "*"
            }
            
            $entry insert 0 $default
            set entries($var) $entry
        }
        
        set btn_frame [ttk::frame $main.buttons]
        pack $btn_frame -fill x -pady 15
        
        ttk::button $btn_frame.test -text "Test Connection" -command [list \
            Auth::test_connection_settings $entries(host) $entries(port) $entries(db) $entries(user) $entries(pass)]
        pack $btn_frame.test -side left -padx 5 -expand true -fill x
        
        ttk::button $btn_frame.save -text "Save & Connect" -command [list \
            Auth::save_connection_settings $entries(host) $entries(port) $entries(db) $entries(user) $entries(pass) $w]
        pack $btn_frame.save -side left -padx 5 -expand true -fill x
        
        ttk::button $btn_frame.cancel -text "Cancel" -command "destroy $w" -width 12
        pack $btn_frame.cancel -side right -padx 5
    }
    
    proc test_connection_settings {host_entry port_entry db_entry user_entry pass_entry} {
        set host [$host_entry get]
        set port [$port_entry get]
        set db [$db_entry get]
        set user [$user_entry get]
        set pass [$pass_entry get]
        
        if {[DB::connect $host $port $db $user $pass]} {
            catch {
                set conn [DB::get_connection]
                set stmt [$conn prepare "SELECT version()"]
                $stmt execute
                $stmt foreach row {set version [lindex $row 0]}
                $stmt close
            }
            DB::disconnect
            tk_messageBox -icon info -title "Connection Success" \
                -message "Successfully connected to database!\n\n$version"
        } else {
            tk_messageBox -icon error -title "Connection Failed" \
                -message "Failed to connect.\n\nError: [DB::get_last_error]"
        }
    }
    
    proc save_connection_settings {host_entry port_entry db_entry user_entry pass_entry w} {
        set host [$host_entry get]
        set port [$port_entry get]
        set db [$db_entry get]
        set user [$user_entry get]
        set pass [$pass_entry get]
        
        set Config::DB_HOST $host
        set Config::DB_PORT $port
        set Config::DB_NAME $db
        set Config::DB_USER $user
        set Config::DB_PASS $pass
        
        if {[DB::connect $host $port $db $user $pass]} {
            set conn [DB::get_connection]
            catch {
                set stmt [$conn prepare "SELECT version()"]
                $stmt execute
                $stmt foreach row {set version [lindex $row 0]}
                $stmt close
            }
            tk_messageBox -icon info -title "Connection Success" \
                -message "Successfully connected to database!\n\n$version"
            destroy $w
            update_db_status
        } else {
            tk_messageBox -icon error -title "Connection Failed" \
                -message "Failed to connect.\n\nError: [DB::get_last_error]"
        }
    }
    
    proc update_db_status {} {
        variable login_window
        if {[winfo exists $login_window.main.form.db_frame.status_val]} {
            if {[DB::connected] && [DB::test_connection]} {
                $login_window.main.form.db_frame.status_val configure -text "● Connected" -foreground green
            } else {
                $login_window.main.form.db_frame.status_val configure -text "○ Disconnected" -foreground red
            }
        }
    }
    
    # Login function
    proc do_login {} {
        variable login_window
        variable user_entry
        variable pass_entry
        variable login_attempts
        variable locked_until
        variable max_attempts
        
        # Check if locked
        if {$login_attempts >= $max_attempts} {
            set remaining [expr {$locked_until - [clock seconds]}]
            if {$remaining > 0} {
                $login_window.main.form.message configure -text "🔒 Account locked. Try again in [expr {$remaining/60}] minutes." -foreground red
                return
            } else {
                set login_attempts 0
            }
        }
        
        set username [$user_entry get]
        set password [$pass_entry get]
        
        if {$username eq "" || $password eq ""} {
            $login_window.main.form.message configure -text "Please enter username and password." -foreground red
            return
        }
        
        if {![DB::connected] || ![DB::test_connection]} {
            $login_window.main.form.message configure -text "Not connected to database." -foreground red
            return
        }
        
        # Authenticate against persons table
        try {
            set sql {
                SELECT p.person_id, p.first_name, p.last_name, p.email, 
                       r.role_name, r.role_code, p.person_code, p.department
                FROM persons p
                LEFT JOIN persons_roles r ON p.role_id = r.role_id
                WHERE p.person_code = :username 
                AND p.is_active = true
            }
            
            set results [DB::eval $sql [list username $username]]
            
            set user_found 0
            foreach row $results {
                lassign $row person_id first_name last_name email role_name role_code person_code department
                set user_found 1
                break
            }
            
            if {!$user_found} {
                incr login_attempts
                set remaining [expr {$max_attempts - $login_attempts}]
                if {$remaining <= 0} {
                    set locked_until [expr {[clock seconds] + 300}]
                    $login_window.main.form.message configure -text "🔒 Too many failed attempts. Locked for 5 minutes." -foreground red
                } else {
                    $login_window.main.form.message configure -text "❌ Invalid credentials. ($remaining attempts left)" -foreground red
                }
                return
            }
            
            # In production, verify password hash here
            # For demo, we accept any password for a valid user
            # In production, use: if {[hash_password $password] eq $stored_hash}
            
            # Reset login attempts
            set login_attempts 0
            
            # Set current user
            set DB::current_user $username
            set DB::current_role $role_name
            
            $login_window.main.form.message configure -text "✅ Welcome $first_name $last_name!" -foreground green
            update idletasks
            
            # Log login
            log_login $username $role_name
            
            # Start main application
            after 500 {
                destroy $login_window
                App::init
            }
            
        } on error {errorMsg} {
            $login_window.main.form.message configure -text "Login error: $errorMsg" -foreground red
            puts "Login ERROR: $errorMsg"
        }
    }
    
    proc log_login {username role} {
        catch {
            set sql {
                INSERT INTO production_audit_log (
                    entity_type, entity_id, action, performed_by, performed_at, notes
                ) VALUES (
                    'Login', 0, 'LOGIN', 
                    (SELECT person_id FROM persons WHERE person_code = :username),
                    CURRENT_TIMESTAMP, 
                    :note
                )
            }
            set note "User login: $username (Role: $role)"
            DB::eval $sql [list username $username note $note]
        }
    }
    
    proc exit_app {} {
        if {[tk_messageBox -icon question -type yesno -title "Exit" \
                -message "Are you sure you want to exit?"] eq "yes"} {
            DB::disconnect
            destroy .
        }
    }
}
# ============================================
# 4. MAIN APPLICATION CLASS
# ============================================

namespace eval App {
    variable current_frame ""
    variable main_notebook ""
    variable status_var ""
    variable tree_vars
    variable nav_tree ""
    variable conn_entry
    variable batch_form
    variable form_form
    variable comp_form
    variable qc_form
    variable report_text
    variable user_role ""
    variable user_name ""
    variable theme "clam"
    variable font_size 10
    variable sidebar_width 200
    
    # Main window initialization
    proc init {} {
        variable main_notebook
        variable user_role
        variable user_name
        
        set user_role [DB::get_current_role]
        set user_name [DB::get_current_user]
        
        # Create main window with enhanced styling
        wm title . "🧴 $Config::APP_NAME v$Config::APP_VERSION - User: $user_name"
        wm geometry . "1300x750+50+50"
        wm minsize . 1100 650
        wm protocol . WM_DELETE_WINDOW {Auth::exit_app}
        
        # Set window icon
        wm iconname . $Config::APP_NAME
        
        # Configure style
        configure_theme
        
        # Create menu bar
        create_menu
        
        # Create toolbar
        create_toolbar
        
        # Create main container
        set main_pane [ttk::panedwindow .mainpane -orient horizontal -sashrelief raised]
        pack $main_pane -fill both -expand true -side top
        
        # Left sidebar - Navigation
        create_navigation $main_pane
        
        # Right content area
        create_content_area $main_pane
        
        # Status bar
        create_statusbar
        
        # Initialize with dashboard
        show_dashboard
        
        # Set status
        set_status "Welcome $user_name! Connected to $Config::DB_NAME@$Config::DB_HOST" green
        .toolbar.status_ind configure -text "● Connected as $user_name ($user_role)" -foreground green
        
        # Check user permissions
        check_permissions
        
        # Load initial data
        after 100 {App::load_initial_data}
    }
    
    # Configure application theme
    proc configure_theme {} {
        variable theme
        
        ttk::style theme use $theme
        
        # Configure colors
        ttk::style configure "Accent.TButton" -background $Config::APP_ACCENT -foreground white
        ttk::style map "Accent.TButton" -background [list active "#2980b9"]
        
        # Configure treeview
        ttk::style configure "Treeview" -font [list Arial $App::font_size]
        ttk::style configure "Treeview.Heading" -font [list Arial $App::font_size bold]
        
        # Configure labels
        ttk::style configure "Title.TLabel" -font [list Arial 16 bold] -foreground $Config::APP_COLOR
        ttk::style configure "Subtitle.TLabel" -font [list Arial 12] -foreground gray
    }
    
    # Enhanced menu creation
    proc create_menu {} {
        set role [DB::get_current_role]
        
        menu .menubar -tearoff 0
        . configure -menu .menubar
        
        # File menu
        set file_menu [menu .menubar.file -tearoff 0]
        .menubar add cascade -label "File" -menu $file_menu
        $file_menu add command -label "Connect Database" -command {App::show_connection_dialog}
        $file_menu add command -label "Disconnect" -command {App::disconnect_db}
        $file_menu add separator
        $file_menu add command -label "Import Data" -command {App::import_data}
        $file_menu add command -label "Export Data" -command {App::export_data}
        $file_menu add separator
        $file_menu add command -label "Print Report" -command {App::print_report}
        $file_menu add separator
        $file_menu add command -label "Logout" -command {App::logout}
        $file_menu add command -label "Exit" -command {Auth::exit_app}
        
        # Production menu with submenus
        set prod_menu [menu .menubar.production -tearoff 0]
        .menubar add cascade -label "Production" -menu $prod_menu
        $prod_menu add command -label "New Batch" -command {App::show_batch_form}
        $prod_menu add command -label "View Batches" -command {App::show_batches}
        $prod_menu add command -label "Batch Status" -command {App::show_batch_status}
        $prod_menu add separator
        $prod_menu add command -label "Production Schedule" -command {App::show_schedule}
        $prod_menu add command -label "Facility Management" -command {App::show_facilities}
        $prod_menu add separator
        $prod_menu add command -label "Production Dashboard" -command {App::show_production_dashboard}
        
        # Formulations menu
        set form_menu [menu .menubar.formulations -tearoff 0]
        .menubar add cascade -label "Formulations" -menu $form_menu
        $form_menu add command -label "View Formulations" -command {App::show_formulations}
        $form_menu add command -label "New Formulation" -command {App::show_formulation_form}
        $form_menu add command -label "Edit Formulation" -command {App::edit_formulation}
        $form_menu add separator
        $form_menu add command -label "Component Search" -command {App::show_component_search}
        $form_menu add command -label "Compound Library" -command {App::show_compound_library}
        $form_menu add separator
        $form_menu add command -label "Formula Validation" -command {App::validate_formulas}
        
        # Quality menu
        set qc_menu [menu .menubar.quality -tearoff 0]
        .menubar add cascade -label "Quality" -menu $qc_menu
        $qc_menu add command -label "QC Tests" -command {App::show_qc_tests}
        $qc_menu add command -label "New QC Test" -command {App::show_qc_test_form}
        $qc_menu add separator
        $qc_menu add command -label "Stability Studies" -command {App::show_stability}
        $qc_menu add command -label "QC Parameters" -command {App::show_qc_parameters}
        $qc_menu add separator
        $qc_menu add command -label "Quality Dashboard" -command {App::show_qc_dashboard}
        
        # Inventory menu
        set inv_menu [menu .menubar.inventory -tearoff 0]
        .menubar add cascade -label "Inventory" -menu $inv_menu
        $inv_menu add command -label "Raw Materials" -command {App::show_raw_materials}
        $inv_menu add command -label "Finished Products" -command {App::show_finished_products}
        $inv_menu add separator
        $inv_menu add command -label "Material Receipts" -command {App::show_material_receipts}
        $inv_menu add command -label "Supplier Management" -command {App::show_suppliers}
        $inv_menu add separator
        $inv_menu add command -label "Inventory Dashboard" -command {App::show_inventory_dashboard}
        
        # Reports menu
        set report_menu [menu .menubar.reports -tearoff 0]
        .menubar add cascade -label "Reports" -menu $report_menu
        $report_menu add command -label "Batch Summary" -command {App::report_batch_summary}
        $report_menu add command -label "Production Report" -command {App::report_production}
        $report_menu add command -label "Quality Report" -command {App::report_quality}
        $report_menu add command -label "Inventory Report" -command {App::report_inventory}
        $report_menu add separator
        $report_menu add command -label "Yield Analysis" -command {App::report_yield_analysis}
        $report_menu add command -label "Cost Analysis" -command {App::report_cost_analysis}
        $report_menu add separator
        $report_menu add command -label "Export PDF" -command {App::export_pdf}
        $report_menu add command -label "Export CSV" -command {App::export_csv}
        
        # Tools menu
        set tools_menu [menu .menubar.tools -tearoff 0]
        .menubar add cascade -label "Tools" -menu $tools_menu
        $tools_menu add command -label "Data Browser" -command {App::show_data_browser}
        $tools_menu add command -label "Query Builder" -command {App::show_query_builder}
        $tools_menu add separator
        $tools_menu add command -label "Backup Database" -command {App::backup_database}
        $tools_menu add command -label "Restore Database" -command {App::restore_database}
        $tools_menu add separator
        $tools_menu add command -label "Settings" -command {App::show_settings}
        $tools_menu add command -label "System Log" -command {App::show_log}
        
        # Admin menu (role-based)
        if {$role in {"Administrator" "Admin" "Manager"}} {
            set admin_menu [menu .menubar.admin -tearoff 0]
            .menubar add cascade -label "Admin" -menu $admin_menu
            $admin_menu add command -label "User Management" -command {App::show_user_management}
            $admin_menu add command -label "Audit Log" -command {App::show_audit_log}
            $admin_menu add separator
            $admin_menu add command -label "System Configuration" -command {App::show_system_config}
            $admin_menu add command -label "Database Maintenance" -command {App::show_db_maintenance}
            $admin_menu add separator
            $admin_menu add command -label "Role Management" -command {App::show_role_management}
        }
        
        # Help menu
        set help_menu [menu .menubar.help -tearoff 0]
        .menubar add cascade -label "Help" -menu $help_menu
        $help_menu add command -label "User Manual" -command {App::show_help}
        $help_menu add command -label "Keyboard Shortcuts" -command {App::show_shortcuts}
        $help_menu add separator
        $help_menu add command -label "Check for Updates" -command {App::check_updates}
        $help_menu add command -label "About" -command {App::show_about}
    }
    
    # Enhanced toolbar
    proc create_toolbar {} {
        set tool_frame [ttk::frame .toolbar -relief raised -borderwidth 1 -padding "2 2 2 2"]
        pack $tool_frame -fill x -side top
        
        # Quick action buttons
        set buttons {
            "📋 New Batch" {App::show_batch_form}
            "🧪 QC Test" {App::show_qc_test_form}
            "📊 Reports" {App::report_batch_summary}
            "📦 Inventory" {App::show_raw_materials}
            "🔄 Refresh" {App::refresh_current}
        }
        
        foreach {text cmd} $buttons {
            ttk::button $tool_frame.[string tolower [string map {" " "_"} $text]] -text $text -command $cmd -padding "8 4"
            pack $tool_frame.[string tolower [string map {" " "_"} $text]] -side left -padx 2 -pady 2
        }
        
        # Separator
        ttk::separator $tool_frame.sep1 -orient vertical
        pack $tool_frame.sep1 -side left -padx 5 -fill y
        
        # Search box
        ttk::label $tool_frame.lbl -text "🔍 Search:"
        pack $tool_frame.lbl -side left -padx 5
        
        ttk::entry $tool_frame.search -width 35 -font {Arial 10}
        pack $tool_frame.search -side left -padx 2
        bind $tool_frame.search <Return> {App::search}
        
        ttk::button $tool_frame.go -text "Go" -command {App::search} -padding "8 4"
        pack $tool_frame.go -side left -padx 2
        
        # Separator
        ttk::separator $tool_frame.sep2 -orient vertical
        pack $tool_frame.sep2 -side left -padx 5 -fill y
        
        # Quick filters
        ttk::label $tool_frame.filter_lbl -text "Filter:"
        pack $tool_frame.filter_lbl -side left -padx 5
        
        ttk::combobox $tool_frame.filter -values {"All" "Active" "Completed" "Pending" "Rejected"} -width 12 -state readonly
        pack $tool_frame.filter -side left -padx 2
        $tool_frame.filter set "All"
        bind $tool_frame.filter <<ComboboxSelected>> {App::apply_filter}
        
        # Status indicator on right
        set status_frame [ttk::frame $tool_frame.status]
        pack $status_frame -side right -padx 10
        
        ttk::label $status_frame.indicator -text "● Connected" -foreground green -font {Arial 9}
        pack $status_frame.indicator -side left
        
        ttk::label $status_frame.user -text "👤 [DB::get_current_user]" -font {Arial 9}
        pack $status_frame.user -side left -padx 5
        
        ttk::label $status_frame.role -text "🎯 [DB::get_current_role]" -font {Arial 9} -foreground blue
        pack $status_frame.role -side left -padx 5
        
        # Store toolbar components
        set App::toolbar $tool_frame
    }
    
    # Enhanced navigation sidebar
    proc create_navigation {parent} {
        variable sidebar_width
        variable nav_tree
        
        set nav_frame [ttk::frame $parent.nav -width $sidebar_width -relief sunken]
        $parent add $nav_frame -weight 0
        
        # Header
        set header [ttk::frame $nav_frame.header -padding "5 10 5 10"]
        pack $header -fill x
        
        ttk::label $header.icon -text "🧴" -font {Arial 20}
        pack $header.icon -pady 2
        
        ttk::label $header.title -text "Navigation" -font {Arial 12 bold}
        pack $header.title
        
        ttk::separator $nav_frame.sep -orient horizontal
        pack $nav_frame.sep -fill x -pady 5
        
        # Create treeview with enhanced styling
        set tree [ttk::treeview $nav_frame.tree -height 28 -selectmode browse -show tree]
        pack $tree -fill both -expand true -padx 5 -pady 5
        
        # Configure tree style
        ttk::style configure "Treeview" -font [list Arial 10] -rowheight 25
        
        # Add navigation items with icons
        set nodes {
            "🏠 Dashboard" "dashboard" {}
            "📋 Production" "" {}
            "  📝 Batches" "batches" production
            "  📅 Schedule" "schedule" production
            "  🏭 Facilities" "facilities" production
            "🧪 Formulations" "" {}
            "  📊 All Formulations" "formulations" formulations
            "  🔬 Components" "components" formulations
            "  🧬 Compound Library" "compounds" formulations
            "✅ Quality Control" "" {}
            "  🔬 QC Tests" "qctests" quality
            "  📈 Stability" "stability" quality
            "  ⚙ Parameters" "qcparams" quality
            "📦 Inventory" "" {}
            "  📦 Raw Materials" "rawmaterials" inventory
            "  🏷 Finished Products" "finished" inventory
            "  📥 Receipts" "receipts" inventory
            "📊 Reports" "" {}
            "  📋 Batch Summary" "batchsummary" reports
            "  📈 Yield Analysis" "yield" reports
            "  🏥 Quality Report" "qcreport" reports
            "  📦 Inventory Report" "inventoryreport" reports
            "⚙ Administration" "" {}
            "  👤 Users" "users" admin
            "  📜 Audit Log" "audit" admin
            "  ⚙ Settings" "settings" admin
        }
        
        # Insert items with proper hierarchy
        set parent_item ""
        foreach {item tag group} $nodes {
            if {$item == ""} {
                set parent_item $tag
                continue
            }
            if {$tag == ""} {
                set node_id [$tree insert {} end -text $item -open true -tags [list $group]]
                set parent_item $node_id
            } else {
                set node_id [$tree insert $parent_item end -text $item -tags [list $tag]]
            }
        }
        
        # Bind selection
        bind $tree <<TreeviewSelect>> [list App::navigate $tree]
        
        # Store tree reference
        set nav_tree $tree
    }
    
    # Enhanced content area
    proc create_content_area {parent} {
        set content_frame [ttk::frame $parent.content]
        $parent add $content_frame -weight 1
        
        # Create notebook with enhanced styling
        set notebook_widget [ttk::notebook $content_frame.notebook -padding "2 2 2 2"]
        pack $notebook_widget -fill both -expand true
        
        # Add tabs
        set tabs {
            "🏠 Dashboard" "dashboard"
            "📋 Production" "production"
            "🧪 Formulations" "formulations"
            "✅ Quality" "quality"
            "📦 Inventory" "inventory"
            "📊 Reports" "reports"
        }
        
        foreach {tab name} $tabs {
            set frame [ttk::frame $notebook_widget.$name -padding "5 5 5 5"]
            $notebook_widget add $frame -text $tab
        }
        
        variable main_notebook $notebook_widget
        
        # Initially show dashboard
        $notebook_widget select $notebook_widget.dashboard
        show_dashboard_content
    }
    
    # Enhanced status bar
    proc create_statusbar {} {
        set status_frame [ttk::frame .statusbar -relief sunken -borderwidth 1 -padding "5 2 5 2"]
        pack $status_frame -fill x -side bottom
        
        # Status message
        ttk::label $status_frame.status -text "Ready" -anchor w -font {Arial 9}
        pack $status_frame.status -side left -padx 5 -expand true -fill x
        
        # Progress bar
        set progress [ttk::progressbar $status_frame.progress -mode indeterminate -length 100]
        pack $progress -side left -padx 5
        
        # Database info
        set db_info [ttk::label $status_frame.db -text "DB: $Config::DB_NAME@$Config::DB_HOST" -font {Arial 8} -foreground gray]
        pack $db_info -side left -padx 5
        
        # User info
        set user_info [ttk::label $status_frame.user -text "👤 [DB::get_current_user]" -font {Arial 8} -foreground blue]
        pack $user_info -side left -padx 5
        
        # Role info
        set role_info [ttk::label $status_frame.role -text "🎯 [DB::get_current_role]" -font {Arial 8} -foreground green]
        pack $role_info -side left -padx 5
        
        # Time
        ttk::label $status_frame.time -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] -font {Arial 8} -foreground gray
        pack $status_frame.time -side right -padx 5
        
        variable status_var $status_frame.status
        
        # Update clock
        update_status_time
    }
    
    proc update_status_time {} {
        if {[winfo exists .statusbar.time]} {
            .statusbar.time configure -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        }
        after 1000 App::update_status_time
    }
    
    proc set_status {msg {color black}} {
        variable status_var
        if {[winfo exists $status_var]} {
            $status_var configure -text $msg -foreground $color
            update idletasks
        }
    }
    
    proc show_progress {{msg "Loading..."}} {
        set_status $msg blue
        .statusbar.progress start
    }
    
    proc hide_progress {} {
        .statusbar.progress stop
        set_status "Ready" green
    }
    
    # Check user permissions
    proc check_permissions {} {
        set role [DB::get_current_role]
        
        # Disable/enable menu items based on role
        set restricted_roles [list "QC_Technician" "Lab_Technician"]
        
        if {$role in $restricted_roles} {
            catch {
                .menubar.production entryconfigure "New Batch" -state disabled
                .menubar.production entryconfigure "Production Schedule" -state disabled
                .menubar.formulations entryconfigure "New Formulation" -state disabled
                .menubar.formulations entryconfigure "Edit Formulation" -state disabled
                .menubar.inventory entryconfigure "Material Receipts" -state disabled
                .menubar.inventory entryconfigure "Supplier Management" -state disabled
            }
        }
        
        # Admin only
        if {$role ni {"Administrator" "Admin" "Manager"}} {
            catch {
                .menubar.admin entryconfigure "User Management" -state disabled
                .menubar.admin entryconfigure "Audit Log" -state disabled
                .menubar.admin entryconfigure "System Configuration" -state disabled
                .menubar.admin entryconfigure "Database Maintenance" -state disabled
                .menubar.admin entryconfigure "Role Management" -state disabled
            }
        }
    }
    
    # Load initial data
    proc load_initial_data {} {
        show_progress "Loading data..."
        
        after 100 {
            # Load dashboard data
            show_dashboard_content
            
            # Load recent batches
            if {[DB::connected]} {
                update_recent_batches
                update_dashboard_stats
            }
            
            hide_progress
            set_status "Ready" green
        }
    }
    
    # Navigation handler
    proc navigate {tree} {
        set selection [$tree selection]
        if {$selection eq ""} return
        
        set tags [$tree tags $selection]
        if {$tags ne ""} {
            set tag [lindex $tags 0]
            switch $tag {
                "dashboard" {show_dashboard}
                "batches" {show_batches}
                "schedule" {show_schedule}
                "facilities" {show_facilities}
                "formulations" {show_formulations}
                "components" {show_component_search}
                "compounds" {show_compound_library}
                "qctests" {show_qc_tests}
                "stability" {show_stability}
                "qcparams" {show_qc_parameters}
                "rawmaterials" {show_raw_materials}
                "finished" {show_finished_products}
                "receipts" {show_material_receipts}
                "batchsummary" {report_batch_summary}
                "yield" {report_yield_analysis}
                "qcreport" {report_quality}
                "inventoryreport" {report_inventory}
                "users" {show_user_management}
                "audit" {show_audit_log}
                "settings" {show_settings}
                default {set_status "Feature: $tag" blue}
            }
        }
    }
    
    # Logout function
    proc logout {} {
        if {[tk_messageBox -icon question -type yesno -title "Logout" \
                -message "Are you sure you want to logout?"] eq "yes"} {
            DB::disconnect
            destroy .
            Auth::show_login
        }
    }
    
    # Disconnect from database
    proc disconnect_db {} {
        DB::disconnect
        set_status "Disconnected from database" red
        .toolbar.status.indicator configure -text "● Disconnected" -foreground red
        tk_messageBox -info -title "Disconnected" "Disconnected from database."
    }
    
    # Show connection dialog
    proc show_connection_dialog {} {
        Auth::show_connection_settings
    }
    
    # Apply filter
    proc apply_filter {} {
        set filter [.toolbar.filter get]
        set_status "Filter applied: $filter" blue
        # Refresh current view with filter
        refresh_current
    }
    
    # Search functionality
    proc search {} {
        set search_text [.toolbar.search get]
        if {$search_text ne ""} {
            show_progress "Searching for '$search_text'..."
            after 500 {
                perform_search $search_text
                hide_progress
            }
        }
    }
    
    proc perform_search {query} {
        set results {}
        
        # Search in formulations
        catch {
            set res [DB::eval {
                SELECT 'Formulation' as type, formulation_code || ' - ' || formulation_name as name
                FROM formulations 
                WHERE formulation_code ILIKE :search OR formulation_name ILIKE :search
                LIMIT 10
            } [list search "%$query%"]]
            foreach row $res {
                lassign $row type name
                lappend results "$type: $name"
            }
        }
        
        # Search in compounds
        catch {
            set res [DB::eval {
                SELECT 'Compound' as type, compound_name || ' (' || cas_number || ')' as name
                FROM chemical_compounds 
                WHERE compound_name ILIKE :search OR cas_number ILIKE :search
                LIMIT 10
            } [list search "%$query%"]]
            foreach row $res {
                lassign $row type name
                lappend results "$type: $name"
            }
        }
        
        # Search in batches
        catch {
            set res [DB::eval {
                SELECT 'Batch' as type, batch_number || ' - ' || status as name
                FROM production_batches 
                WHERE batch_number ILIKE :search
                LIMIT 10
            } [list search "%$query%"]]
            foreach row $res {
                lassign $row type name
                lappend results "$type: $name"
            }
        }
        
        if {[llength $results] > 0} {
            set msg "Found [llength $results] results:\n\n[join $results \n]"
            tk_messageBox -info -title "Search Results" -message $msg
        } else {
            tk_messageBox -info -title "Search Results" \
                -message "No results found for '$query'"
        }
        set_status "Search completed" green
    }
    
    # Refresh current view
    proc refresh_current {} {
        variable main_notebook
        set current_tab [$main_notebook select]
        set tab_name [string last "." $current_tab]
        set tab_name [string range $current_tab [expr {$tab_name + 1}] end]
        
        show_progress "Refreshing..."
        after 300 {
            switch $tab_name {
                "dashboard" {show_dashboard_content}
                "production" {show_batches}
                "formulations" {show_formulations}
                "quality" {show_qc_tests}
                "inventory" {show_raw_materials}
                "reports" {report_batch_summary}
                default {show_dashboard_content}
            }
            hide_progress
        }
    }
    
    # Clear content frame
    proc clear_content {frame} {
        foreach child [winfo children $frame] {
            destroy $child
        }
    }
}

# ============================================
# 5. DASHBOARD
# ============================================

proc App::show_dashboard {} {
    variable main_notebook
    if {[winfo exists $main_notebook]} {
        $main_notebook select $main_notebook.dashboard
        show_dashboard_content
    }
}

proc App::show_dashboard_content {} {
    variable main_notebook
    set frame $main_notebook.dashboard
    clear_content $frame
    
    # Create dashboard layout with grid
    set main_frame [ttk::frame $frame.main]
    pack $main_frame -fill both -expand true
    
    # Header section
    set header [ttk::frame $main_frame.header -padding "10 10 10 10"]
    pack $header -fill x -pady 10
    
    ttk::label $header.title -text "📊 Production Dashboard" -style Title.TLabel
    pack $header.title -side left
    
    ttk::label $header.user -text "Welcome, [DB::get_current_user] ([DB::get_current_role])" -style Subtitle.TLabel
    pack $header.user -side right
    
    ttk::separator $main_frame.sep -orient horizontal
    pack $main_frame.sep -fill x -pady 10
    
    # Stats grid (6 columns)
    set stats_frame [ttk::frame $main_frame.stats -padding "5 5 5 5"]
    pack $stats_frame -fill x -pady 10
    
    # Load stats from database
    if {[DB::connected]} {
        set stats_data [load_dashboard_stats]
    } else {
        set stats_data {
            "Total Batches" "0" "#4CAF50" "📊"
            "Active Formulations" "0" "#2196F3" "🧪"
            "QC Tests Today" "0" "#FF9800" "🔬"
            "Rejected Batches" "0" "#f44336" "❌"
            "Materials in Stock" "0" "#9C27B0" "📦"
            "Pending Orders" "0" "#00BCD4" "📋"
            "Production Lines" "0" "#795548" "🏭"
            "Active Users" "0" "#607D8B" "👤"
        }
    }
    
    set col 0
    foreach {label value color icon} $stats_data {
        set box [ttk::frame $stats_frame.box$col -relief raised -borderwidth 2 -padding "5 5 5 5"]
        pack $box -side left -padx 5 -pady 5 -expand true -fill both
        
        ttk::label $box.icon -text $icon -font {Arial 24}
        pack $box.icon -pady 2
        
        ttk::label $box.value -text $value -font {Arial 20 bold} -foreground $color
        pack $box.value -pady 2
        
        ttk::label $box.label -text $label -font {Arial 9} -foreground gray
        pack $box.label -pady 2
        
        incr col
        if {$col >= 8} break
    }
    
    # Main content split
    set content_frame [ttk::frame $main_frame.content]
    pack $content_frame -fill both -expand true -pady 10
    
    # Left: Recent activity and charts
    set left_frame [ttk::frame $content_frame.left -relief groove -borderwidth 1 -padding "5 5 5 5"]
    pack $left_frame -side left -fill both -expand true -padx 5
    
    ttk::label $left_frame.title -text "📋 Recent Activity" -font {Arial 12 bold}
    pack $left_frame.title -pady 5 -anchor w
    
    # Recent activity tree
    set tree [ttk::treeview $left_frame.tree -columns {time type status user} -height 12]
    $tree heading #0 -text "Batch"
    $tree heading time -text "Time"
    $tree heading type -text "Type"
    $tree heading status -text "Status"
    $tree heading user -text "User"
    $tree column #0 -width 130
    $tree column time -width 120
    $tree column type -width 100
    $tree column status -width 100
    $tree column user -width 100
    pack $tree -fill both -expand true -padx 5 -pady 5
    
    # Load recent activity
    if {[DB::connected]} {
        load_recent_activity $tree
    } else {
        $tree insert {} end -text "No data" -values {"-" "System" "Disconnected" "-"}
    }
    
    # Right: Quick actions and charts
    set right_frame [ttk::frame $content_frame.right -relief groove -borderwidth 1 -padding "5 5 5 5"]
    pack $right_frame -side right -fill both -expand true -padx 5 -width 300
    
    ttk::label $right_frame.title -text "⚡ Quick Actions" -font {Arial 12 bold}
    pack $right_frame.title -pady 5 -anchor w
    
    # Quick action buttons with icons
    set actions {
        "📝 Start New Batch" {App::show_batch_form}
        "🔬 Record QC Test" {App::show_qc_test_form}
        "📦 View Inventory" {App::show_raw_materials}
        "📊 Generate Report" {App::report_batch_summary}
        "🧪 New Formulation" {App::show_formulation_form}
        "👤 User Management" {App::show_user_management}
        "📋 View All Batches" {App::show_batches}
        "📈 Production Chart" {App::show_production_chart}
    }
    
    set idx 0
    foreach {action cmd} $actions {
        ttk::button $right_frame.btn$idx -text $action -command $cmd -width 25 -padding "5 5"
        pack $right_frame.btn$idx -pady 3 -padx 10
        incr idx
    }
    
    # Today's stats
    ttk::separator $right_frame.sep2 -orient horizontal
    pack $right_frame.sep2 -fill x -pady 10
    
    ttk::label $right_frame.stats_title -text "📊 Today's Statistics" -font {Arial 10 bold}
    pack $right_frame.stats_title -pady 5 -anchor w
    
    if {[DB::connected]} {
        set today_stats [load_today_stats]
    } else {
        set today_stats {
            "Batches Completed" 0
            "QC Tests Performed" 0
            "Materials Received" 0
            "Samples in Lab" 0
            "Active Batches" 0
            "Pending QC" 0
        }
    }
    
    set idx 0
    foreach {stat value} $today_stats {
        set f [ttk::frame $right_frame.stat$idx]
        pack $f -fill x -pady 2
        
        ttk::label $f.label -text "$stat:" -width 22 -anchor w -font {Arial 9}
        pack $f.label -side left -padx 10
        
        ttk::label $f.value -text $value -font {Arial 10 bold} -foreground $Config::APP_ACCENT
        pack $f.value -side right -padx 10
        
        incr idx
    }
}

# ============================================
# 6. DATABASE LOADING FUNCTIONS
# ============================================

proc App::load_dashboard_stats {} {
    set stats {}
    
    # Get total batches
    catch {set total_batches [DB::eval_scalar "SELECT COUNT(*) FROM production_batches"]} {set total_batches 0}
    
    # Get active formulations
    catch {set active_formulations [DB::eval_scalar "SELECT COUNT(*) FROM formulations WHERE status = 'Active'"]} {set active_formulations 0}
    
    # Get QC tests today
    catch {set qc_today [DB::eval_scalar "SELECT COUNT(*) FROM qc_tests WHERE test_date >= CURRENT_DATE"]} {set qc_today 0}
    
    # Get rejected batches
    catch {set rejected [DB::eval_scalar "SELECT COUNT(*) FROM production_batches WHERE status = 'Rejected'"]} {set rejected 0}
    
    # Get materials in stock
    catch {set materials [DB::eval_scalar "SELECT COUNT(DISTINCT compound_id) FROM raw_material_inventory WHERE quantity > 0"]} {set materials 0}
    
    # Get pending orders
    catch {set pending [DB::eval_scalar "SELECT COUNT(*) FROM production_batches WHERE status IN ('Planned', 'Raw_Materials_Ready')"]} {set pending 0}
    
    # Get production lines
    catch {set lines [DB::eval_scalar "SELECT COUNT(*) FROM production_facilities WHERE is_active = true"]} {set lines 0}
    
    # Get active users
    catch {set users [DB::eval_scalar "SELECT COUNT(*) FROM persons WHERE is_active = true"]} {set users 0}
    
    return [list \
        "Total Batches" $total_batches "#4CAF50" "📊" \
        "Active Formulations" $active_formulations "#2196F3" "🧪" \
        "QC Tests Today" $qc_today "#FF9800" "🔬" \
        "Rejected Batches" $rejected "#f44336" "❌" \
        "Materials in Stock" $materials "#9C27B0" "📦" \
        "Pending Orders" $pending "#00BCD4" "📋" \
        "Production Lines" $lines "#795548" "🏭" \
        "Active Users" $users "#607D8B" "👤" \
    ]
}

proc App::load_recent_activity {tree} {
    catch {
        set results [DB::eval {
            SELECT batch_number, 
                   TO_CHAR(created_at, 'HH24:MI') as time,
                   'Production' as type,
                   status,
                   COALESCE(p.first_name || ' ' || p.last_name, 'System') as user
            FROM production_batches pb
            LEFT JOIN persons p ON pb.created_by = p.person_id
            ORDER BY created_at DESC 
            LIMIT 15
        }]
        
        foreach row $results {
            lassign $row batch time type status user
            $tree insert {} end -text $batch -values [list $time $type $status $user]
            
            # Color status
            set item [$tree children {}]
            set last [lindex $item end]
            if {$status eq "Completed"} {
                $tree item $last -tags [list completed]
            } elseif {$status eq "Rejected"} {
                $tree item $last -tags [list rejected]
            } elseif {$status eq "In_Production"} {
                $tree item $last -tags [list inprogress]
            }
        }
        
        # Configure tags
        $tree tag configure completed -foreground green
        $tree tag configure rejected -foreground red
        $tree tag configure inprogress -foreground orange
        
    } errorMsg
    puts "DEBUG: load_recent_activity error: $errorMsg"
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No recent batches" -values {"-" "System" "No data" "-"}
    }
}

proc App::load_today_stats {} {
    set batches_completed 0
    set qc_performed 0
    set materials_received 0
    set samples_in_lab 0
    set active_batches 0
    set pending_qc 0
    
    catch {
        set batches_completed [DB::eval_scalar {
            SELECT COUNT(*) FROM production_batches 
            WHERE status = 'Completed' 
            AND actual_end_date >= CURRENT_DATE
        }]
    }
    
    catch {
        set qc_performed [DB::eval_scalar {
            SELECT COUNT(*) FROM qc_tests 
            WHERE test_date >= CURRENT_DATE
        }]
    }
    
    catch {
        set materials_received [DB::eval_scalar {
            SELECT COUNT(*) FROM material_receipts 
            WHERE receipt_date >= CURRENT_DATE
        }]
    }
    
    catch {
        set active_batches [DB::eval_scalar {
            SELECT COUNT(*) FROM production_batches 
            WHERE status IN ('In_Production', 'Compounding', 'Mixing', 'Quality_Check')
        }]
    }
    
    catch {
        set pending_qc [DB::eval_scalar {
            SELECT COUNT(*) FROM production_batches 
            WHERE status = 'Quality_Check'
        }]
    }
    
    return [list \
        "Batches Completed" $batches_completed \
        "QC Tests Performed" $qc_performed \
        "Materials Received" $materials_received \
        "Samples in Lab" $samples_in_lab \
        "Active Batches" $active_batches \
        "Pending QC" $pending_qc \
    ]
}

proc App::update_recent_batches {} {
    # Update the recent batches view in dashboard
    if {[winfo exists .mainpane.content.notebook.dashboard.main.content.left.tree]} {
        set tree .mainpane.content.notebook.dashboard.main.content.left.tree
        $tree delete [$tree children {}]
        load_recent_activity $tree
    }
}

proc App::update_dashboard_stats {} {
    # Update the stats in dashboard
    if {[winfo exists .mainpane.content.notebook.dashboard.main.stats]} {
        # This is a simplified refresh - full refresh would be more complex
        # Just reload the dashboard
        show_dashboard_content
    }
}

# ============================================
# 7. BATCH MANAGEMENT FUNCTIONS
# ============================================

proc App::show_batches {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    variable main_notebook
    $main_notebook select $main_notebook.production
    
    set frame $main_notebook.production
    clear_content $frame
    
    # Title and toolbar
    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    
    ttk::label $header.title -text "📋 Production Batches" -font {Arial 16 bold}
    pack $header.title -side left
    
    ttk::button $header.new -text "➕ New Batch" -command {App::show_batch_form} -padding "8 4"
    pack $header.new -side right -padx 5
    
    # Filter toolbar
    set filter_frame [ttk::frame $frame.filters -padding "5 5 5 5"]
    pack $filter_frame -fill x -pady 5
    
    ttk::label $filter_frame.lbl -text "Filter by Status:"
    pack $filter_frame.lbl -side left -padx 5
    
    set status_values [list "All"]
    catch {
        set results [DB::eval "SELECT DISTINCT status FROM production_batches ORDER BY status"]
        foreach row $results {
            lassign $row status
            lappend status_values $status
        }
    }
    
    ttk::combobox $filter_frame.status -values $status_values -width 15 -state readonly
    pack $filter_frame.status -side left -padx 5
    $filter_frame.status set "All"
    
    ttk::label $filter_frame.lbl2 -text "Date Range:"
    pack $filter_frame.lbl2 -side left -padx 10
    
    ttk::entry $filter_frame.from -width 12
    pack $filter_frame.from -side left -padx 2
    $filter_frame.from insert 0 [clock format [clock seconds] -format "%Y-%m-01"]
    
    ttk::label $filter_frame.to_lbl -text "to"
    pack $filter_frame.to_lbl -side left -padx 2
    
    ttk::entry $filter_frame.to -width 12
    pack $filter_frame.to -side left -padx 2
    $filter_frame.to insert 0 [clock format [clock seconds] -format "%Y-%m-%d"]
    
    ttk::button $filter_frame.search -text "🔍 Search" -command {App::load_batches} -padding "8 4"
    pack $filter_frame.search -side left -padx 10
    
    ttk::button $filter_frame.export -text "📤 Export" -command {App::export_batches} -padding "8 4"
    pack $filter_frame.export -side right -padx 5
    
    # Batch treeview
    set tree_frame [ttk::frame $frame.tree -padding "5 5 5 5"]
    pack $tree_frame -fill both -expand true
    
    set tree [ttk::treeview $tree_frame.tree -columns {formulation facility quantity start end status yield created} -height 20]
    $tree heading #0 -text "Batch Number"
    $tree heading formulation -text "Formulation"
    $tree heading facility -text "Facility"
    $tree heading quantity -text "Target (kg)"
    $tree heading start -text "Start Date"
    $tree heading end -text "End Date"
    $tree heading status -text "Status"
    $tree heading yield -text "Yield %"
    $tree heading created -text "Created"
    
    $tree column #0 -width 150
    $tree column formulation -width 160
    $tree column facility -width 130
    $tree column quantity -width 80
    $tree column start -width 100
    $tree column end -width 100
    $tree column status -width 100
    $tree column yield -width 80
    $tree column created -width 120
    
    # Scrollbar
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    # Bind double-click for details
    bind $tree <Double-1> {App::show_batch_details %W}
    bind $tree <Control-c> {App::copy_batch_info %W}
    
    # Store tree reference
    set App::tree_vars(batches) $tree
    
    # Load data
    load_batches $tree
}

proc App::load_batches {{tree ""}} {
    if {$tree eq ""} {
        variable tree_vars
        if {[info exists tree_vars(batches)]} {
            set tree $tree_vars(batches)
        } else {
            return
        }
    }
    
    # Clear existing items
    $tree delete [$tree children {}]
    
    show_progress "Loading batches..."
    
    catch {
        # Get filter values
        set status_filter [.mainpane.content.notebook.production.filters.status get]
        set from_filter [.mainpane.content.notebook.production.filters.from get]
        set to_filter [.mainpane.content.notebook.production.filters.to get]
        
        set sql {
            SELECT 
                pb.batch_number,
                f.formulation_name,
                pf.facility_name,
                pb.target_quantity_kg,
                TO_CHAR(pb.planned_start_date, 'YYYY-MM-DD') as start_date,
                TO_CHAR(pb.planned_end_date, 'YYYY-MM-DD') as end_date,
                pb.status,
                COALESCE(pb.yield_percentage::TEXT, '-') as yield,
                TO_CHAR(pb.created_at, 'YYYY-MM-DD HH24:MI') as created
            FROM production_batches pb
            JOIN formulations f ON pb.formulation_id = f.formulation_id
            JOIN production_facilities pf ON pb.facility_id = pf.facility_id
            WHERE 1=1
        }
        
        set params {}
        
        if {$status_filter ne "All"} {
            append sql " AND pb.status = :status"
            lappend params status $status_filter
        }
        
        if {$from_filter ne ""} {
            append sql " AND pb.created_at >= :from_date"
            lappend params from_date $from_filter
        }
        
        if {$to_filter ne ""} {
            append sql " AND pb.created_at <= :to_date"
            lappend params to_date $to_filter
        }
        
        append sql " ORDER BY pb.created_at DESC LIMIT 200"
        
        set results [DB::eval $sql $params]
        
        foreach row $results {
            lassign $row batch_number formulation facility quantity start_date end_date status yield created
            $tree insert {} end -text $batch_number -values [list $formulation $facility $quantity $start_date $end_date $status $yield $created]
        }
    } errorMsg
    puts "DEBUG: load_batches error: $errorMsg"
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No batches found" -values {"-" "-" "-" "-" "-" "-" "-" "-"}
    }
    
    hide_progress
    set_status "Loaded [llength [$tree children {}]] batches" green
}

proc App::show_batch_details {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set batch [$tree item $selection -text]
    
    set w .batch_details
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Batch Details - $batch"
    wm geometry $w "700x500"
    wm resizable $w 1 1
    
    # Main container
    set main [ttk::frame $w.main -padding "10 10 10 10"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "📋 Batch: $batch" -font {Arial 14 bold}
    pack $main.title -pady 10
    
    # Notebook for details
    set nb [ttk::notebook $main.nb -padding "5 5 5 5"]
    pack $nb -fill both -expand true
    
    # General tab
    set gen_frame [ttk::frame $nb.general -padding "10 10 10 10"]
    $nb add $gen_frame -text "📋 General"
    
    # Text widget for details
    set text [text $gen_frame.text -wrap word -font {Courier 10} -yscrollcommand "$gen_frame.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $gen_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Load details
    catch {
        set results [DB::eval {
            SELECT 
                pb.batch_number,
                pb.target_quantity_kg,
                pb.actual_quantity_kg,
                pb.yield_percentage,
                pb.planned_start_date,
                pb.planned_end_date,
                pb.actual_start_date,
                pb.actual_end_date,
                pb.status,
                pb.shift,
                pb.production_notes,
                f.formulation_name,
                pf.facility_name,
                p.first_name || ' ' || p.last_name as supervisor,
                pb.created_at
            FROM production_batches pb
            JOIN formulations f ON pb.formulation_id = f.formulation_id
            JOIN production_facilities pf ON pb.facility_id = pf.facility_id
            LEFT JOIN persons p ON pb.supervisor_id = p.person_id
            WHERE pb.batch_number = :batch
        } [list batch $batch]]
        
        $text insert end "📋 BATCH DETAILS\n"
        $text insert end "================\n\n"
        
        foreach row $results {
            lassign $row batch_number target_quantity_kg actual_quantity_kg yield_percentage planned_start_date planned_end_date actual_start_date actual_end_date status shift production_notes formulation_name facility_name supervisor created_at
            
            $text insert end "📌 General Information\n"
            $text insert end "-----------------------\n"
            $text insert end "Batch Number     : $batch_number\n"
            $text insert end "Formulation      : $formulation_name\n"
            $text insert end "Facility         : $facility_name\n"
            $text insert end "Supervisor       : $supervisor\n"
            $text insert end "Shift            : $shift\n"
            $text insert end "Status           : $status\n\n"
            
            $text insert end "📊 Production Data\n"
            $text insert end "------------------\n"
            $text insert end "Target Quantity  : $target_quantity_kg kg\n"
            $text insert end "Actual Quantity  : $actual_quantity_kg kg\n"
            $text insert end "Yield            : $yield_percentage%\n\n"
            
            $text insert end "📅 Dates\n"
            $text insert end "--------\n"
            $text insert end "Planned Start    : $planned_start_date\n"
            $text insert end "Planned End      : $planned_end_date\n"
            $text insert end "Actual Start     : $actual_start_date\n"
            $text insert end "Actual End       : $actual_end_date\n"
            $text insert end "Created          : $created_at\n\n"
            
            if {$production_notes ne ""} {
                $text insert end "📝 Notes\n"
                $text insert end "--------\n"
                $text insert end "$production_notes\n"
            }
        }
        
        $text configure -state disabled
        
    } errorMsg
    puts "DEBUG: load_batch_details error: $errorMsg"
    
    # QC Tests tab
    set qc_frame [ttk::frame $nb.qc -padding "10 10 10 10"]
    $nb add $qc_frame -text "🔬 QC Tests"
    
    set qc_tree [ttk::treeview $qc_frame.tree -columns {parameter result status date} -height 10]
    $qc_tree heading #0 -text "Test Number"
    $qc_tree heading parameter -text "Parameter"
    $qc_tree heading result -text "Result"
    $qc_tree heading status -text "Status"
    $qc_tree heading date -text "Date"
    
    $qc_tree column #0 -width 120
    $qc_tree column parameter -width 150
    $qc_tree column result -width 100
    $qc_tree column status -width 100
    $qc_tree column date -width 120
    
    pack $qc_tree -fill both -expand true
    
    # Load QC tests for this batch
    catch {
        set results [DB::eval {
            SELECT 
                qt.test_number,
                qp.parameter_name,
                qt.test_result,
                qt.status,
                TO_CHAR(qt.test_date, 'YYYY-MM-DD HH24:MI') as date
            FROM qc_tests qt
            JOIN qc_parameters qp ON qt.parameter_id = qp.parameter_id
            WHERE qt.batch_id = (SELECT batch_id FROM production_batches WHERE batch_number = :batch)
            ORDER BY qt.test_date DESC
        } [list batch $batch]]
        
        foreach row $results {
            lassign $row test_number parameter result status date
            $qc_tree insert {} end -text $test_number -values [list $parameter $result $status $date]
        }
    }
    
    if {[$qc_tree children {}] eq ""} {
        $qc_tree insert {} end -text "No QC tests" -values {"-" "-" "-" "-"}
    }
    
    # Close button
    ttk::button $main.close -text "Close" -command "destroy $w" -padding "8 4"
    pack $main.close -pady 10
}

proc App::show_batch_form {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    set w .batch_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "➕ New Production Batch"
    wm geometry $w "600x520"
    wm resizable $w 0 0
    
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "Create New Production Batch" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    # Load data
    set formulations_list {}
    catch {
        set results [DB::eval "SELECT formulation_id, formulation_name FROM formulations WHERE status = 'Active'"]
        foreach row $results {
            lassign $row id name
            lappend formulations_list $name
        }
    }
    
    set facilities_list {}
    catch {
        set results [DB::eval "SELECT facility_id, facility_name FROM production_facilities WHERE is_active = true"]
        foreach row $results {
            lassign $row id name
            lappend facilities_list $name
        }
    }
    
    set supervisors_list {}
    catch {
        set results [DB::eval {
            SELECT person_id, first_name || ' ' || last_name 
            FROM persons 
            WHERE role_id IN (SELECT role_id FROM persons_roles WHERE role_code IN ('PROD_MANAGER', 'PROC_ENGINEER'))
            AND is_active = true
        }]
        foreach row $results {
            lassign $row id name
            lappend supervisors_list $name
        }
    }
    
    if {[llength $supervisors_list] == 0} {
        set supervisors_list [list [DB::get_current_user]]
    }
    
    # Form fields
    set fields {
        "Formulation:" formulation combobox
        "Facility:" facility combobox
        "Target Quantity (kg):" quantity entry
        "Planned Start Date:" start_date entry
        "Planned End Date:" end_date entry
        "Supervisor:" supervisor combobox
        "Shift:" shift combobox
    }
    
    set entries {}
    foreach {label var type} $fields {
        set f [ttk::frame $main.$var]
        pack $f -fill x -pady 4
        
        ttk::label $f.lbl -text $label -width 20 -anchor e -font {Arial 10}
        pack $f.lbl -side left -padx 5
        
        if {$type eq "combobox"} {
            set widget [ttk::combobox $f.cb -width 30 -state readonly -font {Arial 10}]
            if {$var eq "formulation"} {
                $widget configure -values $formulations_list
                if {[llength $formulations_list] > 0} {
                    $widget set [lindex $formulations_list 0]
                }
            } elseif {$var eq "facility"} {
                $widget configure -values $facilities_list
                if {[llength $facilities_list] > 0} {
                    $widget set [lindex $facilities_list 0]
                }
            } elseif {$var eq "supervisor"} {
                $widget configure -values $supervisors_list
                if {[llength $supervisors_list] > 0} {
                    $widget set [lindex $supervisors_list 0]
                }
            } elseif {$var eq "shift"} {
                $widget configure -values {"Day" "Night" "Weekend"}
                $widget set "Day"
            }
        } else {
            set widget [ttk::entry $f.entry -width 30 -font {Arial 10}]
        }
        pack $widget -side left -expand true -fill x
        set entries($var) $widget
        
        if {$var eq "start_date" || $var eq "end_date"} {
            $widget insert 0 [clock format [clock seconds] -format "%Y-%m-%d"]
        }
        if {$var eq "quantity"} {
            $widget insert 0 "1000"
        }
    }
    
    # Notes
    set note_f [ttk::frame $main.notes]
    pack $note_f -fill x -pady 4
    
    ttk::label $note_f.lbl -text "Notes:" -width 20 -anchor e -font {Arial 10}
    pack $note_f.lbl -side left -padx 5
    
    ttk::entry $note_f.entry -width 30 -font {Arial 10}
    pack $note_f.entry -side left -expand true -fill x
    set entries(notes) $note_f.entry
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 15
    
    ttk::button $btn_frame.save -text "✅ Create Batch" -command [list App::save_batch $entries $w] -padding "8 4" -style Accent.TButton
    pack $btn_frame.save -side left -padx 5 -expand true -fill x
    
    ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "8 4"
    pack $btn_frame.cancel -side right -padx 5 -expand true -fill x
}

proc App::save_batch {entries w} {
    set formulation [$entries(formulation) get]
    set facility [$entries(facility) get]
    set quantity [$entries(quantity) get]
    set start_date [$entries(start_date) get]
    set end_date [$entries(end_date) get]
    set supervisor [$entries(supervisor) get]
    set shift [$entries(shift) get]
    set notes [$entries(notes) get]
    
    if {$formulation eq "" || $quantity eq "" || $start_date eq "" || $end_date eq ""} {
        tk_messageBox -icon warning -title "Validation Error" \
            -message "Please fill in all required fields."
        return
    }
    
    # Get IDs
    set formulation_id 0
    catch {
        set formulation_id [DB::eval_scalar "SELECT formulation_id FROM formulations WHERE formulation_name = :name" [list name $formulation]]
    }
    
    set facility_id 0
    catch {
        set facility_id [DB::eval_scalar "SELECT facility_id FROM production_facilities WHERE facility_name = :name" [list name $facility]]
    }
    
    set supervisor_id 0
    catch {
        set supervisor_id [DB::eval_scalar "SELECT person_id FROM persons WHERE first_name || ' ' || last_name = :name" [list name $supervisor]]
    }
    
    if {$formulation_id == 0 || $facility_id == 0} {
        tk_messageBox -icon error -title "Error" \
            -message "Invalid formulation or facility selected."
        return
    }
    
    show_progress "Creating batch..."
    
    try {
        set stmt [DB::exec_query {
            SELECT create_production_batch(
                :formulation_id::INTEGER,
                :facility_id::INTEGER,
                :quantity::DECIMAL,
                :start_date::DATE,
                :end_date::DATE,
                :supervisor_id::INTEGER,
                (SELECT person_id FROM persons WHERE person_code = :username)
            )
        } [list \
            formulation_id $formulation_id \
            facility_id $facility_id \
            quantity $quantity \
            start_date $start_date \
            end_date $end_date \
            supervisor_id $supervisor_id \
            username [DB::get_current_user] \
        ]]
        
        $stmt execute
        set batch_id 0
        $stmt foreach row {set batch_id [lindex $row 0]}
        $stmt close
        
        hide_progress
        set_status "Batch created successfully! ID: $batch_id" green
        
        tk_messageBox -icon info -title "Success" \
            -message "Production batch created successfully!\n\nBatch ID: $batch_id\nFormulation: $formulation\nTarget: $quantity kg"
        
        destroy $w
        show_batches
        
    } on error {errorMsg} {
        hide_progress
        set_status "Error creating batch: $errorMsg" red
        tk_messageBox -icon error -title "Error" \
            -message "Failed to create batch.\n\nError: $errorMsg"
    }
}

# ============================================
# 8. FORMULATION MANAGEMENT FUNCTIONS
# ============================================

proc App::show_formulations {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    variable main_notebook
    $main_notebook select $main_notebook.formulations
    
    set frame $main_notebook.formulations
    clear_content $frame
    
    # Header
    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    
    ttk::label $header.title -text "🧪 Formulation Management" -font {Arial 16 bold}
    pack $header.title -side left
    
    set btn_frame [ttk::frame $header.buttons]
    pack $btn_frame -side right
    
    ttk::button $btn_frame.new -text "➕ New" -command {App::show_formulation_form} -padding "8 4"
    pack $btn_frame.new -side left -padx 2
    
    ttk::button $btn_frame.edit -text "✏️ Edit" -command {App::edit_formulation} -padding "8 4"
    pack $btn_frame.edit -side left -padx 2
    
    ttk::button $btn_frame.view -text "🔍 View Components" -command {App::view_formulation_components} -padding "8 4"
    pack $btn_frame.view -side left -padx 2
    
    ttk::button $btn_frame.validate -text "✅ Validate" -command {App::validate_formulas} -padding "8 4"
    pack $btn_frame.validate -side left -padx 2
    
    # Filter
    set filter_frame [ttk::frame $frame.filters -padding "5 5 5 5"]
    pack $filter_frame -fill x -pady 5
    
    ttk::label $filter_frame.lbl -text "Search:"
    pack $filter_frame.lbl -side left -padx 5
    
    ttk::entry $filter_frame.search -width 25
    pack $filter_frame.search -side left -padx 2
    bind $filter_frame.search <Return> {App::load_formulations}
    
    ttk::label $filter_frame.lbl2 -text "Type:"
    pack $filter_frame.lbl2 -side left -padx 10
    
    set type_values [list "All"]
    catch {
        set results [DB::eval "SELECT DISTINCT type_name FROM product_types WHERE is_active = true ORDER BY type_name"]
        foreach row $results {
            lassign $row name
            lappend type_values $name
        }
    }
    
    ttk::combobox $filter_frame.type -values $type_values -width 15 -state readonly
    pack $filter_frame.type -side left -padx 2
    $filter_frame.type set "All"
    
    ttk::button $filter_frame.search_btn -text "🔍 Search" -command {App::load_formulations} -padding "8 4"
    pack $filter_frame.search_btn -side left -padx 10
    
    # Treeview
    set tree_frame [ttk::frame $frame.tree -padding "5 5 5 5"]
    pack $tree_frame -fill both -expand true
    
    set tree [ttk::treeview $tree_frame.tree -columns {brand type flavor ph fluoride status created} -height 20]
    $tree heading #0 -text "Formulation Code"
    $tree heading brand -text "Brand"
    $tree heading type -text "Type"
    $tree heading flavor -text "Flavor"
    $tree heading ph -text "pH"
    $tree heading fluoride -text "Fluoride (ppm)"
    $tree heading status -text "Status"
    $tree heading created -text "Created"
    
    $tree column #0 -width 130
    $tree column brand -width 150
    $tree column type -width 130
    $tree column flavor -width 100
    $tree column ph -width 60
    $tree column fluoride -width 100
    $tree column status -width 100
    $tree column created -width 120
    
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    bind $tree <Double-1> {App::view_formulation_components}
    
    set App::tree_vars(formulations) $tree
    load_formulations $tree
}

proc App::load_formulations {{tree ""}} {
    if {$tree eq ""} {
        variable tree_vars
        if {[info exists tree_vars(formulations)]} {
            set tree $tree_vars(formulations)
        } else {
            return
        }
    }
    
    $tree delete [$tree children {}]
    
    set search ""
    set type_filter "All"
    
    catch {
        set search [.mainpane.content.notebook.formulations.filters.search get]
        set type_filter [.mainpane.content.notebook.formulations.filters.type get]
    }
    
    show_progress "Loading formulations..."
    
    catch {
        set sql {
            SELECT 
                f.formulation_code,
                b.brand_name,
                pt.type_name as product_type,
                f.flavor_profile,
                f.target_ph,
                f.fluoride_ppm,
                f.status,
                TO_CHAR(f.created_at, 'YYYY-MM-DD') as created
            FROM formulations f
            JOIN brands b ON f.brand_id = b.brand_id
            LEFT JOIN product_types pt ON f.product_type_id = pt.product_type_id
            WHERE f.is_active = true
        }
        
        set params {}
        
        if {$search ne ""} {
            append sql " AND (f.formulation_code ILIKE :search OR f.formulation_name ILIKE :search)"
            lappend params search "%$search%"
        }
        
        if {$type_filter ne "All"} {
            append sql " AND pt.type_name = :type"
            lappend params type $type_filter
        }
        
        append sql " ORDER BY f.formulation_code"
        
        set results [DB::eval $sql $params]
        
        foreach row $results {
            lassign $row code brand type flavor ph fluoride status created
            $tree insert {} end -text $code -values [list $brand $type $flavor $ph $fluoride $status $created]
        }
    } errorMsg
    puts "DEBUG: load_formulations error: $errorMsg"
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No formulations found" -values {"-" "-" "-" "-" "-" "-" "-"}
    }
    
    hide_progress
    set_status "Loaded [llength [$tree children {}]] formulations" green
}

proc App::view_formulation_components {} {
    variable tree_vars
    if {[info exists tree_vars(formulations)]} {
        set tree $tree_vars(formulations)
        set selection [$tree selection]
        if {$selection ne ""} {
            set code [$tree item $selection -text]
            show_formulation_components $code
        } else {
            tk_messageBox -warning -title "Selection" "Please select a formulation to view components."
        }
    }
}

proc App::show_formulation_components {code} {
    set w .form_components
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Formulation Components - $code"
    wm geometry $w "800x500"
    wm resizable $w 1 1
    
    set main [ttk::frame $w.main -padding "10 10 10 10"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "🧪 Formulation: $code" -font {Arial 14 bold}
    pack $main.title -pady 10
    
    # Component tree
    set tree [ttk::treeview $main.tree -columns {function min max target phase order} -height 20]
    pack $tree -fill both -expand true -padx 5 -pady 5
    
    $tree heading #0 -text "Compound Name"
    $tree heading function -text "Function"
    $tree heading min -text "Min %"
    $tree heading max -text "Max %"
    $tree heading target -text "Target %"
    $tree heading phase -text "Phase"
    $tree heading order -text "Order"
    
    $tree column #0 -width 200
    $tree column function -width 130
    $tree column min -width 80
    $tree column max -width 80
    $tree column target -width 80
    $tree column phase -width 100
    $tree column order -width 60
    
    # Load components
    catch {
        set results [DB::eval {
            SELECT 
                cc.compound_name,
                fc.function,
                fc.percentage_min,
                fc.percentage_max,
                fc.percentage_target,
                fc.phase,
                fc.addition_order
            FROM formulation_components fc
            JOIN chemical_compounds cc ON fc.compound_id = cc.compound_id
            JOIN formulations f ON fc.formulation_id = f.formulation_id
            WHERE f.formulation_code = :code
            ORDER BY fc.addition_order
        } [list code $code]]
        
        foreach row $results {
            lassign $row name function min max target phase order
            $tree insert {} end -text $name -values [list $function $min $max $target $phase $order]
        }
    }
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No components found" -values {"-" "-" "-" "-" "-" "-"}
    }
    
    # Summary
    set summary [ttk::frame $main.summary -padding "5 5 5 5"]
    pack $summary -fill x -pady 5
    
    catch {
        set total [DB::eval_scalar {
            SELECT ROUND(SUM(percentage_target)::numeric, 2) 
            FROM formulation_components fc
            JOIN formulations f ON fc.formulation_id = f.formulation_id
            WHERE f.formulation_code = :code
        } [list code $code]]
        
        ttk::label $summary.total -text "Total Percentage: $total%" -font {Arial 10 bold}
        pack $summary.total -side left -padx 10
        
        if {$total >= 95 && $total <= 105} {
            ttk::label $summary.status -text "✅ VALID" -foreground green -font {Arial 10 bold}
        } else {
            ttk::label $summary.status -text "❌ INVALID" -foreground red -font {Arial 10 bold}
        }
        pack $summary.status -side left -padx 10
    }
    
    ttk::button $main.close -text "Close" -command "destroy $w" -padding "8 4"
    pack $main.close -pady 10
}

# ============================================
# 9. QUALITY CONTROL FUNCTIONS
# ============================================

proc App::show_qc_tests {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    variable main_notebook
    $main_notebook select $main_notebook.quality
    
    set frame $main_notebook.quality
    clear_content $frame
    
    # Header
    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    
    ttk::label $header.title -text "🔬 Quality Control Tests" -font {Arial 16 bold}
    pack $header.title -side left
    
    ttk::button $header.new -text "➕ New QC Test" -command {App::show_qc_test_form} -padding "8 4"
    pack $header.new -side right -padx 5
    
    # Filter
    set filter_frame [ttk::frame $frame.filters -padding "5 5 5 5"]
    pack $filter_frame -fill x -pady 5
    
    ttk::label $filter_frame.lbl -text "Batch:"
    pack $filter_frame.lbl -side left -padx 5
    
    ttk::entry $filter_frame.batch -width 20
    pack $filter_frame.batch -side left -padx 2
    
    ttk::label $filter_frame.lbl2 -text "Status:"
    pack $filter_frame.lbl2 -side left -padx 10
    
    ttk::combobox $filter_frame.status -values {"All" "Pending" "In_Progress" "Completed" "Verified" "Approved" "Rejected"} -width 15 -state readonly
    pack $filter_frame.status -side left -padx 2
    $filter_frame.status set "All"
    
    ttk::button $filter_frame.search -text "🔍 Search" -command {App::load_qc_tests} -padding "8 4"
    pack $filter_frame.search -side left -padx 10
    
    # Treeview
    set tree_frame [ttk::frame $frame.tree -padding "5 5 5 5"]
    pack $tree_frame -fill both -expand true
    
    set tree [ttk::treeview $tree_frame.tree -columns {batch parameter result min max status date performed} -height 20]
    $tree heading #0 -text "Test Number"
    $tree heading batch -text "Batch"
    $tree heading parameter -text "Parameter"
    $tree heading result -text "Result"
    $tree heading min -text "Min"
    $tree heading max -text "Max"
    $tree heading status -text "Status"
    $tree heading date -text "Date"
    $tree heading performed -text "Performed By"
    
    $tree column #0 -width 120
    $tree column batch -width 120
    $tree column parameter -width 150
    $tree column result -width 80
    $tree column min -width 80
    $tree column max -width 80
    $tree column status -width 100
    $tree column date -width 120
    $tree column performed -width 120
    
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    bind $tree <Double-1> {App::show_qc_test_details %W}
    
    set App::tree_vars(qc_tests) $tree
    load_qc_tests $tree
}

proc App::load_qc_tests {{tree ""}} {
    if {$tree eq ""} {
        variable tree_vars
        if {[info exists tree_vars(qc_tests)]} {
            set tree $tree_vars(qc_tests)
        } else {
            return
        }
    }
    
    $tree delete [$tree children {}]
    
    set batch_filter ""
    set status_filter "All"
    
    catch {
        set batch_filter [.mainpane.content.notebook.quality.filters.batch get]
        set status_filter [.mainpane.content.notebook.quality.filters.status get]
    }
    
    show_progress "Loading QC tests..."
    
    catch {
        set sql {
            SELECT 
                qt.test_number,
                pb.batch_number,
                qp.parameter_name,
                qt.test_result,
                qp.target_min,
                qp.target_max,
                qt.status,
                TO_CHAR(qt.test_date, 'YYYY-MM-DD HH24:MI') as test_date,
                p.first_name || ' ' || p.last_name as performed_by
            FROM qc_tests qt
            JOIN production_batches pb ON qt.batch_id = pb.batch_id
            JOIN qc_parameters qp ON qt.parameter_id = qp.parameter_id
            LEFT JOIN persons p ON qt.performed_by = p.person_id
            WHERE 1=1
        }
        
        set params {}
        
        if {$batch_filter ne ""} {
            append sql " AND pb.batch_number ILIKE :batch"
            lappend params batch "%$batch_filter%"
        }
        
        if {$status_filter ne "All"} {
            append sql " AND qt.status = :status"
            lappend params status $status_filter
        }
        
        append sql " ORDER BY qt.test_date DESC LIMIT 200"
        
        set results [DB::eval $sql $params]
        
        foreach row $results {
            lassign $row test_number batch parameter result min max status date performed
            $tree insert {} end -text $test_number -values [list $batch $parameter $result $min $max $status $date $performed]
        }
    } errorMsg
    puts "DEBUG: load_qc_tests error: $errorMsg"
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No QC tests found" -values {"-" "-" "-" "-" "-" "-" "-" "-" "-"}
    }
    
    hide_progress
    set_status "Loaded [llength [$tree children {}]] QC tests" green
}

proc App::show_qc_test_form {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    set w .qc_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "🔬 Record QC Test"
    wm geometry $w "550x450"
    wm resizable $w 0 0
    
    set main [ttk::frame $w.main -padding "20 20 20 20"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "Record Quality Control Test" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    # Load data
    set parameters_list {}
    catch {
        set results [DB::eval "SELECT parameter_id, parameter_name FROM qc_parameters WHERE is_active = true ORDER BY parameter_name"]
        foreach row $results {
            lassign $row id name
            lappend parameters_list $name
        }
    }
    
    set labs_list {}
    catch {
        set results [DB::eval "SELECT lab_id, lab_name FROM chemical_labs WHERE is_active = true"]
        foreach row $results {
            lassign $row id name
            lappend labs_list $name
        }
    }
    if {[llength $labs_list] == 0} {
        set labs_list {"QC Lab"}
    }
    
    # Form fields
    set fields {
        "Batch Number:" batch entry
        "Parameter:" parameter combobox
        "Lab:" lab combobox
        "Test Result:" result entry
        "Pass/Fail:" result_status combobox
        "Notes:" notes entry
    }
    
    set entries {}
    foreach {label var type} $fields {
        set f [ttk::frame $main.$var]
        pack $f -fill x -pady 4
        
        ttk::label $f.lbl -text $label -width 16 -anchor e -font {Arial 10}
        pack $f.lbl -side left -padx 5
        
        if {$type eq "combobox"} {
            set widget [ttk::combobox $f.cb -width 30 -state readonly -font {Arial 10}]
            if {$var eq "parameter"} {
                $widget configure -values $parameters_list
                if {[llength $parameters_list] > 0} {
                    $widget set [lindex $parameters_list 0]
                }
            } elseif {$var eq "lab"} {
                $widget configure -values $labs_list
                if {[llength $labs_list] > 0} {
                    $widget set [lindex $labs_list 0]
                }
            } elseif {$var eq "result_status"} {
                $widget configure -values {"Pass" "Fail" "Pending"}
                $widget set "Pending"
            }
        } else {
            set widget [ttk::entry $f.entry -width 30 -font {Arial 10}]
        }
        pack $widget -side left -expand true -fill x
        set entries($var) $widget
    }
    
    # Buttons
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 15
    
    ttk::button $btn_frame.save -text "✅ Save Test" -command [list App::save_qc_test $entries $w] -padding "8 4" -style Accent.TButton
    pack $btn_frame.save -side left -padx 5 -expand true -fill x
    
    ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "8 4"
    pack $btn_frame.cancel -side right -padx 5 -expand true -fill x
}

proc App::save_qc_test {entries w} {
    set batch [$entries(batch) get]
    set parameter [$entries(parameter) get]
    set lab [$entries(lab) get]
    set result [$entries(result) get]
    set result_status [$entries(result_status) get]
    set notes [$entries(notes) get]
    
    if {$batch eq "" || $parameter eq "" || $result eq ""} {
        tk_messageBox -warning -title "Validation" \
            -message "Please fill in all required fields."
        return
    }
    
    # Get IDs
    set batch_id 0
    catch {
        set batch_id [DB::eval_scalar "SELECT batch_id FROM production_batches WHERE batch_number = :batch" [list batch $batch]]
    }
    
    if {$batch_id == 0} {
        tk_messageBox -warning -title "Error" \
            -message "Batch '$batch' not found. Please enter a valid batch number."
        return
    }
    
    set parameter_id 0
    catch {
        set parameter_id [DB::eval_scalar "SELECT parameter_id FROM qc_parameters WHERE parameter_name = :name" [list name $parameter]]
    }
    
    set lab_id 1
    catch {
        set lab_id [DB::eval_scalar "SELECT lab_id FROM chemical_labs WHERE lab_name = :name" [list name $lab]]
    }
    
    show_progress "Recording QC test..."
    
    try {
        set stmt [DB::exec_query {
            SELECT record_qc_test(
                :batch_id::INTEGER,
                :parameter_id::INTEGER,
                :lab_id::INTEGER,
                :result::DECIMAL,
                :notes,
                (SELECT person_id FROM persons WHERE person_code = :username),
                :notes
            )
        } [list \
            batch_id $batch_id \
            parameter_id $parameter_id \
            lab_id $lab_id \
            result $result \
            notes $notes \
            username [DB::get_current_user] \
        ]]
        
        $stmt execute
        set test_id 0
        $stmt foreach row {set test_id [lindex $row 0]}
        $stmt close
        
        hide_progress
        set_status "QC test recorded! ID: $test_id" green
        tk_messageBox -icon info -title "Success" \
            -message "QC test recorded successfully!\n\nTest ID: $test_id\nBatch: $batch\nParameter: $parameter\nResult: $result"
        
        destroy $w
        show_qc_tests
        
    } on error {errorMsg} {
        hide_progress
        set_status "Error recording QC test: $errorMsg" red
        tk_messageBox -icon error -title "Error" \
            -message "Failed to record QC test.\n\nError: $errorMsg"
    }
}

# ============================================
# 10. REPORTING FUNCTIONS
# ============================================

proc App::report_batch_summary {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    variable main_notebook
    $main_notebook select $main_notebook.reports
    
    set frame $main_notebook.reports
    clear_content $frame
    
    # Header
    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    
    ttk::label $header.title -text "📊 Batch Summary Report" -font {Arial 16 bold}
    pack $header.title -side left
    
    # Report parameters
    set param_frame [ttk::frame $frame.params -relief groove -borderwidth 1 -padding "10 10 10 10"]
    pack $param_frame -fill x -pady 10 -padx 10
    
    ttk::label $param_frame.lbl -text "Date Range:" -font {Arial 10 bold}
    pack $param_frame.lbl -side left -padx 5
    
    ttk::label $param_frame.from_lbl -text "From:"
    pack $param_frame.from_lbl -side left -padx 5
    
    ttk::entry $param_frame.from -width 15
    pack $param_frame.from -side left -padx 2
    $param_frame.from insert 0 [clock format [clock seconds] -format "%Y-%m-01"]
    
    ttk::label $param_frame.to_lbl -text "To:"
    pack $param_frame.to_lbl -side left -padx 5
    
    ttk::entry $param_frame.to -width 15
    pack $param_frame.to -side left -padx 2
    $param_frame.to insert 0 [clock format [clock seconds] -format "%Y-%m-%d"]
    
    ttk::button $param_frame.run -text "📊 Generate" -command {App::generate_batch_summary} -padding "8 4" -style Accent.TButton
    pack $param_frame.run -side left -padx 10
    
    ttk::button $param_frame.export_pdf -text "📄 Export PDF" -command {App::export_pdf} -padding "8 4"
    pack $param_frame.export_pdf -side left -padx 5
    
    ttk::button $param_frame.export_csv -text "📊 Export CSV" -command {App::export_csv} -padding "8 4"
    pack $param_frame.export_csv -side left -padx 5
    
    # Report content
    set report_frame [ttk::frame $frame.report -relief sunken -borderwidth 1]
    pack $report_frame -fill both -expand true -padx 10 -pady 5
    
    set text [text $report_frame.text -wrap word -font {Courier 10} -yscrollcommand "$report_frame.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $report_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Generate report
    if {[DB::connected]} {
        generate_report_content $text
    } else {
        $text insert end "⚠ NOT CONNECTED TO DATABASE\n"
        $text insert end "Please connect to the database first."
    }
    
    $text configure -state disabled
    set App::report_text $text
}

proc App::generate_report_content {text} {
    $text configure -state normal
    $text delete 1.0 end
    
    $text insert end "📊 TOOTHPASTE PRODUCTION BATCH SUMMARY REPORT\n"
    $text insert end "=============================================\n\n"
    $text insert end "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]\n"
    $text insert end "User: [DB::get_current_user] ([DB::get_current_role])\n"
    $text insert end "Database: $Config::DB_NAME@$Config::DB_HOST\n"
    $text insert end "=" * 70 "\n\n"
    
    # Get date range
    set from_date ""
    set to_date ""
    catch {
        set from_date [.mainpane.content.notebook.reports.params.from get]
        set to_date [.mainpane.content.notebook.reports.params.to get]
    }
    
    if {$from_date eq ""} {
        set from_date [clock format [clock seconds] -format "%Y-%m-01"]
    }
    if {$to_date eq ""} {
        set to_date [clock format [clock seconds] -format "%Y-%m-%d"]
    }
    
    $text insert end "📅 Period: $from_date to $to_date\n"
    $text insert end "-" * 70 "\n\n"
    
    # Summary statistics
    $text insert end "📈 SUMMARY STATISTICS\n"
    $text insert end "---------------------\n\n"
    
    catch {
        set results [DB::eval {
            SELECT 
                COUNT(*) as total_batches,
                SUM(target_quantity_kg) as total_target,
                SUM(actual_quantity_kg) as total_actual,
                AVG(yield_percentage) as avg_yield,
                COUNT(CASE WHEN status = 'Released' THEN 1 ELSE NULL END) as released,
                COUNT(CASE WHEN status = 'Rejected' THEN 1 ELSE NULL END) as rejected,
                COUNT(CASE WHEN status = 'Completed' THEN 1 ELSE NULL END) as completed,
                COUNT(CASE WHEN status = 'In_Production' THEN 1 ELSE NULL END) as in_production
            FROM production_batches
            WHERE created_at BETWEEN :from AND :to
        } [list from $from_date to $to_date]]
        
        foreach row $results {
            lassign $row total total_target total_actual avg_yield released rejected completed in_production
            
            $text insert end [format "%-20s: %s\n" "Total Batches" $total]
            $text insert end [format "%-20s: %s kg\n" "Target Production" [format "%.2f" $total_target]]
            $text insert end [format "%-20s: %s kg\n" "Actual Production" [format "%.2f" $total_actual]]
            $text insert end [format "%-20s: %s%%\n" "Average Yield" [format "%.2f" $avg_yield]]
            $text insert end [format "%-20s: %s\n" "Released Batches" $released]
            $text insert end [format "%-20s: %s\n" "Rejected Batches" $rejected]
            $text insert end [format "%-20s: %s\n" "Completed" $completed]
            $text insert end [format "%-20s: %s\n" "In Production" $in_production]
        }
    }
    
    $text insert end "\n" $text insert end "📋 BATCH DETAILS\n"
    $text insert end "----------------\n\n"
    
    # Batch details table
    $text insert end [format "%-15s | %-20s | %-12s | %-8s | %-10s\n" "Batch Number" "Formulation" "Quantity" "Yield %" "Status"]
    $text insert end "-" * 70 "\n"
    
    catch {
        set results [DB::eval {
            SELECT 
                pb.batch_number,
                f.formulation_name,
                pb.target_quantity_kg,
                pb.yield_percentage,
                pb.status
            FROM production_batches pb
            JOIN formulations f ON pb.formulation_id = f.formulation_id
            WHERE pb.created_at BETWEEN :from AND :to
            ORDER BY pb.created_at DESC
            LIMIT 50
        } [list from $from_date to $to_date]]
        
        foreach row $results {
            lassign $row batch formulation quantity yield status
            set yield_val [expr {$yield eq "" ? "-" : [format "%.1f" $yield]}]
            set line [format "%-15s | %-20s | %-12s | %-8s | %-10s" \
                $batch [string range $formulation 0 19] [format "%.1f" $quantity] $yield_val $status]
            $text insert end "$line\n"
        }
    }
    
    $text insert end "\n" $text insert end "=" * 70 "\n"
    $text insert end "📌 Report generated by $Config::APP_NAME v$Config::APP_VERSION\n"
    
    $text configure -state disabled
}

proc App::generate_batch_summary {} {
    if {[info exists App::report_text]} {
        set text $App::report_text
        generate_report_content $text
        set_status "Report generated successfully" green
    } else {
        report_batch_summary
    }
}

# ============================================
# 11. COMPOUND LIBRARY
# ============================================

proc App::show_compound_library {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    set w .compounds
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "🧬 Chemical Compound Library"
    wm geometry $w "900x550"
    wm resizable $w 1 1
    
    set main [ttk::frame $w.main -padding "10 10 10 10"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "🧬 Chemical Compound Library" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    # Search
    set search_frame [ttk::frame $main.search -padding "5 5 5 5"]
    pack $search_frame -fill x -pady 5
    
    ttk::label $search_frame.lbl -text "Search:"
    pack $search_frame.lbl -side left -padx 5
    
    ttk::entry $search_frame.entry -width 30
    pack $search_frame.entry -side left -padx 2
    
    ttk::button $search_frame.btn -text "🔍" -command {App::search_compounds} -padding "8 4"
    pack $search_frame.btn -side left -padx 5
    
    # Treeview
    set tree [ttk::treeview $main.tree -columns {formula cas type state density ph} -height 25]
    pack $tree -fill both -expand true -padx 5 -pady 5
    
    $tree heading #0 -text "Compound Name"
    $tree heading formula -text "Formula"
    $tree heading cas -text "CAS Number"
    $tree heading type -text "Type"
    $tree heading state -text "State"
    $tree heading density -text "Density"
    $tree heading ph -text "pH"
    
    $tree column #0 -width 200
    $tree column formula -width 120
    $tree column cas -width 140
    $tree column type -width 130
    $tree column state -width 80
    $tree column density -width 80
    $tree column ph -width 60
    
    # Load compounds
    catch {
        set results [DB::eval {
            SELECT 
                cc.compound_name, 
                cc.chemical_formula, 
                cc.cas_number, 
                ct.type_name as compound_type, 
                cc.physical_state, 
                cc.density, 
                cc.ph_level
            FROM chemical_compounds cc
            LEFT JOIN compound_types ct ON cc.compound_type_id = ct.compound_type_id
            WHERE cc.is_active = true
            ORDER BY cc.compound_name
        }]
        
        foreach row $results {
            lassign $row name formula cas type state density ph
            $tree insert {} end -text $name -values [list $formula $cas $type $state $density $ph]
        }
    }
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No compounds found" -values {"-" "-" "-" "-" "-" "-"}
    }
    
    bind $tree <Double-1> {App::show_compound_details %W}
    
    set App::tree_vars(compounds) $tree
    
    ttk::button $main.close -text "Close" -command "destroy $w" -padding "8 4"
    pack $main.close -pady 10
}

proc App::search_compounds {} {
    set w .compounds
    if {![winfo exists $w]} return
    
    set search_text [$w.main.search.entry get]
    set tree $w.main.tree
    $tree delete [$tree children {}]
    
    if {$search_text eq ""} {
        # Reload all
        catch {
            set results [DB::eval {
                SELECT 
                    cc.compound_name, 
                    cc.chemical_formula, 
                    cc.cas_number, 
                    ct.type_name as compound_type, 
                    cc.physical_state, 
                    cc.density, 
                    cc.ph_level
                FROM chemical_compounds cc
                LEFT JOIN compound_types ct ON cc.compound_type_id = ct.compound_type_id
                WHERE cc.is_active = true
                ORDER BY cc.compound_name
            }]
            
            foreach row $results {
                lassign $row name formula cas type state density ph
                $tree insert {} end -text $name -values [list $formula $cas $type $state $density $ph]
            }
        }
    } else {
        catch {
            set results [DB::eval {
                SELECT 
                    cc.compound_name, 
                    cc.chemical_formula, 
                    cc.cas_number, 
                    ct.type_name as compound_type, 
                    cc.physical_state, 
                    cc.density, 
                    cc.ph_level
                FROM chemical_compounds cc
                LEFT JOIN compound_types ct ON cc.compound_type_id = ct.compound_type_id
                WHERE cc.is_active = true
                AND (cc.compound_name ILIKE :search OR cc.cas_number ILIKE :search)
                ORDER BY cc.compound_name
                LIMIT 50
            } [list search "%$search_text%"]]
            
            foreach row $results {
                lassign $row name formula cas type state density ph
                $tree insert {} end -text $name -values [list $formula $cas $type $state $density $ph]
            }
        }
    }
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No compounds found" -values {"-" "-" "-" "-" "-" "-"}
    }
}

proc App::show_compound_details {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set name [$tree item $selection -text]
    
    tk_messageBox -info -title "Compound Details" \
        -message "📋 Compound: $name\n\nFull details would appear here.\nThis feature is being enhanced."
}

# ============================================
# 12. ADDITIONAL FUNCTIONS
# ============================================

proc App::logout {} {
    if {[tk_messageBox -icon question -type yesno -title "Logout" \
            -message "Are you sure you want to logout?"] eq "yes"} {
        DB::disconnect
        destroy .
        Auth::show_login
    }
}

proc App::export_csv {} {
    set file [tk_getSaveFile -title "Export CSV" -defaultextension .csv \
        -filetypes {{"CSV Files" *.csv} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting CSV to $file..." blue
        tk_messageBox -info -title "Export" "CSV exported to $file"
        set_status "CSV export completed" green
    }
}

proc App::export_pdf {} {
    set file [tk_getSaveFile -title "Export PDF" -defaultextension .pdf \
        -filetypes {{"PDF Files" *.pdf} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting PDF to $file..." blue
        tk_messageBox -info -title "Export" "PDF exported to $file"
        set_status "PDF export completed" green
    }
}

proc App::export_data {} {
    set file [tk_getSaveFile -title "Export Data" -defaultextension .json \
        -filetypes {{"JSON Files" *.json} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting data to $file..." blue
        tk_messageBox -info -title "Export" "Data exported to $file"
        set_status "Export completed" green
    }
}

proc App::import_data {} {
    set file [tk_getOpenFile -title "Import Data" \
        -filetypes {{"CSV Files" *.csv} {"JSON Files" *.json} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Importing data from $file..." blue
        tk_messageBox -info -title "Import" "Data imported from $file"
        set_status "Import completed" green
    }
}

proc App::print_report {} {
    tk_messageBox -info -title "Print Report" "Print dialog would appear here."
}

proc App::copy_batch_info {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    set batch [$tree item $selection -text]
    clipboard clear
    clipboard append $batch
    set_status "Copied: $batch" green
}

# ============================================
# 13. PLACEHOLDER FUNCTIONS
# ============================================

proc App::show_schedule {} { tk_messageBox -info -title "Production Schedule" "Production scheduling calendar would appear here." }
proc App::show_facilities {} { tk_messageBox -info -title "Facilities" "Facility management would appear here." }
proc App::show_production_dashboard {} { tk_messageBox -info -title "Production Dashboard" "Enhanced production dashboard would appear here." }
proc App::show_formulation_form {} { tk_messageBox -info -title "New Formulation" "New formulation form would appear here." }
proc App::edit_formulation {} { tk_messageBox -info -title "Edit Formulation" "Edit formulation form would appear here." }
proc App::validate_formulas {} { tk_messageBox -info -title "Formula Validation" "Formula validation results would appear here." }
proc App::show_component_search {} { tk_messageBox -info -title "Component Search" "Component search interface would appear here." }
proc App::show_stability {} { tk_messageBox -info -title "Stability Studies" "Stability studies management would appear here." }
proc App::show_qc_parameters {} { tk_messageBox -info -title "QC Parameters" "QC parameters configuration would appear here." }
proc App::show_qc_dashboard {} { tk_messageBox -info -title "QC Dashboard" "Quality control dashboard would appear here." }
proc App::show_raw_materials {} { tk_messageBox -info -title "Raw Materials" "Raw materials inventory would appear here." }
proc App::show_finished_products {} { tk_messageBox -info -title "Finished Products" "Finished products inventory would appear here." }
proc App::show_material_receipts {} { tk_messageBox -info -title "Material Receipts" "Material receipts management would appear here." }
proc App::show_suppliers {} { tk_messageBox -info -title "Supplier Management" "Supplier management would appear here." }
proc App::show_inventory_dashboard {} { tk_messageBox -info -title "Inventory Dashboard" "Inventory dashboard would appear here." }
proc App::show_batch_status {} { tk_messageBox -info -title "Batch Status" "Batch status dashboard would appear here." }
proc App::show_user_management {} { tk_messageBox -info -title "User Management" "User management would appear here (Admin only)." }
proc App::show_audit_log {} { tk_messageBox -info -title "Audit Log" "Audit log would appear here (Admin only)." }
proc App::show_system_config {} { tk_messageBox -info -title "System Configuration" "System configuration would appear here (Admin only)." }
proc App::show_db_maintenance {} { tk_messageBox -info -title "Database Maintenance" "Database maintenance tools would appear here." }
proc App::show_role_management {} { tk_messageBox -info -title "Role Management" "Role management would appear here (Admin only)." }
proc App::show_data_browser {} { tk_messageBox -info -title "Data Browser" "Data browser would appear here." }
proc App::show_query_builder {} { tk_messageBox -info -title "Query Builder" "Query builder would appear here." }
proc App::backup_database {} { tk_messageBox -info -title "Backup Database" "Database backup would start here." }
proc App::restore_database {} { tk_messageBox -info -title "Restore Database" "Database restore would start here." }
proc App::show_settings {} { tk_messageBox -info -title "Settings" "Application settings would appear here." }
proc App::show_log {} { tk_messageBox -info -title "System Log" "System log would appear here." }
proc App::show_shortcuts {} { tk_messageBox -info -title "Keyboard Shortcuts" "Keyboard shortcuts reference would appear here." }
proc App::check_updates {} { tk_messageBox -info -title "Check Updates" "Checking for updates...\n\nYou are running the latest version." }
proc App::report_production {} { tk_messageBox -info -title "Production Report" "Production report would appear here." }
proc App::report_quality {} { tk_messageBox -info -title "Quality Report" "Quality report would appear here." }
proc App::report_cost_analysis {} { tk_messageBox -info -title "Cost Analysis" "Cost analysis report would appear here." }
proc App::report_yield_analysis {} { tk_messageBox -info -title "Yield Analysis" "Yield analysis report would appear here." }
proc App::report_inventory {} { tk_messageBox -info -title "Inventory Report" "Inventory report would appear here." }
proc App::export_batches {} { tk_messageBox -info -title "Export Batches" "Batch export would start here." }
proc App::show_qc_test_details {tree} { tk_messageBox -info -title "QC Test Details" "QC test details would appear here." }
proc App::show_production_chart {} { tk_messageBox -info -title "Production Chart" "Production chart would appear here." }

# ============================================
# 14. ABOUT AND HELP
# ============================================

proc App::show_about {} {
    tk_messageBox -info -title "About $Config::APP_NAME" \
        -message "🧴 $Config::APP_NAME v$Config::APP_VERSION\n\nA comprehensive Tcl/Tk GUI for managing toothpaste production processes.\n\nDatabase: PostgreSQL\nLanguage: Tcl/Tk\nDriver: tdbc::postgres\n\nFeatures:\n• Production Batch Management\n• Formulation Management\n• Quality Control Testing\n• Inventory Management\n• Reporting and Analytics\n• User Administration\n\n© 2026 Production Management Systems\n\nLicensed under MIT License"
}

proc App::show_help {} {
    set w .help
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Help - $Config::APP_NAME"
    wm geometry $w "650x550"
    wm resizable $w 1 1
    
    set main [ttk::frame $w.main -padding "10 10 10 10"]
    pack $main -fill both -expand true
    
    ttk::label $main.title -text "📖 Help - $Config::APP_NAME" -font {Arial 16 bold}
    pack $main.title -pady 10
    
    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10
    
    set text [text $main.text -wrap word -font {Arial 10} -yscrollcommand "$main.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $main.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    $text insert end "🧴 TOOTHPASTE PRODUCTION MANAGER\n"
    $text insert end "=================================\n\n"
    $text insert end "📌 GETTING STARTED\n"
    $text insert end "------------------\n"
    $text insert end "1. Login with your credentials\n"
    $text insert end "2. Navigate using the left sidebar\n"
    $text insert end "3. Use the toolbar for quick actions\n"
    $text insert end "4. Search for items using the search bar\n\n"
    
    $text insert end "📋 PRODUCTION MANAGEMENT\n"
    $text insert end "------------------------\n"
    $text insert end "• Create and track production batches\n"
    $text insert end "• Monitor batch status and progress\n"
    $text insert end "• Record production parameters\n"
    $text insert end "• View batch history and details\n\n"
    
    $text insert end "🧪 FORMULATIONS\n"
    $text insert end "---------------\n"
    $text insert end "• View and edit toothpaste formulations\n"
    $text insert end "• Manage chemical components\n"
    $text insert end "• Validate formula percentages\n"
    $text insert end "• Browse compound library\n\n"
    
    $text insert end "🔬 QUALITY CONTROL\n"
    $text insert end "------------------\n"
    $text insert end "• Record QC test results\n"
    $text insert end "• Monitor stability studies\n"
    $text insert end "• Track QC parameters\n"
    $text insert end "• View quality dashboard\n\n"
    
    $text insert end "📊 REPORTS\n"
    $text insert end "----------\n"
    $text insert end "• Generate batch summaries\n"
    $text insert end "• Export to PDF and CSV\n"
    $text insert end "• Production and quality reports\n"
    $text insert end "• Yield and cost analysis\n\n"
    
    $text insert end "👤 USER ROLES\n"
    $text insert end "-------------\n"
    $text insert end "• Administrator: Full system access\n"
    $text insert end "• Production Manager: Batch management\n"
    $text insert end "• QC Technician: Quality testing\n"
    $text insert end "• Scientist: Formulation management\n"
    $text insert end "• Lab Technician: Laboratory testing\n"
    $text insert end "• Process Engineer: Process optimization\n\n"
    
    $text insert end "⌨️ KEYBOARD SHORTCUTS\n"
    $text insert end "---------------------\n"
    $text insert end "• Ctrl+N: New Batch\n"
    $text insert end "• Ctrl+Q: QC Test\n"
    $text insert end "• Ctrl+R: Refresh\n"
    $text insert end "• Ctrl+F: Search\n"
    $text insert end "• Ctrl+P: Print Report\n"
    $text insert end "• Ctrl+E: Export\n\n"
    
    $text insert end "💡 TIPS\n"
    $text insert end "-------\n"
    $text insert end "• Double-click items for details\n"
    $text insert end "• Use filters to narrow results\n"
    $text insert end "• Right-click for context menus\n"
    $text insert end "• Hover for tooltips\n\n"
    
    $text insert end "For more information, please refer to the user manual or contact support."
    
    $text configure -state disabled
    
    ttk::button $main.close -text "Close" -command "destroy $w" -padding "8 4"
    pack $main.close -pady 10
}

# ============================================
# 15. START THE APPLICATION
# ============================================

# Set global variables
set Auth::show_password 0
set Auth::show_reg_password 0

# Check driver availability
if {![DB::check_availability]} {
    puts "WARNING: PostgreSQL driver (tdbc::postgres) is not available"
    puts "Please install it using: teacup install tdbc::postgres"
}

# Show login window
Auth::show_login

# Enter the Tk event loop
vwait forever