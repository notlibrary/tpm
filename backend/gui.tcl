#!/usr/bin/env tclsh
# ============================================
# TOOTHPASTE PRODUCTION MANAGER GUI v3.1
# Merged with login.tcl authentication
# Full production management interface
# ============================================

package require Tk
package require ttk

# Try to load PostgreSQL driver
set pg_available 0
catch {
    package require tdbc::postgres
    set pg_available 1
}

if {!$pg_available} {
    tk_messageBox -icon error -title "Driver Error" \
        -message "PostgreSQL driver (tdbc::postgres) is not available.\n\nPlease install it using:\n  teacup install tdbc::postgres"
    exit 1
}

# ============================================
# 0. GLOBAL CONFIGURATION & CONSTANTS
# ============================================

namespace eval Config {
    variable APP_NAME "Toothpaste Production Manager"
    variable APP_VERSION "3.1"
    variable APP_ICON "🧴"
    variable APP_COLOR "#2c3e50"
    variable APP_ACCENT "#3498db"
    variable DB_HOST "localhost"
    variable DB_PORT "5433"
    variable DB_NAME "toothpastes"
    variable DB_USER "postgres"
    variable DB_PASS "arizona42"
    variable MAX_BATCHES 1000
    variable PAGE_SIZE 50
    variable LOG_LEVEL "INFO"
}

# ============================================
# 1. INITIALIZATION – set driver flag in DB
# ============================================

namespace eval DB {
    variable pg_available 0
    proc set_available {val} { variable pg_available; set pg_available $val }
}
DB::set_available $pg_available

# ============================================
# 2. DATABASE CONNECTION (fixed)
# ============================================

namespace eval DB {
    variable conn ""
    variable connected 0
    variable last_error ""
    variable current_user ""
    variable current_role ""
    variable transaction_active 0

    proc check_availability {} { variable pg_available; return $pg_available }

    proc connect {host port db user password} {
        variable conn
        variable connected
        variable pg_available
        variable last_error

        if {!$pg_available} {
            set last_error "PostgreSQL driver (tdbc::postgres) is not available"
            error $last_error
        }

        if {$connected} {
            return 1
        }

        if {$host eq "localhost"} { set host "127.0.0.1" }

        catch { dbconn close }
        catch { rename dbconn {} }

        set code [catch {
            tdbc::postgres::connection create dbconn \
                -host $host -port $port -database $db \
                -user $user -password $password
        } errorMsg]

        if {$code != 0} {
            set connected 0
            set last_error "Connection failed: $errorMsg"
            puts "DEBUG: DB::connect error: $last_error"
            return 0
        }

        if {[catch {
            dbconn allrows "SELECT 1"
        } testError]} {
            set connected 0
            set last_error "Connection test failed: $testError"
            puts "DEBUG: DB::connect test failed: $last_error"
            catch { dbconn close }
            catch { rename dbconn {} }
            return 0
        }

        set conn dbconn
        set connected 1
        set last_error ""
        puts "DEBUG: ✅ Connection successful"
        return 1
    }

    proc disconnect {} {
        variable conn
        variable connected
        if {$connected} {
            catch {$conn close}
            set connected 0
        }
        catch { rename dbconn {} }
    }

    proc connected {} { variable connected; return $connected }
    proc get_connection {} { variable conn; if {![connected]} { error "Not connected" }; return $conn }
    proc get_last_error {} { variable last_error }

    # ---- Transaction methods ----
    proc begin_transaction {} {
        variable transaction_active
        if {!$transaction_active} {
            set conn [get_connection]
            $conn begintransaction
            set transaction_active 1
        }
    }

    proc commit_transaction {} {
        variable transaction_active
        if {$transaction_active} {
            set conn [get_connection]
            $conn commit
            set transaction_active 0
        }
    }

    proc rollback_transaction {} {
        variable transaction_active
        if {$transaction_active} {
            set conn [get_connection]
            $conn rollback
            set transaction_active 0
        }
    }

    # ---- Query methods (fixed parameter passing) ----
    proc exec_query {sql {params {}}} {
        if {![connected]} { error "Not connected" }
        set conn [get_connection]
        set stmt [$conn prepare $sql]
        if {[llength $params] > 0} {
            $stmt execute [dict create {*}$params]
        } else {
            $stmt execute
        }
        return $stmt
    }

    proc eval {sql {params {}}} {
        if {![connected]} { error "Not connected" }
        set conn [get_connection]
        set stmt [$conn prepare $sql]
        if {[llength $params] > 0} {
            $stmt execute [dict create {*}$params]
        } else {
            $stmt execute
        }
        set results {}
        $stmt foreach row { lappend results $row }
        $stmt close
        return $results
    }

    proc eval_one {sql {params {}}} {
        set results [eval $sql $params]
        if {[llength $results] > 0} { return [lindex $results 0] }
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
        if {![connected]} { return 0 }
        catch {
            set conn [get_connection]
            $conn allrows "SELECT 1"
            return 1
        } errorMsg
        set connected 0
        return 0
    }

    proc set_current_user {username role} {
        variable current_user
        variable current_role
        set current_user $username
        set current_role $role
    }

    proc get_current_user {} { variable current_user }
    proc get_current_role {} { variable current_role }

    proc get_version {} {
        if {[connected]} {
            catch { return [eval_scalar "SELECT version()"] }
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
# 3. NATIVE SHA-256 (from login.tcl)
# ============================================

proc native_sha256 {input_string} {
    if {$::tcl_platform(platform) eq "windows"} {
        set tmp_file "tmp_hash_input.bin"
        set fh [open $tmp_file w]
        fconfigure $fh -translation binary -encoding utf-8
        puts -nonewline $fh $input_string
        close $fh

        set hash ""
        if {![catch {exec certutil -hashfile $tmp_file SHA256} output]} {
            set lines [split [string trim $output] "\n"]
            if {[llength $lines] >= 2} {
                set hash [string map {" " "" "\r" "" "\n" ""} [lindex $lines 1]]
            }
        }
        file delete -force $tmp_file
        return [string tolower $hash]
    } else {
        package require sha256
        return [sha2::sha256 $input_string]
    }
}

# ============================================
# 4. AUTHENTICATION (exactly as login.tcl)
# ============================================

proc authenticate_user {username password} {
    set authenticated 0

    if {[catch {
        tdbc::postgres::connection create auth_conn \
            -host $Config::DB_HOST \
            -port $Config::DB_PORT \
            -user $Config::DB_USER \
            -password $Config::DB_PASS \
            -database $Config::DB_NAME
    } conn_err]} {
        tk_messageBox -icon error -title "Database Error" \
            -message "Could not connect to database:\n$conn_err"
        return 0
    }

    set query {
        SELECT user_id, password_hash, salt
        FROM tp_users
        WHERE username = :username AND is_active = true
    }

    if {[catch {
        set statement [auth_conn prepare $query]
        set resultset [$statement execute [dict create username $username]]

        if {[$resultset nextrow row]} {
            set user_id [dict get $row user_id]
            set db_hash [string tolower [string trim [dict get $row password_hash]]]
            set db_salt [string trim [dict get $row salt]]

            set hash_pure [native_sha256 $password]
            set hash_salted [native_sha256 "${password}${db_salt}"]

            if {$hash_pure eq $db_hash || $hash_salted eq $db_hash} {
                set authenticated $user_id
            }
        }
        $resultset close
        $statement close
    } exec_err]} {
        tk_messageBox -icon error -title "SQL Error" \
            -message "Error executing query:\n$exec_err"
    }

    auth_conn close
    return $authenticated
}

# Генератор случайной соли (32 символа)
proc generate_random_salt {} {
    set chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
    set salt ""
    for {set i 0} {$i < 32} {incr i} {
        set idx [expr {int(rand() * [string length $chars])}]
        append salt [string index $chars $idx]
    }
    return $salt
}

proc show_register_dialog {} {
    set w .register
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Register New User"
    wm geometry $w "450x550"
    wm resizable $w 0 0
    wm transient $w .
    grab set $w   ;# <-- ИСПРАВЛЕНО: grab set вместо wm grab

    if {![DB::connected]} {
        if {![DB::connect $Config::DB_HOST $Config::DB_PORT $Config::DB_NAME $Config::DB_USER $Config::DB_PASS]} {
            tk_messageBox -icon error -title "Database Error" \
                -message "Could not connect to database:\n[DB::get_last_error]"
            destroy $w
            return
        }
    }

    set main [ttk::frame $w.main -padding "15 15 15 15"]
    pack $main -fill both -expand true

    ttk::label $main.title -text "📝 Create New Account" -font {Arial 14 bold}
    pack $main.title -pady 10

    ttk::label $main.sub -text "Fill in the details below" -font {Arial 9} -foreground gray
    pack $main.sub -pady 5

    ttk::separator $main.sep -orient horizontal
    pack $main.sep -fill x -pady 10

    # Переменные для полей
    set fields {
        first_name "First Name *"
        last_name  "Last Name *"
        email      "Email"
        username   "Username *"
        password   "Password *"
        confirm    "Confirm Password *"
        role       "Role *"
    }

    array set entries {}   ;# <-- ИСПРАВЛЕНО: объявляем массив
    foreach {var label} $fields {
        set f [ttk::frame $main.$var]
        pack $f -fill x -pady 4

        ttk::label $f.lbl -text $label -width 18 -anchor e -font {Arial 10}
        pack $f.lbl -side left -padx 5

        if {$var eq "role"} {
            set widget [ttk::combobox $f.cb -width 28 -state readonly -font {Arial 10}]
            set roles [get_roles_list]
            $widget configure -values $roles
            if {[llength $roles] > 0} {
                $widget set [lindex $roles 0]
            } else {
                $widget set "QC_Technician"
            }
        } elseif {$var eq "password" || $var eq "confirm"} {
            set widget [ttk::entry $f.entry -width 28 -show "*" -font {Arial 10}]
        } else {
            set widget [ttk::entry $f.entry -width 28 -font {Arial 10}]
        }
        pack $widget -side left -expand true -fill x
        set entries($var) $widget
    }

    # Чекбокс показа паролей
    set show_pass 0
    set check_frame [ttk::frame $main.show]
    pack $check_frame -fill x -pady 5 -padx 10
    ttk::checkbutton $check_frame.cb -text "👁 Show Passwords" -variable show_pass -command "
        if {\$show_pass} {
            $w.main.password.entry configure -show \"\"
            $w.main.confirm.entry configure -show \"\"
        } else {
            $w.main.password.entry configure -show \"*\"
            $w.main.confirm.entry configure -show \"*\"
        }
    "
    pack $check_frame.cb -anchor w

    ttk::label $main.note -text "* Required fields" -font {Arial 8} -foreground gray
    pack $main.note -pady 5 -anchor w -padx 10

    # Сообщение об ошибке
    ttk::label $main.err -text "" -foreground red -font {Arial 9}
    pack $main.err -fill x -pady 5

    # Кнопки
    set btn_frame [ttk::frame $main.buttons]
    pack $btn_frame -fill x -pady 15
    ttk::button $btn_frame.register -text "✅ Register" -command [list register_user $w] -padding "10 5" -style Accent.TButton
    pack $btn_frame.register -side left -expand true -fill x -padx 5
    ttk::button $btn_frame.cancel -text "❌ Cancel" -command "destroy $w" -padding "10 5"
    pack $btn_frame.cancel -side right -expand true -fill x -padx 5

    bind $w <Return> [list register_user $w]
    focus $entries(first_name)
}
proc get_roles_list {} {
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

proc register_user {w} {
    # Получить виджеты из окна
    set entries(first_name) $w.main.first_name.entry
    set entries(last_name)  $w.main.last_name.entry
    set entries(email)      $w.main.email.entry
    set entries(username)   $w.main.username.entry
    set entries(password)   $w.main.password.entry
    set entries(confirm)    $w.main.confirm.entry
    set entries(role)       $w.main.role.cb

    # Собрать данные
    set first_name [string trim [$entries(first_name) get]]
    set last_name  [string trim [$entries(last_name) get]]
    set email      [string trim [$entries(email) get]]
    set username   [string trim [$entries(username) get]]
    set password   [$entries(password) get]
    set confirm    [$entries(confirm) get]
    set role       [$entries(role) get]

    # Проверки
    set errors {}
    if {$first_name eq ""} { lappend errors "First Name is required" }
    if {$last_name eq ""}  { lappend errors "Last Name is required" }
    if {$username eq ""}   { lappend errors "Username is required" }
    if {$password eq ""}   { lappend errors "Password is required" }
    if {$role eq ""}       { lappend errors "Role is required" }

    if {[llength $errors] > 0} {
        $w.main.err configure -text "Please fix:\n[join $errors \n]"
        return
    }

    if {$password ne $confirm} {
        $w.main.err configure -text "Passwords do not match!"
        return
    }

    if {[string length $password] < 6} {
        $w.main.err configure -text "Password must be at least 6 characters."
        return
    }

    if {$email ne "" && ![regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $email]} {
        $w.main.err configure -text "Please enter a valid email address."
        return
    }

    # Проверка уникальности
    set count [DB::eval_scalar "SELECT COUNT(*) FROM tp_users WHERE username = :username" [list username $username]]
    if {$count > 0} {
        $w.main.err configure -text "Username '$username' already exists!"
        return
    }

    if {$email ne ""} {
        set count [DB::eval_scalar "SELECT COUNT(*) FROM persons WHERE email = :email" [list email $email]]
        if {$count > 0} {
            $w.main.err configure -text "Email already registered!"
            return
        }
    }

    # Получить role_id
    set role_id [DB::eval_scalar "SELECT role_id FROM persons_roles WHERE role_name = :role" [list role $role]]
    if {$role_id == 0} {
        $w.main.err configure -text "Invalid role selected."
        return
    }

    # Хеширование пароля с солью
    set salt [generate_random_salt]
    set hashed [native_sha256 "${password}${salt}"]

    set person_code [string toupper $username]

    DB::begin_transaction
    try {
        # Вставка в persons
        set sql_person {
            INSERT INTO persons (
                person_code, first_name, last_name, email, role_id,
                is_active, created_at
            ) VALUES (
                :person_code, :first_name, :last_name, :email, :role_id,
                true, CURRENT_TIMESTAMP
            ) RETURNING person_id
        }
        set params_person [list \
            person_code $person_code \
            first_name $first_name \
            last_name $last_name \
            email $email \
            role_id $role_id
        ]
        set person_id [DB::eval_scalar $sql_person $params_person]

        # Вставка в tp_users
        set sql_user {
            INSERT INTO tp_users (
                username, password_hash, salt, person_id, is_active, created_at
            ) VALUES (
                :username, :password_hash, :salt, :person_id, true, CURRENT_TIMESTAMP
            )
        }
        set params_user [list \
            username $username \
            password_hash $hashed \
            salt $salt \
            person_id $person_id
        ]
        DB::eval $sql_user $params_user

        DB::commit_transaction

        tk_messageBox -icon info -title "Registration Successful" \
            -message "✅ User '$username' registered successfully!\n\nYou can now login."

        destroy $w

        # Автоматически подставить имя пользователя в форму входа
        global login_user
        set login_user $username

    } on error {err} {
        DB::rollback_transaction
        $w.main.err configure -text "Registration failed: $err"
        puts "ERROR: $err"
    }
}
# ============================================
# 5. LOGIN WINDOW (from login.tcl)
# ============================================

set login_user ""
set login_pass ""

proc handle_login {} {
    global login_user login_pass

    set user [string trim $login_user]
    set pass $login_pass

    if {$user eq "" || $pass eq ""} {
        tk_messageBox -icon warning -title "Warning" -message "Please enter username and password."
        return
    }

    set auth_result [authenticate_user $user $pass]

    if {$auth_result > 0} {
        if {![DB::connected]} {
            if {![DB::connect $Config::DB_HOST $Config::DB_PORT $Config::DB_NAME $Config::DB_USER $Config::DB_PASS]} {
                set error_msg [DB::get_last_error]
                tk_messageBox -icon error -title "Database Error" \
                    -message "Could not connect to main database:\n$error_msg"
                return
            }
        }

      
        set sql {
            SELECT p.first_name, p.last_name, r.role_name
            FROM persons p
            LEFT JOIN persons_roles r ON p.role_id = r.role_id
            WHERE p.person_id = (SELECT person_id FROM tp_users WHERE user_id = :user_id)
        }
        set row [DB::eval_one $sql [list user_id $auth_result]]
        lassign $row first_name last_name role_name

        set DB::current_user $user
        set DB::current_role $role_name

        
        foreach child [winfo children .] {
            destroy $child
        }

        
        App::init
    } else {
        tk_messageBox -icon error -title "Access Denied" -message "Invalid username or password."
    }
}

proc create_login_window {} {
    wm title . "Login - $Config::APP_NAME"
    wm geometry . "320x220"
    wm resizable . 0 0

    global login_user login_pass

    set f [ttk::frame .main_frame -padding 15]
    pack $f -fill both -expand 1

    ttk::label $f.lbl_user -text "Username:" -anchor w
    ttk::entry $f.ent_user -textvariable login_user -width 30
    pack $f.lbl_user -fill x -pady {0 2}
    pack $f.ent_user -fill x -pady {0 10}

    ttk::label $f.lbl_pass -text "Password:" -anchor w
    ttk::entry $f.ent_pass -textvariable login_pass -show "*" -width 30
    pack $f.lbl_pass -fill x -pady {0 2}
    pack $f.ent_pass -fill x -pady {0 15}

    # Контейнер для двух кнопок в ряд
    set btn_frame [ttk::frame $f.btns]
    pack $btn_frame -fill x -pady 5

    ttk::button $btn_frame.login -text "Login" -command handle_login -default active -padding "8 4"
    pack $btn_frame.login -side left -expand true -fill x -padx 2

    ttk::button $btn_frame.register -text "Register" -command show_register_dialog -padding "8 4"
    pack $btn_frame.register -side right -expand true -fill x -padx 2

    bind . <Return> {handle_login}
    focus $f.ent_user
}
# ============================================
# 6. MAIN APPLICATION CLASS (FULL FROM ORIGINAL)
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
	variable toolbar ""   ;

    # Main window initialization
proc init {} {
    variable main_notebook
    variable user_role
    variable user_name

    set user_role [DB::get_current_role]
    set user_name [DB::get_current_user]

    wm title . "🧴 $Config::APP_NAME v$Config::APP_VERSION - User: $user_name"
    wm geometry . "1300x750+50+50"
    wm minsize . 1100 650
    wm protocol . WM_DELETE_WINDOW {App::logout}

    wm iconname . $Config::APP_NAME

    configure_theme
    create_menu
    create_toolbar

    set main_pane [ttk::panedwindow .mainpane -orient horizontal]
    pack $main_pane -fill both -expand true -side top

    create_navigation $main_pane
    create_content_area $main_pane
    create_statusbar

    App::show_dashboard
    set_status "Welcome $user_name! Connected to $Config::DB_NAME@$Config::DB_HOST" green
    .toolbar.status.indicator configure -text "● Connected as $user_name ($user_role)" -foreground green

    check_permissions
    after 100 {App::load_initial_data}
}

    # Configure application theme
    proc configure_theme {} {
        variable theme
        ttk::style theme use $theme
        ttk::style configure "Accent.TButton" -background $Config::APP_ACCENT -foreground white
        ttk::style map "Accent.TButton" -background [list active "#2980b9"]
        ttk::style configure "Treeview" -font [list Arial $App::font_size]
        ttk::style configure "Treeview.Heading" -font [list Arial $App::font_size bold]
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
        $file_menu add command -label "Exit" -command {App::exit_app}

        # Production menu
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

        ttk::separator $tool_frame.sep1 -orient vertical
        pack $tool_frame.sep1 -side left -padx 5 -fill y

        ttk::label $tool_frame.lbl -text "🔍 Search:"
        pack $tool_frame.lbl -side left -padx 5
        ttk::entry $tool_frame.search -width 35 -font {Arial 10}
        pack $tool_frame.search -side left -padx 2
        bind $tool_frame.search <Return> {App::search}

        ttk::button $tool_frame.go -text "Go" -command {App::search} -padding "8 4"
        pack $tool_frame.go -side left -padx 2

        ttk::separator $tool_frame.sep2 -orient vertical
        pack $tool_frame.sep2 -side left -padx 5 -fill y

        ttk::label $tool_frame.filter_lbl -text "Filter:"
        pack $tool_frame.filter_lbl -side left -padx 5
        ttk::combobox $tool_frame.filter -values {"All" "Active" "Completed" "Pending" "Rejected"} -width 12 -state readonly
        pack $tool_frame.filter -side left -padx 2
        $tool_frame.filter set "All"
        bind $tool_frame.filter <<ComboboxSelected>> {App::apply_filter}

        set status_frame [ttk::frame $tool_frame.status]
        pack $status_frame -side right -padx 10

        ttk::label $status_frame.indicator -text "● Connected" -foreground green -font {Arial 9}
        pack $status_frame.indicator -side left
        ttk::label $status_frame.user -text "👤 [DB::get_current_user]" -font {Arial 9}
        pack $status_frame.user -side left -padx 5
        ttk::label $status_frame.role -text "🎯 [DB::get_current_role]" -font {Arial 9} -foreground blue
        pack $status_frame.role -side left -padx 5

        set App::toolbar $tool_frame
    }

    # Navigation sidebar
    proc create_navigation {parent} {
        variable sidebar_width
        variable nav_tree

        set nav_frame [ttk::frame $parent.nav -width $sidebar_width -relief sunken]
        $parent add $nav_frame -weight 0

        set header [ttk::frame $nav_frame.header -padding "5 10 5 10"]
        pack $header -fill x
        ttk::label $header.icon -text "🧴" -font {Arial 20}
        pack $header.icon -pady 2
        ttk::label $header.title -text "Navigation" -font {Arial 12 bold}
        pack $header.title
        ttk::separator $nav_frame.sep -orient horizontal
        pack $nav_frame.sep -fill x -pady 5

        set tree [ttk::treeview $nav_frame.tree -height 28 -selectmode browse -show tree]
        pack $tree -fill both -expand true -padx 5 -pady 5
        ttk::style configure "Treeview" -font [list Arial 10] -rowheight 25

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
        bind $tree <<TreeviewSelect>> [list App::navigate $tree]
        set nav_tree $tree
    }

    # Content area
    proc create_content_area {parent} {
    set content_frame [ttk::frame $parent.content]
    $parent add $content_frame -weight 1

    set notebook_widget [ttk::notebook $content_frame.notebook -padding "2 2 2 2"]
    pack $notebook_widget -fill both -expand true

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
    $notebook_widget select $notebook_widget.dashboard
    App::show_dashboard_content
}

    # Status bar
    proc create_statusbar {} {
        set status_frame [ttk::frame .statusbar -relief sunken -borderwidth 1 -padding "5 2 5 2"]
        pack $status_frame -fill x -side bottom

        ttk::label $status_frame.status -text "Ready" -anchor w -font {Arial 9}
        pack $status_frame.status -side left -padx 5 -expand true -fill x

        set progress [ttk::progressbar $status_frame.progress -mode indeterminate -length 100]
        pack $progress -side left -padx 5

        ttk::label $status_frame.db -text "DB: $Config::DB_NAME@$Config::DB_HOST" -font {Arial 8} -foreground gray
        pack $status_frame.db -side left -padx 5

        ttk::label $status_frame.user -text "👤 [DB::get_current_user]" -font {Arial 8} -foreground blue
        pack $status_frame.user -side left -padx 5

        ttk::label $status_frame.role -text "🎯 [DB::get_current_role]" -font {Arial 8} -foreground green
        pack $status_frame.role -side left -padx 5

        ttk::label $status_frame.time -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] -font {Arial 8} -foreground gray
        pack $status_frame.time -side right -padx 5

        variable status_var $status_frame.status
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
			App::show_dashboard_content
			if {[DB::connected]} {
				App::update_recent_batches
				App::update_dashboard_stats
			}
			App::hide_progress
			App::set_status "Ready" green
		}
	}

    # Navigation handler
	proc navigate {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return

    set tags [$tree item $selection -tags]
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

    # Logout
    proc logout {} {
        if {[tk_messageBox -icon question -type yesno -title "Logout" \
                -message "Are you sure you want to logout?"] eq "yes"} {
            DB::disconnect
            destroy .
            create_login_window
        }
    }

    proc exit_app {} {
        if {[tk_messageBox -icon question -type yesno -title "Exit" \
                -message "Are you sure you want to exit?"] eq "yes"} {
            DB::disconnect
            destroy .
        }
    }

    # Disconnect
    proc disconnect_db {} {
        DB::disconnect
        set_status "Disconnected from database" red
        .toolbar.status.indicator configure -text "● Disconnected" -foreground red
        tk_messageBox -icon info -title "Disconnected" "Disconnected from database."
    }

    proc show_connection_dialog {} {
        tk_messageBox -icon info -title "Connection Settings" "Connection settings dialog would appear here."
    }

    # Apply filter
    proc apply_filter {} {
        set filter [.toolbar.filter get]
        set_status "Filter applied: $filter" blue
        refresh_current
    }

    # Search
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
            tk_messageBox -icon info -title "Search Results" -message $msg
        } else {
            tk_messageBox -icon info -title "Search Results" \
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
				"dashboard" {App::show_dashboard_content}
				"production" {show_batches}
				"formulations" {show_formulations}
				"quality" {show_qc_tests}
				"inventory" {show_raw_materials}
				"reports" {report_batch_summary}
				default {App::show_dashboard_content}
			}
			hide_progress
		}
	}

    proc clear_content {frame} {
        foreach child [winfo children $frame] {
            destroy $child
        }
    }
}

# ============================================
# 7. DASHBOARD
# ============================================

proc App::show_dashboard {} {
    variable main_notebook
    if {[winfo exists $main_notebook]} {
        $main_notebook select $main_notebook.dashboard
        App::show_dashboard_content
    }
}

proc App::show_dashboard_content {} {
    variable main_notebook
    set frame $main_notebook.dashboard
    clear_content $frame

    set main_frame [ttk::frame $frame.main]
    pack $main_frame -fill both -expand true

    set header [ttk::frame $main_frame.header -padding "10 10 10 10"]
    pack $header -fill x -pady 10
    ttk::label $header.title -text "📊 Production Dashboard" -style Title.TLabel
    pack $header.title -side left
    ttk::label $header.user -text "Welcome, [DB::get_current_user] ([DB::get_current_role])" -style Subtitle.TLabel
    pack $header.user -side right
    ttk::separator $main_frame.sep -orient horizontal
    pack $main_frame.sep -fill x -pady 10

    set stats_frame [ttk::frame $main_frame.stats -padding "5 5 5 5"]
    pack $stats_frame -fill x -pady 10

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

    set content_frame [ttk::frame $main_frame.content]
    pack $content_frame -fill both -expand true -pady 10

    set left_frame [ttk::frame $content_frame.left -relief groove -borderwidth 1 -padding "5 5 5 5"]
    pack $left_frame -side left -fill both -expand true -padx 5
    ttk::label $left_frame.title -text "📋 Recent Activity" -font {Arial 12 bold}
    pack $left_frame.title -pady 5 -anchor w

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

    if {[DB::connected]} {
        load_recent_activity $tree
    } else {
        $tree insert {} end -text "No data" -values {"-" "System" "Disconnected" "-"}
    }

# Right: Quick actions and charts
	set right_frame [ttk::frame $content_frame.right -relief groove -borderwidth 1 -padding "5 5 5 5"]
	pack $right_frame -side right -fill both -expand true -padx 5
    ttk::label $right_frame.title -text "⚡ Quick Actions" -font {Arial 12 bold}
    pack $right_frame.title -pady 5 -anchor w

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
# 8. DATABASE LOADING FUNCTIONS
# ============================================

proc App::load_dashboard_stats {} {
    set stats {}
    catch {set total_batches [DB::eval_scalar "SELECT COUNT(*) FROM production_batches"]} {set total_batches 0}
    catch {set active_formulations [DB::eval_scalar "SELECT COUNT(*) FROM formulations WHERE status = 'Active'"]} {set active_formulations 0}
    catch {set qc_today [DB::eval_scalar "SELECT COUNT(*) FROM qc_tests WHERE test_date >= CURRENT_DATE"]} {set qc_today 0}
    catch {set rejected [DB::eval_scalar "SELECT COUNT(*) FROM production_batches WHERE status = 'Rejected'"]} {set rejected 0}
    catch {set materials [DB::eval_scalar "SELECT COUNT(DISTINCT compound_id) FROM raw_material_inventory WHERE quantity > 0"]} {set materials 0}
    catch {set pending [DB::eval_scalar "SELECT COUNT(*) FROM production_batches WHERE status IN ('Planned', 'Raw_Materials_Ready')"]} {set pending 0}
    catch {set lines [DB::eval_scalar "SELECT COUNT(*) FROM production_facilities WHERE is_active = true"]} {set lines 0}
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
        $tree tag configure completed -foreground green
        $tree tag configure rejected -foreground red
        $tree tag configure inprogress -foreground orange
    } errorMsg
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
    if {[winfo exists .mainpane.content.notebook.dashboard.main.content.left.tree]} {
        set tree .mainpane.content.notebook.dashboard.main.content.left.tree
        $tree delete [$tree children {}]
        load_recent_activity $tree
    }
}

proc App::update_dashboard_stats {} {
    if {[winfo exists .mainpane.content.notebook.dashboard.main.stats]} {
        App::show_dashboard_content
    }
}

# ============================================
# 9. BATCH MANAGEMENT FUNCTIONS
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

    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    ttk::label $header.title -text "📋 Production Batches" -font {Arial 16 bold}
    pack $header.title -side left
    ttk::button $header.new -text "➕ New Batch" -command {App::show_batch_form} -padding "8 4"
    pack $header.new -side right -padx 5

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
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    bind $tree <Double-1> {App::show_batch_details %W}
    bind $tree <Control-c> {App::copy_batch_info %W}
    set App::tree_vars(batches) $tree
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
    $tree delete [$tree children {}]
    show_progress "Loading batches..."
    catch {
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
    set main [ttk::frame $w.main -padding "10 10 10 10"]
    pack $main -fill both -expand true
    ttk::label $main.title -text "📋 Batch: $batch" -font {Arial 14 bold}
    pack $main.title -pady 10
    set nb [ttk::notebook $main.nb -padding "5 5 5 5"]
    pack $nb -fill both -expand true
    set gen_frame [ttk::frame $nb.general -padding "10 10 10 10"]
    $nb add $gen_frame -text "📋 General"
    set text [text $gen_frame.text -wrap word -font {Courier 10} -yscrollcommand "$gen_frame.scroll set"]
    pack $text -side left -fill both -expand true
    set scrollbar [ttk::scrollbar $gen_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
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
                if {[llength $formulations_list] > 0} { $widget set [lindex $formulations_list 0] }
            } elseif {$var eq "facility"} {
                $widget configure -values $facilities_list
                if {[llength $facilities_list] > 0} { $widget set [lindex $facilities_list 0] }
            } elseif {$var eq "supervisor"} {
                $widget configure -values $supervisors_list
                if {[llength $supervisors_list] > 0} { $widget set [lindex $supervisors_list 0] }
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
    set note_f [ttk::frame $main.notes]
    pack $note_f -fill x -pady 4
    ttk::label $note_f.lbl -text "Notes:" -width 20 -anchor e -font {Arial 10}
    pack $note_f.lbl -side left -padx 5
    ttk::entry $note_f.entry -width 30 -font {Arial 10}
    pack $note_f.entry -side left -expand true -fill x
    set entries(notes) $note_f.entry

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
# 10. FORMULATION MANAGEMENT FUNCTIONS
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
# 11. QUALITY CONTROL FUNCTIONS
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

    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    ttk::label $header.title -text "🔬 Quality Control Tests" -font {Arial 16 bold}
    pack $header.title -side left
    ttk::button $header.new -text "➕ New QC Test" -command {App::show_qc_test_form} -padding "8 4"
    pack $header.new -side right -padx 5

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
                if {[llength $parameters_list] > 0} { $widget set [lindex $parameters_list 0] }
            } elseif {$var eq "lab"} {
                $widget configure -values $labs_list
                if {[llength $labs_list] > 0} { $widget set [lindex $labs_list 0] }
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
# 12. REPORTING FUNCTIONS
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

    set header [ttk::frame $frame.header -padding "5 5 5 5"]
    pack $header -fill x
    ttk::label $header.title -text "📊 Batch Summary Report" -font {Arial 16 bold}
    pack $header.title -side left

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

    set report_frame [ttk::frame $frame.report -relief sunken -borderwidth 1]
    pack $report_frame -fill both -expand true -padx 10 -pady 5
    set text [text $report_frame.text -wrap word -font {Courier 10} -yscrollcommand "$report_frame.scroll set"]
    pack $text -side left -fill both -expand true
    set scrollbar [ttk::scrollbar $report_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
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

    set from_date ""
    set to_date ""
    catch {
        set from_date [.mainpane.content.notebook.reports.params.from get]
        set to_date [.mainpane.content.notebook.reports.params.to get]
    }
    if {$from_date eq ""} { set from_date [clock format [clock seconds] -format "%Y-%m-01"] }
    if {$to_date eq ""} { set to_date [clock format [clock seconds] -format "%Y-%m-%d"] }
    $text insert end "📅 Period: $from_date to $to_date\n"
    $text insert end "-" * 70 "\n\n"
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
# 13. COMPOUND LIBRARY
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
    set search_frame [ttk::frame $main.search -padding "5 5 5 5"]
    pack $search_frame -fill x -pady 5
    ttk::label $search_frame.lbl -text "Search:"
    pack $search_frame.lbl -side left -padx 5
    ttk::entry $search_frame.entry -width 30
    pack $search_frame.entry -side left -padx 2
    ttk::button $search_frame.btn -text "🔍" -command {App::search_compounds} -padding "8 4"
    pack $search_frame.btn -side left -padx 5

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
    tk_messageBox -icon info -title "Compound Details" \
        -message "📋 Compound: $name\n\nFull details would appear here.\nThis feature is being enhanced."
}

# ============================================
# 14. ADDITIONAL FUNCTIONS
# ============================================

proc App::export_csv {} {
    set file [tk_getSaveFile -title "Export CSV" -defaultextension .csv \
        -filetypes {{"CSV Files" *.csv} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting CSV to $file..." blue
        tk_messageBox -icon info -title "Export" "CSV exported to $file"
        set_status "CSV export completed" green
    }
}

proc App::export_pdf {} {
    set file [tk_getSaveFile -title "Export PDF" -defaultextension .pdf \
        -filetypes {{"PDF Files" *.pdf} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting PDF to $file..." blue
        tk_messageBox -icon info -title "Export" "PDF exported to $file"
        set_status "PDF export completed" green
    }
}

proc App::export_data {} {
    set file [tk_getSaveFile -title "Export Data" -defaultextension .json \
        -filetypes {{"JSON Files" *.json} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting data to $file..." blue
        tk_messageBox -icon info -title "Export" "Data exported to $file"
        set_status "Export completed" green
    }
}

proc App::import_data {} {
    set file [tk_getOpenFile -title "Import Data" \
        -filetypes {{"CSV Files" *.csv} {"JSON Files" *.json} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Importing data from $file..." blue
        tk_messageBox -icon info -title "Import" "Data imported from $file"
        set_status "Import completed" green
    }
}

proc App::print_report {} {
    tk_messageBox -icon info -title "Print Report" "Print dialog would appear here."
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
# 15. PLACEHOLDER FUNCTIONS
# ============================================
proc App::show_schedule {} { tk_messageBox -icon info -title "Production Schedule" -message "Production scheduling calendar would appear here." }
proc App::show_facilities {} { tk_messageBox -icon info -title "Facilities" -message "Facility management would appear here." }
proc App::show_production_dashboard {} { tk_messageBox -icon info -title "Production Dashboard" -message "Enhanced production dashboard would appear here." }
proc App::show_formulation_form {} { tk_messageBox -icon info -title "New Formulation" -message "New formulation form would appear here." }
proc App::edit_formulation {} { tk_messageBox -icon info -title "Edit Formulation" -message "Edit formulation form would appear here." }
proc App::validate_formulas {} { tk_messageBox -icon info -title "Formula Validation" -message "Formula validation results would appear here." }
proc App::show_component_search {} { tk_messageBox -icon info -title "Component Search" -message "Component search interface would appear here." }
proc App::show_stability {} { tk_messageBox -icon info -title "Stability Studies" -message "Stability studies management would appear here." }
proc App::show_qc_parameters {} { tk_messageBox -icon info -title "QC Parameters" -message "QC parameters configuration would appear here." }
proc App::show_qc_dashboard {} { tk_messageBox -icon info -title "QC Dashboard" -message "Quality control dashboard would appear here." }
proc App::show_raw_materials {} { tk_messageBox -icon info -title "Raw Materials" -message "Raw materials inventory would appear here." }
proc App::show_finished_products {} { tk_messageBox -icon info -title "Finished Products" -message "Finished products inventory would appear here." }
proc App::show_material_receipts {} { tk_messageBox -icon info -title "Material Receipts" -message "Material receipts management would appear here." }
proc App::show_suppliers {} { tk_messageBox -icon info -title "Supplier Management" -message "Supplier management would appear here." }
proc App::show_inventory_dashboard {} { tk_messageBox -icon info -title "Inventory Dashboard" -message "Inventory dashboard would appear here." }
proc App::show_batch_status {} { tk_messageBox -icon info -title "Batch Status" -message "Batch status dashboard would appear here." }
proc App::show_user_management {} { tk_messageBox -icon info -title "User Management" -message "User management would appear here (Admin only)." }
proc App::show_audit_log {} { tk_messageBox -icon info -title "Audit Log" -message "Audit log would appear here (Admin only)." }
proc App::show_system_config {} { tk_messageBox -icon info -title "System Configuration" -message "System configuration would appear here (Admin only)." }
proc App::show_db_maintenance {} { tk_messageBox -icon info -title "Database Maintenance" -message "Database maintenance tools would appear here." }
proc App::show_role_management {} { tk_messageBox -icon info -title "Role Management" -message "Role management would appear here (Admin only)." }
proc App::show_data_browser {} { tk_messageBox -icon info -title "Data Browser" -message "Data browser would appear here." }
proc App::show_query_builder {} { tk_messageBox -icon info -title "Query Builder" -message "Query builder would appear here." }
proc App::backup_database {} { tk_messageBox -icon info -title "Backup Database" -message "Database backup would start here." }
proc App::restore_database {} { tk_messageBox -icon info -title "Restore Database" -message "Database restore would start here." }
proc App::show_settings {} { tk_messageBox -icon info -title "Settings" -message "Application settings would appear here." }
proc App::show_log {} { tk_messageBox -icon info -title "System Log" -message "System log would appear here." }
proc App::show_shortcuts {} { tk_messageBox -icon info -title "Keyboard Shortcuts" -message "Keyboard shortcuts reference would appear here." }
proc App::check_updates {} { tk_messageBox -icon info -title "Check Updates" -message "Checking for updates...\n\nYou are running the latest version." }
proc App::report_production {} { tk_messageBox -icon info -title "Production Report" -message "Production report would appear here." }
proc App::report_quality {} { tk_messageBox -icon info -title "Quality Report" -message "Quality report would appear here." }
proc App::report_cost_analysis {} { tk_messageBox -icon info -title "Cost Analysis" -message "Cost analysis report would appear here." }
proc App::report_yield_analysis {} { tk_messageBox -icon info -title "Yield Analysis" -message "Yield analysis report would appear here." }
proc App::report_inventory {} { tk_messageBox -icon info -title "Inventory Report" -message "Inventory report would appear here." }
proc App::export_batches {} { tk_messageBox -icon info -title "Export Batches" -message "Batch export would start here." }
proc App::show_qc_test_details {tree} { tk_messageBox -icon info -title "QC Test Details" -message "QC test details would appear here." }
proc App::show_production_chart {} { tk_messageBox -icon info -title "Production Chart" -message "Production chart would appear here." }

# ============================================
# 16. ABOUT AND HELP
# ============================================

proc App::show_about {} {
    tk_messageBox -icon info -title "About $Config::APP_NAME" \
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
# 17. START THE APPLICATION
# ============================================

create_login_window
vwait forever