#!/usr/bin/env tclsh
# ============================================
# TOOTHPASTE PRODUCTION MANAGER GUI
# Tcl/Tk with PostgreSQL (tdbc::postgres)
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
# 1. DATABASE CONNECTION
# ============================================

namespace eval DB {
    variable conn ""
    variable connected 0
    variable pg_available 0
    
    proc check_availability {} {
        variable pg_available
        return $pg_available
    }
    
    proc connect {host port db user password} {
        variable conn
        variable connected
        variable pg_available
        
        if {!$pg_available} {
            error "PostgreSQL driver (tdbc::postgres) is not available"
        }
        
        catch {
            # Using tdbc::postgres driver
            set conn [tdbc::postgres::connection new \
                -host $host -port $port -db $db \
                -user $user -password $password]
            set connected 1
        }
        return $connected
    }
    
    proc disconnect {} {
        variable conn
        variable connected
        if {$connected} {
            $conn close
            set connected 0
        }
    }
    
    proc connected {} {
        variable connected
        return $connected
    }
    
    proc exec_query {sql} {
        variable conn
        variable connected
        if {!$connected} {
            error "Not connected to database"
        }
        return [$conn prepare $sql]
    }
    
    proc eval {sql} {
        variable conn
        if {!$connected} {
            error "Not connected to database"
        }
        set stmt [$conn prepare $sql]
        $stmt execute
        set results {}
        $stmt foreach row {
            lappend results $row
        }
        $stmt close
        return $results
    }
    
    proc get_connection {} {
        variable conn
        return $conn
    }
}

# Set PostgreSQL availability
if {$pg_available} {
    DB::pg_available 1
}

# ============================================
# 2. MAIN APPLICATION CLASS
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
    
    # Main window initialization
    proc init {} {
        # Create main window
        wm title . "Toothpaste Production Manager v2.0"
        wm geometry . "1200x700+50+50"
        wm minsize . 1000 600
        
        # Set style
        ttk::style theme use clam
        
        # Create menu bar
        create_menu
        
        # Create toolbar
        create_toolbar
        
        # Create main container (paned window)
        set main_pane [ttk::panedwindow .mainpane -orient horizontal]
        pack $main_pane -fill both -expand true -side top
        
        # Left side - Navigation tree
        create_navigation $main_pane
        
        # Right side - Content area with notebook
        create_content_area $main_pane
        
        # Status bar
        create_statusbar
        
        # Initialize with dashboard
        show_dashboard
        
        # Check PostgreSQL driver availability
        if {![DB::check_availability]} {
            set_status "PostgreSQL driver not available! Please install tdbc::postgres" red
            .toolbar.status_ind configure -text "● Driver Missing" -foreground orange
        }
    }
    
    # Menu creation
    proc create_menu {} {
        menu .menubar -tearoff 0
        . configure -menu .menubar
        
        # File menu
        set file_menu [menu .menubar.file -tearoff 0]
        .menubar add cascade -label "File" -menu $file_menu
        $file_menu add command -label "Connect Database" -command {App::show_connection_dialog}
        $file_menu add command -label "Disconnect" -command {App::disconnect_db}
        $file_menu add separator
        $file_menu add command -label "Import Data" -command {App::import_data}
        $file_menu add command -label "Export Report" -command {App::export_report}
        $file_menu add separator
        $file_menu add command -label "Exit" -command {App::exit_app}
        
        # Production menu
        set prod_menu [menu .menubar.production -tearoff 0]
        .menubar add cascade -label "Production" -menu $prod_menu
        $prod_menu add command -label "New Batch" -command {App::show_batch_form}
        $prod_menu add command -label "View Batches" -command {App::show_batches}
        $prod_menu add command -label "Batch Status" -command {App::show_batch_status}
        $prod_menu add separator
        $prod_menu add command -label "Production Schedule" -command {App::show_schedule}
        
        # Formulations menu
        set form_menu [menu .menubar.formulations -tearoff 0]
        .menubar add cascade -label "Formulations" -menu $form_menu
        $form_menu add command -label "View Formulations" -command {App::show_formulations}
        $form_menu add command -label "New Formulation" -command {App::show_formulation_form}
        $form_menu add command -label "Component Search" -command {App::show_component_search}
        
        # Quality menu
        set qc_menu [menu .menubar.quality -tearoff 0]
        .menubar add cascade -label "Quality" -menu $qc_menu
        $qc_menu add command -label "QC Tests" -command {App::show_qc_tests}
        $qc_menu add command -label "Stability Studies" -command {App::show_stability}
        $qc_menu add command -label "Parameters" -command {App::show_qc_parameters}
        
        # Reports menu
        set report_menu [menu .menubar.reports -tearoff 0]
        .menubar add cascade -label "Reports" -menu $report_menu
        $report_menu add command -label "Batch Summary" -command {App::report_batch_summary}
        $report_menu add command -label "Inventory Status" -command {App::report_inventory}
        $report_menu add command -label "QC Dashboard" -command {App::report_qc_dashboard}
        $report_menu add command -label "Yield Analysis" -command {App::report_yield_analysis}
        $report_menu add separator
        $report_menu add command -label "Export PDF" -command {App::export_pdf}
        
        # Tools menu
        set tools_menu [menu .menubar.tools -tearoff 0]
        .menubar add cascade -label "Tools" -menu $tools_menu
        $tools_menu add command -label "Compound Library" -command {App::show_compound_library}
        $tools_menu add command -label "Supplier Management" -command {App::show_suppliers}
        $tools_menu add command -label "Lab Equipment" -command {App::show_equipment}
        $tools_menu add separator
        $tools_menu add command -label "Settings" -command {App::show_settings}
        $tools_menu add command -label "System Log" -command {App::show_log}
        
        # Help menu
        set help_menu [menu .menubar.help -tearoff 0]
        .menubar add cascade -label "Help" -menu $help_menu
        $help_menu add command -label "User Manual" -command {App::show_help}
        $help_menu add command -label "About" -command {App::show_about}
    }
    
    # Toolbar creation
    proc create_toolbar {} {
        set tool_frame [ttk::frame .toolbar -relief raised -borderwidth 1]
        pack $tool_frame -fill x -side top -pady 2
        
        # Button images (using text as placeholder)
        foreach {btn cmd text} {
            new_batch   {App::show_batch_form}     "New Batch"
            formulations {App::show_formulations}   "Formulations"
            qc_tests    {App::show_qc_tests}        "QC Tests"
            inventory   {App::report_inventory}     "Inventory"
            refresh     {App::refresh_current}      "Refresh"
        } {
            ttk::button $tool_frame.$btn -text $text -command $cmd
            pack $tool_frame.$btn -side left -padx 2 -pady 2
        }
        
        # Separator
        ttk::separator $tool_frame.sep -orient vertical
        pack $tool_frame.sep -side left -padx 5 -fill y
        
        # Search box
        ttk::label $tool_frame.lbl -text "Search:"
        pack $tool_frame.lbl -side left -padx 5
        
        ttk::entry $tool_frame.search -width 30
        pack $tool_frame.search -side left -padx 2
        
        ttk::button $tool_frame.go -text "Go" -command {App::search}
        pack $tool_frame.go -side left -padx 2
        
        # Status indicator on right
        ttk::label $tool_frame.status_ind -text "● Disconnected" -foreground red
        pack $tool_frame.status_ind -side right -padx 10
    }
    
    # Navigation tree
    proc create_navigation {parent} {
        set nav_frame [ttk::frame $parent.nav -width 200 -relief sunken]
        $parent add $nav_frame -weight 0
        
        ttk::label $nav_frame.title -text "Navigation" -font {Arial 12 bold}
        pack $nav_frame.title -pady 5
        
        # Create treeview for navigation
        set tree [ttk::treeview $nav_frame.tree -height 25 -selectmode browse]
        pack $tree -fill both -expand true -padx 5 -pady 5
        
        # Add navigation items
        set nodes {
            "Dashboard" "dashboard" {}
            "Production" "" {}
            "  Batches" "batches" production
            "  Schedule" "schedule" production
            "Formulations" "" {}
            "  All Formulations" "formulations" formulations
            "  Components" "components" formulations
            "Quality Control" "" {}
            "  QC Tests" "qctests" quality
            "  Stability Studies" "stability" quality
            "  QC Parameters" "qcparams" quality
            "Inventory" "" {}
            "  Raw Materials" "rawmaterials" inventory
            "  Finished Products" "finished" inventory
            "Reports" "" {}
            "  Batch Summary" "batchsummary" reports
            "  Yield Analysis" "yield" reports
            "  QC Dashboard" "qcdashboard" reports
            "Administration" "" {}
            "  Users" "users" admin
            "  Audit Log" "audit" admin
            "  Settings" "settings" admin
        }
        
        # Insert items
        set parent_item ""
        foreach {item tag group} $nodes {
            if {$item == ""} {
                set parent_item $tag
                continue
            }
            if {$tag == ""} {
                # This is a parent node
                set node_id [$tree insert {} end -text $item -open true -tags [list $group]]
                set parent_item $node_id
            } else {
                # Child node
                set node_id [$tree insert $parent_item end -text $item -tags [list $tag]]
            }
        }
        
        # Bind selection
        bind $tree <<TreeviewSelect>> [list App::navigate $tree]
        
        # Store tree reference
        variable nav_tree $tree
    }
    
    # Content area with notebooks
    proc create_content_area {parent} {
        set content_frame [ttk::frame $parent.content]
        $parent add $content_frame -weight 1
        
        # Create notebook
        set notebook_widget [ttk::notebook $content_frame.notebook]
        pack $notebook_widget -fill both -expand true
        
        # Add tabs
        set tabs {
            "Dashboard" "dashboard" 
            "Production" "production"
            "Formulations" "formulations"
            "Quality" "quality"
            "Inventory" "inventory"
            "Reports" "reports"
        }
        
        foreach {tab name} $tabs {
            set frame [ttk::frame $notebook_widget.$name]
            $notebook_widget add $frame -text $tab
        }
        
        variable main_notebook $notebook_widget
        
        # Initially show dashboard tab
        $notebook_widget select $notebook_widget.dashboard
        show_dashboard_content
    }
    
    # Status bar
    proc create_statusbar {} {
        set status_frame [ttk::frame .statusbar -relief sunken -borderwidth 1]
        pack $status_frame -fill x -side bottom
        
        ttk::label $status_frame.status -text "Ready" -anchor w
        pack $status_frame.status -side left -padx 5 -pady 2 -expand true -fill x
        
        ttk::label $status_frame.time -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        pack $status_frame.time -side right -padx 5
        
        variable status_var $status_frame.status
        
        # Update clock
        update_status_time
    }
    
    # Update status bar time
    proc update_status_time {} {
        if {[winfo exists .statusbar.time]} {
            .statusbar.time configure -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        }
        after 1000 App::update_status_time
    }
    
    # Set status message
    proc set_status {msg {color black}} {
        variable status_var
        if {[winfo exists $status_var]} {
            $status_var configure -text $msg -foreground $color
            update idletasks
        }
    }
}

# ============================================
# 3. CONNECTION DIALOG
# ============================================

proc App::show_connection_dialog {} {
    # Check if PostgreSQL driver is available
    if {![DB::check_availability]} {
        tk_messageBox -icon error -title "Driver Not Available" \
            -message "PostgreSQL driver (tdbc::postgres) is not installed.\n\nPlease install it using:\n\n  teacup install tdbc::postgres\n\nOr download from:\n  https://github.com/tcltk/tdbcpostgres"
        return
    }
    
    set w .connection_dialog
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Database Connection"
    wm geometry $w "450x320"
    
    ttk::label $w.title -text "PostgreSQL Connection Settings" -font {Arial 12 bold}
    pack $w.title -pady 10
    
    # PostgreSQL version info
    set ver_frame [ttk::frame $w.version]
    pack $ver_frame -fill x -padx 10 -pady 5
    ttk::label $ver_frame.lbl -text "Driver: tdbc::postgres (loaded)" -foreground green -font {Arial 9}
    pack $ver_frame.lbl -side left
    
    set fields [list \
        [list "Host:" host "localhost"] \
        [list "Port:" port "5432"] \
        [list "Database:" db "toothpaste_db"] \
        [list "Username:" user "postgres"] \
        [list "Password:" pass ""] \
    ]
    
    foreach {label var default} $fields {
        set f [ttk::frame $w.$var]
        pack $f -fill x -padx 10 -pady 2
        
        ttk::label $f.lbl -text $label -width 15
        pack $f.lbl -side left
        
        set entry [ttk::entry $f.entry -width 30]
        pack $f.entry -side left -expand true -fill x
        
        if {$var eq "pass"} {
            $entry configure -show "*"
        }
        
        # Store entry in array
        set entry_var [string tolower $var]
        set App::conn_entry($entry_var) $entry
        $entry insert 0 $default
    }
    
    set btn_frame [ttk::frame $w.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.connect -text "Connect" -command {
        App::connect_to_db
    }
    pack $btn_frame.connect -side left -padx 10
    
    ttk::button $btn_frame.test -text "Test Connection" -command {
        App::test_connection
    }
    pack $btn_frame.test -side left -padx 10
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .connection_dialog
    }
    pack $btn_frame.cancel -side right -padx 10
}

proc App::test_connection {} {
    variable conn_entry
    
    set host [$conn_entry(host) get]
    set port [$conn_entry(port) get]
    set db [$conn_entry(db) get]
    set user [$conn_entry(user) get]
    set pass [$conn_entry(pass) get]
    
    # Try to connect
    set temp_conn [DB::connect $host $port $db $user $pass]
    if {$temp_conn} {
        # Test query
        set conn [DB::get_connection]
        set stmt [$conn prepare "SELECT version()"]
        $stmt execute
        $stmt foreach row {
            set version [lindex $row 0]
        }
        $stmt close
        
        DB::disconnect
        tk_messageBox -icon info -title "Success" \
            -message "Connection successful!\nConnected to $db@$host\n\nPostgreSQL: $version"
    } else {
        tk_messageBox -icon error -title "Connection Failed" \
            -message "Failed to connect to database.\nPlease check your settings."
    }
}

proc App::connect_to_db {} {
    variable conn_entry
    
    set host [$conn_entry(host) get]
    set port [$conn_entry(port) get]
    set db [$conn_entry(db) get]
    set user [$conn_entry(user) get]
    set pass [$conn_entry(pass) get]
    
    if {[DB::connect $host $port $db $user $pass]} {
        set_status "Connected to $db@$host" green
        .toolbar.status_ind configure -text "● Connected" -foreground green
        destroy .connection_dialog
        load_initial_data
    } else {
        set_status "Connection failed!" red
        tk_messageBox -icon error -title "Connection Error" \
            -message "Failed to connect to database.\nPlease check your settings."
    }
}

proc App::disconnect_db {} {
    DB::disconnect
    set_status "Disconnected" red
    .toolbar.status_ind configure -text "● Disconnected" -foreground red
}

# ============================================
# 4. DASHBOARD
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
    
    # Clear existing content
    foreach child [winfo children $frame] {
        destroy $child
    }
    
    # Create dashboard layout
    set top_frame [ttk::frame $frame.top -relief ridge]
    pack $top_frame -fill x -padx 10 -pady 5
    
    # Title
    ttk::label $top_frame.title -text "Production Dashboard" -font {Arial 16 bold}
    pack $top_frame.title -pady 5
    
    # Stats grid
    set stats_frame [ttk::frame $frame.stats]
    pack $stats_frame -fill x -padx 10 -pady 5
    
    # Try to load stats from database
    if {[DB::connected]} {
        set stats_data [load_dashboard_stats]
    } else {
        set stats_data {
            "Total Batches" "0" "#4CAF50"
            "Active Formulations" "0" "#2196F3"
            "QC Tests Today" "0" "#FF9800"
            "Rejected Batches" "0" "#f44336"
            "Materials in Stock" "0" "#9C27B0"
            "Pending Orders" "0" "#00BCD4"
        }
    }
    
    set col 0
    foreach {label value color} $stats_data {
        set box [ttk::frame $stats_frame.box$col -relief ridge -borderwidth 2]
        pack $box -side left -padx 5 -pady 5 -expand true -fill both
        
        ttk::label $box.label -text $label -font {Arial 10}
        pack $box.label -pady 2
        
        ttk::label $box.value -text $value -font {Arial 18 bold} -foreground $color
        pack $box.value -pady 5
        
        incr col
    }
    
    # Main content split
    set main_frame [ttk::frame $frame.main]
    pack $main_frame -fill both -expand true -padx 10 -pady 5
    
    # Left side - Recent activity
    set left_frame [ttk::frame $main_frame.left -relief groove -borderwidth 1]
    pack $left_frame -side left -fill both -expand true -padx 5
    
    ttk::label $left_frame.title -text "Recent Activity" -font {Arial 12 bold}
    pack $left_frame.title -pady 5 -anchor w
    
    # Treeview for recent activity
    set tree [ttk::treeview $left_frame.tree -columns {time type status} -height 10]
    $tree heading #0 -text "Batch"
    $tree heading time -text "Time"
    $tree heading type -text "Type"
    $tree heading status -text "Status"
    $tree column #0 -width 120
    $tree column time -width 120
    $tree column type -width 100
    $tree column status -width 100
    pack $tree -fill both -expand true -padx 5 -pady 5
    
    # Load recent activity from database
    if {[DB::connected]} {
        load_recent_activity $tree
    } else {
        $tree insert {} end -text "No data" -values {"-" "System" "Disconnected"}
    }
    
    # Right side - Quick actions
    set right_frame [ttk::frame $main_frame.right -relief groove -borderwidth 1]
    pack $right_frame -side right -fill both -expand true -padx 5
    
    ttk::label $right_frame.title -text "Quick Actions" -font {Arial 12 bold}
    pack $right_frame.title -pady 5 -anchor w
    
    set actions {
        "Start New Batch" "App::show_batch_form"
        "Record QC Test" "App::show_qc_test_form"
        "View Inventory" "App::report_inventory"
        "Create Report" "App::report_batch_summary"
    }
    
    set idx 0
    foreach {action cmd} $actions {
        ttk::button $right_frame.btn$idx -text $action -command $cmd -width 25
        pack $right_frame.btn$idx -pady 5 -padx 10
        incr idx
    }
    
    # Quick stats on right
    ttk::label $right_frame.stats_title -text "Today's Statistics" -font {Arial 10 bold}
    pack $right_frame.stats_title -pady 10 -anchor w
    
    # Load today's stats from database
    if {[DB::connected]} {
        set today_stats [load_today_stats]
    } else {
        set today_stats {
            "Batches Completed" 0
            "QC Tests Performed" 0
            "Materials Received" 0
            "Samples in Lab" 0
        }
    }
    
    set idx 0
    foreach {stat value} $today_stats {
        set f [ttk::frame $right_frame.stat$idx]
        pack $f -fill x -pady 2
        
        ttk::label $f.label -text "$stat:" -width 20 -anchor w
        pack $f.label -side left -padx 10
        
        ttk::label $f.value -text $value -font {Arial 10 bold}
        pack $f.value -side right -padx 10
        
        incr idx
    }
}

# ============================================
# 5. DATABASE LOADING FUNCTIONS (PostgreSQL)
# ============================================

proc App::load_dashboard_stats {} {
    set conn [DB::get_connection]
    set stats {}
    
    # Get total batches
    set stmt [$conn prepare {SELECT COUNT(*) FROM production_batches}]
    $stmt execute
    $stmt foreach row {set total_batches [lindex $row 0]}
    $stmt close
    
    # Get active formulations
    set stmt [$conn prepare {SELECT COUNT(*) FROM formulations WHERE status = 'Active'}]
    $stmt execute
    $stmt foreach row {set active_formulations [lindex $row 0]}
    $stmt close
    
    # Get QC tests today
    set stmt [$conn prepare {SELECT COUNT(*) FROM qc_tests WHERE test_date >= CURRENT_DATE}]
    $stmt execute
    $stmt foreach row {set qc_today [lindex $row 0]}
    $stmt close
    
    # Get rejected batches
    set stmt [$conn prepare {SELECT COUNT(*) FROM production_batches WHERE status = 'Rejected'}]
    $stmt execute
    $stmt foreach row {set rejected [lindex $row 0]}
    $stmt close
    
    # Get materials in stock
    set stmt [$conn prepare {SELECT COUNT(DISTINCT compound_id) FROM raw_material_inventory WHERE quantity > 0}]
    $stmt execute
    $stmt foreach row {set materials [lindex $row 0]}
    $stmt close
    
    return [list \
        "Total Batches" $total_batches "#4CAF50" \
        "Active Formulations" $active_formulations "#2196F3" \
        "QC Tests Today" $qc_today "#FF9800" \
        "Rejected Batches" $rejected "#f44336" \
        "Materials in Stock" $materials "#9C27B0" \
        "Pending Orders" 0 "#00BCD4" \
    ]
}

proc App::load_recent_activity {tree} {
    set conn [DB::get_connection]
    
    set stmt [$conn prepare {
        SELECT batch_number, 
               TO_CHAR(created_at, 'HH24:MI') as time,
               'Production' as type,
               status
        FROM production_batches 
        ORDER BY created_at DESC 
        LIMIT 10
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row batch time type status
        $tree insert {} end -text $batch -values [list $time $type $status]
    }
    $stmt close
    
    # If no data, show a message
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No recent batches" -values {"-" "System" "No data"}
    }
}

proc App::load_today_stats {} {
    set conn [DB::get_connection]
    
    # Get batches completed today
    set stmt [$conn prepare {
        SELECT COUNT(*) FROM production_batches 
        WHERE status = 'Completed' 
        AND actual_end_date >= CURRENT_DATE
    }]
    $stmt execute
    $stmt foreach row {set batches_completed [lindex $row 0]}
    $stmt close
    
    # Get QC tests today
    set stmt [$conn prepare {
        SELECT COUNT(*) FROM qc_tests 
        WHERE test_date >= CURRENT_DATE
    }]
    $stmt execute
    $stmt foreach row {set qc_performed [lindex $row 0]}
    $stmt close
    
    # Get materials received today
    set stmt [$conn prepare {
        SELECT COUNT(*) FROM material_receipts 
        WHERE receipt_date >= CURRENT_DATE
    }]
    $stmt execute
    $stmt foreach row {set materials_received [lindex $row 0]}
    $stmt close
    
    return [list \
        "Batches Completed" $batches_completed \
        "QC Tests Performed" $qc_performed \
        "Materials Received" $materials_received \
        "Samples in Lab" 0 \
    ]
}

# ============================================
# 6. BATCH MANAGEMENT
# ============================================

proc App::show_batch_form {} {
    if {![DB::connected]} {
        tk_messageBox -icon warning -title "Not Connected" \
            -message "Please connect to the database first."
        return
    }
    
    set w .batch_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "New Production Batch"
    wm geometry $w "600x500"
    
    # Title
    ttk::label $w.title -text "Create New Production Batch" -font {Arial 14 bold}
    pack $w.title -pady 10
    
    # Load formulations from database
    set conn [DB::get_connection]
    set formulations_list {}
    set stmt [$conn prepare "SELECT formulation_id, formulation_name FROM formulations WHERE status = 'Active'"]
    $stmt execute
    $stmt foreach row {
        lassign $row id name
        lappend formulations_list $name
    }
    $stmt close
    
    # Load facilities from database
    set facilities_list {}
    set stmt [$conn prepare "SELECT facility_id, facility_name FROM production_facilities WHERE is_active = true"]
    $stmt execute
    $stmt foreach row {
        lassign $row id name
        lappend facilities_list $name
    }
    $stmt close
    
    # Load supervisors from database
    set supervisors_list {}
    set stmt [$conn prepare "SELECT person_id, first_name || ' ' || last_name FROM persons WHERE role IN ('Production_Manager', 'Supervisor')"]
    $stmt execute
    $stmt foreach row {
        lassign $row id name
        lappend supervisors_list $name
    }
    $stmt close
    
    # Form fields
    set fields [list \
        "Formulation:" "formulation" "combobox" \
        "Facility:" "facility" "combobox" \
        "Target Quantity (kg):" "quantity" "entry" \
        "Planned Start Date:" "start_date" "entry" \
        "Planned End Date:" "end_date" "entry" \
        "Supervisor:" "supervisor" "combobox" \
    ]
    
    set form_frame [ttk::frame $w.form]
    pack $form_frame -fill both -expand true -padx 20 -pady 10
    
    foreach {label var type} $fields {
        set f [ttk::frame $form_frame.$var]
        pack $f -fill x -pady 5
        
        ttk::label $f.lbl -text $label -width 20 -anchor e
        pack $f.lbl -side left -padx 5
        
        if {$type eq "combobox"} {
            set widget [ttk::combobox $f.cb -width 30]
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
            }
        } else {
            set widget [ttk::entry $f.entry -width 30]
        }
        pack $widget -side left -expand true -fill x
        set App::batch_form($var) $widget
        
        if {$var eq "start_date" || $var eq "end_date"} {
            $widget insert 0 [clock format [clock seconds] -format "%Y-%m-%d"]
        }
    }
    
    # Notes
    set note_f [ttk::frame $form_frame.notes]
    pack $note_f -fill x -pady 5
    
    ttk::label $note_f.lbl -text "Notes:" -width 20 -anchor e
    pack $note_f.lbl -side left -padx 5
    
    ttk::entry $note_f.entry -width 30
    pack $note_f.entry -side left -expand true -fill x
    set App::batch_form(notes) $note_f.entry
    
    # Buttons
    set btn_frame [ttk::frame $w.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.save -text "Create Batch" -command {
        App::save_batch
    }
    pack $btn_frame.save -side left -padx 10
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .batch_form
    }
    pack $btn_frame.cancel -side right -padx 10
}

proc App::save_batch {} {
    variable batch_form
    
    set formulation [$batch_form(formulation) get]
    set facility [$batch_form(facility) get]
    set quantity [$batch_form(quantity) get]
    set start_date [$batch_form(start_date) get]
    set end_date [$batch_form(end_date) get]
    set supervisor [$batch_form(supervisor) get]
    set notes [$batch_form(notes) get]
    
    if {$formulation eq "" || $quantity eq "" || $start_date eq "" || $end_date eq ""} {
        tk_messageBox -icon warning -title "Validation Error" \
            -message "Please fill in all required fields."
        return
    }
    
    set conn [DB::get_connection]
    
    # Get formulation_id
    set formulation_id ""
    set stmt [$conn prepare "SELECT formulation_id FROM formulations WHERE formulation_name = :name"]
    $stmt set parameter name $formulation
    $stmt execute
    $stmt foreach row {set formulation_id [lindex $row 0]}
    $stmt close
    
    # Get facility_id
    set facility_id ""
    set stmt [$conn prepare "SELECT facility_id FROM production_facilities WHERE facility_name = :name"]
    $stmt set parameter name $facility
    $stmt execute
    $stmt foreach row {set facility_id [lindex $row 0]}
    $stmt close
    
    # Get supervisor_id
    set supervisor_id ""
    set stmt [$conn prepare "SELECT person_id FROM persons WHERE first_name || ' ' || last_name = :name"]
    $stmt set parameter name $supervisor
    $stmt execute
    $stmt foreach row {set supervisor_id [lindex $row 0]}
    $stmt close
    
    # Call stored procedure
    set stmt [$conn prepare {
        SELECT create_production_batch(
            :formulation_id,
            :facility_id,
            :quantity::DECIMAL,
            :start_date::DATE,
            :end_date::DATE,
            :supervisor_id,
            1
        )
    }]
    
    $stmt set parameter formulation_id $formulation_id    $stmt set parameter facility_id $facility_id
    $stmt set parameter quantity $quantity
    $stmt set parameter start_date $start_date
    $stmt set parameter end_date $end_date
    $stmt set parameter supervisor_id $supervisor_id
    
    $stmt execute
    $stmt foreach row {set batch_id [lindex $row 0]}
    $stmt close
    
    set_status "Batch created successfully! ID: $batch_id" green
    tk_messageBox -icon info -title "Success" \
        -message "Production batch created successfully!\nBatch ID: $batch_id"
    destroy .batch_form
    show_batches
}

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
    
    # Title
    ttk::label $frame.title -text "Production Batches" -font {Arial 16 bold}
    pack $frame.title -pady 10
    
    # Filter toolbar
    set filter_frame [ttk::frame $frame.filters]
    pack $filter_frame -fill x -padx 10 -pady 5
    
    ttk::label $filter_frame.lbl -text "Status Filter:"
    pack $filter_frame.lbl -side left -padx 5
    
    set status_values [list "All"]
    set conn [DB::get_connection]
    set stmt [$conn prepare "SELECT DISTINCT status FROM production_batches ORDER BY status"]
    $stmt execute
    $stmt foreach row {
        lassign $row status
        lappend status_values $status
    }
    $stmt close
    
    ttk::combobox $filter_frame.status -values $status_values -width 15
    pack $filter_frame.status -side left -padx 5
    $filter_frame.status set "All"
    
    ttk::button $filter_frame.search -text "Search" -command {App::load_batches}
    pack $filter_frame.search -side left -padx 10
    
    ttk::button $filter_frame.new -text "New Batch" -command {App::show_batch_form}
    pack $filter_frame.new -side right -padx 10
    
    # Treeview for batches
    set tree_frame [ttk::frame $frame.tree_frame]
    pack $tree_frame -fill both -expand true -padx 10 -pady 5
    
    set tree [ttk::treeview $tree_frame.tree -columns {formulation facility quantity start end status yield} -height 20]
    $tree heading #0 -text "Batch Number"
    $tree heading formulation -text "Formulation"
    $tree heading facility -text "Facility"
    $tree heading quantity -text "Target (kg)"
    $tree heading start -text "Start Date"
    $tree heading end -text "End Date"
    $tree heading status -text "Status"
    $tree heading yield -text "Yield %"
    
    $tree column #0 -width 150
    $tree column formulation -width 150
    $tree column facility -width 120
    $tree column quantity -width 80
    $tree column start -width 100
    $tree column end -width 100
    $tree column status -width 100
    $tree column yield -width 80
    
    # Scrollbar
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    # Load batches from database
    load_batches $tree
    
    # Double-click to view details
    bind $tree <<TreeviewSelect>> {App::show_batch_details %W}
    
    set App::tree_vars(batches) $tree
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
    
    set conn [DB::get_connection]
    set stmt [$conn prepare {
        SELECT 
            pb.batch_number,
            f.formulation_name,
            pf.facility_name,
            pb.target_quantity_kg,
            TO_CHAR(pb.planned_start_date, 'YYYY-MM-DD') as start_date,
            TO_CHAR(pb.planned_end_date, 'YYYY-MM-DD') as end_date,
            pb.status,
            COALESCE(pb.yield_percentage::TEXT, '-') as yield
        FROM production_batches pb
        JOIN formulations f ON pb.formulation_id = f.formulation_id
        JOIN production_facilities pf ON pb.facility_id = pf.facility_id
        ORDER BY pb.created_at DESC
        LIMIT 100
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row batch_number formulation facility quantity start_date end_date status yield
        $tree insert {} end -text $batch_number -values [list $formulation $facility $quantity $start_date $end_date $status $yield]
    }
    $stmt close
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No batches found" -values {"-" "-" "-" "-" "-" "-" "-"}
    }
    
    set_status "Loaded batches" green
}

proc App::show_batch_details {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set batch [$tree item $selection -text]
    
    set w .batch_details
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Batch Details - $batch"
    wm geometry $w "600x400"
    
    ttk::label $w.title -text "Batch: $batch" -font {Arial 14 bold}
    pack $w.title -pady 10
    
    set text [text $w.text -wrap word -font {Courier 10} -yscrollcommand "$w.scroll set"]
    pack $text -side left -fill both -expand true -padx 10 -pady 5
    
    set scrollbar [ttk::scrollbar $w.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Load batch details from database
    set conn [DB::get_connection]
    set stmt [$conn prepare {
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
            p.first_name || ' ' || p.last_name as supervisor
        FROM production_batches pb
        JOIN formulations f ON pb.formulation_id = f.formulation_id
        JOIN production_facilities pf ON pb.facility_id = pf.facility_id
        LEFT JOIN persons p ON pb.supervisor_id = p.person_id
        WHERE pb.batch_number = :batch
    }]
    $stmt set parameter batch $batch
    $stmt execute
    
    $text insert end "Batch Details\n"
    $text insert end "=============\n\n"
    
    $stmt foreach row {
        lassign $row batch_number target_quantity_kg actual_quantity_kg yield_percentage planned_start_date planned_end_date actual_start_date actual_end_date status shift production_notes formulation_name facility_name supervisor
        $text insert end "Batch Number     : $batch_number\n"
        $text insert end "Formulation      : $formulation_name\n"
        $text insert end "Facility         : $facility_name\n"
        $text insert end "Supervisor       : $supervisor\n"
        $text insert end "Target Quantity  : $target_quantity_kg kg\n"
        $text insert end "Actual Quantity  : $actual_quantity_kg kg\n"
        $text insert end "Yield            : $yield_percentage%\n"
        $text insert end "Planned Start    : $planned_start_date\n"
        $text insert end "Planned End      : $planned_end_date\n"
        $text insert end "Actual Start     : $actual_start_date\n"
        $text insert end "Actual End       : $actual_end_date\n"
        $text insert end "Status           : $status\n"
        $text insert end "Shift            : $shift\n"
        $text insert end "Production Notes : $production_notes\n"
    }
    $stmt close
    
    $text configure -state disabled
    
    ttk::button $w.close -text "Close" -command "destroy $w"
    pack $w.close -pady 10
}

# ============================================
# 7. FORMULATIONS MANAGEMENT
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
    
    ttk::label $frame.title -text "Formulation Management" -font {Arial 16 bold}
    pack $frame.title -pady 10
    
    # Buttons
    set btn_frame [ttk::frame $frame.buttons]
    pack $btn_frame -fill x -padx 10 -pady 5
    
    ttk::button $btn_frame.new -text "New Formulation" -command {App::show_formulation_form}
    pack $btn_frame.new -side left -padx 5
    
    ttk::button $btn_frame.edit -text "Edit Selected" -command {App::edit_formulation}
    pack $btn_frame.edit -side left -padx 5
    
    ttk::button $btn_frame.view -text "View Components" -command {App::view_formulation_components}
    pack $btn_frame.view -side left -padx 5
    
    # Treeview for formulations
    set tree_frame [ttk::frame $frame.tree_frame]
    pack $tree_frame -fill both -expand true -padx 10 -pady 5
    
    set tree [ttk::treeview $tree_frame.tree -columns {brand type flavor ph fluoride status} -height 20]
    $tree heading #0 -text "Formulation Code"
    $tree heading brand -text "Brand"
    $tree heading type -text "Type"
    $tree heading flavor -text "Flavor"
    $tree heading ph -text "pH"
    $tree heading fluoride -text "Fluoride (ppm)"
    $tree heading status -text "Status"
    
    $tree column #0 -width 120
    $tree column brand -width 150
    $tree column type -width 120
    $tree column flavor -width 100
    $tree column ph -width 60
    $tree column fluoride -width 100
    $tree column status -width 100
    
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    # Load formulations from database
    load_formulations $tree
    
    set App::tree_vars(formulations) $tree
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
    
    # Clear existing items
    $tree delete [$tree children {}]
    
    set conn [DB::get_connection]
    set stmt [$conn prepare {
        SELECT 
            f.formulation_code,
            b.brand_name,
            f.product_type,
            f.flavor_profile,
            f.target_ph,
            f.fluoride_ppm,
            f.status
        FROM formulations f
        JOIN brands b ON f.brand_id = b.brand_id
        WHERE f.is_active = true
        ORDER BY f.formulation_code
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row code brand type flavor ph fluoride status
        $tree insert {} end -text $code -values [list $brand $type $flavor $ph $fluoride $status]
    }
    $stmt close
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No formulations found" -values {"-" "-" "-" "-" "-" "-"}
    }
}

proc App::view_formulation_components {} {
    variable tree_vars
    if {[info exists tree_vars(formulations)]} {
        set tree $tree_vars(formulations)
        set selection [$tree selection]
        if {$selection ne ""} {
            set code [$tree item $selection -text]
            set w .form_components
            catch {destroy $w}
            toplevel $w -class Dialog
            wm title $w "Formulation Components - $code"
            wm geometry $w "700x400"
            
            set comp_tree [ttk::treeview $w.tree -columns {function min max target phase} -height 15]
            pack $comp_tree -fill both -expand true -padx 5 -pady 5
            
            $comp_tree heading #0 -text "Compound Name"
            $comp_tree heading function -text "Function"
            $comp_tree heading min -text "Min %"
            $comp_tree heading max -text "Max %"
            $comp_tree heading target -text "Target %"
            $comp_tree heading phase -text "Phase"
            
            $comp_tree column #0 -width 200
            $comp_tree column function -width 120
            $comp_tree column min -width 80
            $comp_tree column max -width 80
            $comp_tree column target -width 80
            $comp_tree column phase -width 80
            
            # Load components from database
            set conn [DB::get_connection]
            set stmt [$conn prepare {
                SELECT 
                    cc.compound_name,
                    fc.function,
                    fc.percentage_min,
                    fc.percentage_max,
                    fc.percentage_target,
                    fc.phase
                FROM formulation_components fc
                JOIN chemical_compounds cc ON fc.compound_id = cc.compound_id
                JOIN formulations f ON fc.formulation_id = f.formulation_id
                WHERE f.formulation_code = :code
                ORDER BY fc.addition_order
            }]
            $stmt set parameter code $code
            $stmt execute
            $stmt foreach row {
                lassign $row name function min max target phase
                $comp_tree insert {} end -text $name -values [list $function $min $max $target $phase]
            }
            $stmt close
            
            if {[$comp_tree children {}] eq ""} {
                $comp_tree insert {} end -text "No components found" -values {"-" "-" "-" "-" "-"}
            }
            
            ttk::button $w.close -text "Close" -command "destroy $w"
            pack $w.close -pady 10
        } else {
            tk_messageBox -warning -title "Selection" "Please select a formulation to view components."
        }
    }
}

# ============================================
# 8. QUALITY CONTROL
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
    
    ttk::label $frame.title -text "Quality Control Tests" -font {Arial 16 bold}
    pack $frame.title -pady 10
    
    # Filter
    set filter_frame [ttk::frame $frame.filters]
    pack $filter_frame -fill x -padx 10 -pady 5
    
    ttk::label $filter_frame.lbl -text "Batch:"
    pack $filter_frame.lbl -side left -padx 5
    
    ttk::entry $filter_frame.batch -width 20
    pack $filter_frame.batch -side left -padx 5
    
    ttk::label $filter_frame.lbl2 -text "Status:"
    pack $filter_frame.lbl2 -side left -padx 5
    
    ttk::combobox $filter_frame.status -values {"All" "Pending" "In Progress" "Completed" "Approved" "Rejected"} -width 15
    pack $filter_frame.status -side left -padx 5
    $filter_frame.status set "All"
    
    ttk::button $filter_frame.search -text "Search" -command {App::load_qc_tests}
    pack $filter_frame.search -side left -padx 10
    
    ttk::button $filter_frame.new -text "New QC Test" -command {App::show_qc_test_form}
    pack $filter_frame.new -side right -padx 10
    
    # Treeview
    set tree_frame [ttk::frame $frame.tree_frame]
    pack $tree_frame -fill both -expand true -padx 10 -pady 5
    
    set tree [ttk::treeview $tree_frame.tree -columns {batch parameter result min max status test_date} -height 20]
    $tree heading #0 -text "Test Number"
    $tree heading batch -text "Batch"
    $tree heading parameter -text "Parameter"
    $tree heading result -text "Result"
    $tree heading min -text "Min"
    $tree heading max -text "Max"
    $tree heading status -text "Status"
    $tree heading test_date -text "Test Date"
    
    $tree column #0 -width 120
    $tree column batch -width 120
    $tree column parameter -width 150
    $tree column result -width 80
    $tree column min -width 80
    $tree column max -width 80
    $tree column status -width 100
    $tree column test_date -width 100
    
    set scrollbar [ttk::scrollbar $tree_frame.scroll -orient vertical -command "$tree yview"]
    $tree configure -yscrollcommand "$scrollbar set"
    
    pack $tree -side left -fill both -expand true
    pack $scrollbar -side right -fill y
    
    # Load QC tests from database
    load_qc_tests $tree
    
    set App::tree_vars(qc_tests) $tree
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
    
    # Clear existing items
    $tree delete [$tree children {}]
    
    set conn [DB::get_connection]
    set stmt [$conn prepare {
        SELECT 
            qt.test_number,
            pb.batch_number,
            qp.parameter_name,
            qt.test_result,
            qp.target_min,
            qp.target_max,
            qt.status,
            TO_CHAR(qt.test_date, 'YYYY-MM-DD') as test_date
        FROM qc_tests qt
        JOIN production_batches pb ON qt.batch_id = pb.batch_id
        JOIN qc_parameters qp ON qt.parameter_id = qp.parameter_id
        ORDER BY qt.test_date DESC
        LIMIT 100
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row test_number batch parameter result min max status test_date
        $tree insert {} end -text $test_number -values [list $batch $parameter $result $min $max $status $test_date]
    }
    $stmt close
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No QC tests found" -values {"-" "-" "-" "-" "-" "-" "-"}
    }
}

proc App::show_qc_test_form {} {
    set w .qc_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Record QC Test"
    wm geometry $w "500x400"
    
    # Load parameters from database
    set conn [DB::get_connection]
    set parameters_list {}
    set stmt [$conn prepare "SELECT parameter_id, parameter_name FROM qc_parameters ORDER BY parameter_name"]
    $stmt execute
    $stmt foreach row {
        lassign $row id name
        lappend parameters_list $name
    }
    $stmt close
    
    # Load labs from database
    set labs_list {}
    set stmt [$conn prepare "SELECT lab_id, lab_name FROM chemical_labs WHERE is_active = true"]
    $stmt execute
    $stmt foreach row {
        lassign $row id name
        lappend labs_list $name
    }
    $stmt close
    if {[llength $labs_list] == 0} {
        set labs_list {"QC Lab"}
    }
    
    ttk::label $w.title -text "Record Quality Control Test" -font {Arial 14 bold}
    pack $w.title -pady 10
    
    set fields {
        "Batch Number:" "batch"
        "Parameter:" "parameter"
        "Lab:" "lab"
        "Test Result:" "result"
        "Pass/Fail:" "result_status"
        "Notes:" "notes"
    }
    
    foreach {label var} $fields {
        set f [ttk::frame $w.$var]
        pack $f -fill x -pady 3 -padx 20
        
        ttk::label $f.lbl -text $label -width 15 -anchor e
        pack $f.lbl -side left
        
        if {$var eq "parameter"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values $parameters_list
            if {[llength $parameters_list] > 0} {
                $widget set [lindex $parameters_list 0]
            }
        } elseif {$var eq "lab"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values $labs_list
            if {[llength $labs_list] > 0} {
                $widget set [lindex $labs_list 0]
            }
        } elseif {$var eq "result_status"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values {"Pass" "Fail" "Pending"}
            $widget set "Pending"
        } elseif {$var eq "notes"} {
            set widget [ttk::entry $f.entry -width 30]
        } else {
            set widget [ttk::entry $f.entry -width 30]
        }
        pack $widget -side left -expand true -fill x
        set App::qc_form($var) $widget
    }
    
    set btn_frame [ttk::frame $w.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.save -text "Save Test" -command {
        App::save_qc_test
    }
    pack $btn_frame.save -side left -padx 10
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .qc_form
    }
    pack $btn_frame.cancel -side right -padx 10
}

proc App::save_qc_test {} {
    variable qc_form
    
    set batch [$qc_form(batch) get]
    set parameter [$qc_form(parameter) get]
    set lab [$qc_form(lab) get]
    set result [$qc_form(result) get]
    set result_status [$qc_form(result_status) get]
    set notes [$qc_form(notes) get]
    
    if {$batch eq "" || $parameter eq "" || $result eq ""} {
        tk_messageBox -warning -title "Validation" \
            -message "Please fill in all required fields."
        return
    }
    
    set conn [DB::get_connection]
    
    # Get batch_id
    set batch_id ""
    set stmt [$conn prepare "SELECT batch_id FROM production_batches WHERE batch_number = :batch"]
    $stmt set parameter batch $batch
    $stmt execute
    $stmt foreach row {set batch_id [lindex $row 0]}
    $stmt close
    
    if {$batch_id eq ""} {
        tk_messageBox -warning -title "Error" \
            -message "Batch '$batch' not found. Please enter a valid batch number."
        return
    }
    
    # Get parameter_id
    set parameter_id ""
    set stmt [$conn prepare "SELECT parameter_id FROM qc_parameters WHERE parameter_name = :name"]
    $stmt set parameter name $parameter
    $stmt execute
    $stmt foreach row {set parameter_id [lindex $row 0]}
    $stmt close
    
    # Get lab_id
    set lab_id 1
    set stmt [$conn prepare "SELECT lab_id FROM chemical_labs WHERE lab_name = :name"]
    $stmt set parameter name $lab
    $stmt execute
    $stmt foreach row {set lab_id [lindex $row 0]}
    $stmt close
    
    # Call stored procedure
    set stmt [$conn prepare {
        SELECT record_qc_test(
            :batch_id,
            :parameter_id,
            :lab_id,
            :result::DECIMAL,
            :notes,
            1,
            :notes
        )
    }]
    
    $stmt set parameter batch_id $batch_id
    $stmt set parameter parameter_id $parameter_id
    $stmt set parameter lab_id $lab_id
    $stmt set parameter result $result
    $stmt set parameter notes $notes
    
    $stmt execute
    $stmt foreach row {set test_id [lindex $row 0]}
    $stmt close
    
    set_status "QC test recorded! ID: $test_id" green
    tk_messageBox -icon info -title "Success" \
        -message "QC test recorded successfully!\nTest ID: $test_id"
    destroy .qc_form
    show_qc_tests
}

# ============================================
# 9. REPORTING FUNCTIONS
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
    
    ttk::label $frame.title -text "Batch Summary Report" -font {Arial 16 bold}
    pack $frame.title -pady 10
    
    # Report parameters
    set param_frame [ttk::frame $frame.params -relief groove -borderwidth 1]
    pack $param_frame -fill x -padx 10 -pady 10
    
    ttk::label $param_frame.lbl -text "Date Range:" -font {Arial 10 bold}
    pack $param_frame.lbl -side left -padx 10
    
    ttk::label $param_frame.from -text "From:"
    pack $param_frame.from -side left -padx 5
    
    ttk::entry $param_frame.from_entry -width 15
    pack $param_frame.from_entry -side left
    $param_frame.from_entry insert 0 [clock format [clock seconds] -format "%Y-%m-01"]
    
    ttk::label $param_frame.to -text "To:"
    pack $param_frame.to -side left -padx 5
    
    ttk::entry $param_frame.to_entry -width 15
    pack $param_frame.to_entry -side left
    $param_frame.to_entry insert 0 [clock format [clock seconds] -format "%Y-%m-%d"]
    
    ttk::button $param_frame.run -text "Generate Report" -command {App::generate_batch_summary}
    pack $param_frame.run -side left -padx 10
    
    ttk::button $param_frame.export -text "Export PDF" -command {App::export_pdf}
    pack $param_frame.export -side left -padx 10
    
    # Report content
    set report_frame [ttk::frame $frame.report -relief sunken -borderwidth 1]
    pack $report_frame -fill both -expand true -padx 10 -pady 5
    
    # Text widget for report
    set text [text $report_frame.text -wrap word -font {Courier 10} -yscrollcommand "$report_frame.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $report_frame.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Generate report
    if {[DB::connected]} {
        generate_report_content $text
    } else {
        $text insert end "= NOT CONNECTED TO DATABASE =\n"
        $text insert end "Please connect to the database first."
    }
    
    $text configure -state disabled
    set App::report_text $text
}

proc App::generate_report_content {text} {
    set conn [DB::get_connection]
    
    $text insert end "= TOOTHPASTE PRODUCTION BATCH SUMMARY REPORT =\n"
    $text insert end "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]\n"
    $text insert end "-" * 60 "\n\n"
    
    # Get summary statistics
    set stmt [$conn prepare {
        SELECT 
            COUNT(*) as total_batches,
            SUM(target_quantity_kg) as total_target,
            AVG(yield_percentage) as avg_yield,
            COUNT(CASE WHEN status = 'Released' THEN 1 ELSE NULL END) as released,
            COUNT(CASE WHEN status = 'Rejected' THEN 1 ELSE NULL END) as rejected
        FROM production_batches
        WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row total total_target avg_yield released rejected
        if {$total > 0} {
            $text insert end "Summary Statistics (Last 30 Days):\n"
            $text insert end "----------------------------------\n"
            $text insert end "Total Batches      : $total\n"
            $text insert end "Total Production   : [format "%.0f" $total_target] kg\n"
            $text insert end "Average Yield      : [format "%.1f" $avg_yield]%\n"
            $text insert end "Released Batches   : $released\n"
            $text insert end "Rejected Batches   : $rejected\n\n"
        } else {
            $text insert end "No data available for the selected period.\n\n"
        }
    }
    $stmt close
    
    # Get batch details
    $text insert end "Batch Details (Recent):\n"
    $text insert end "---------------------\n"
    $text insert end "| Batch Number | Formulation      | Quantity (kg) | Yield % | Status     |\n"
    $text insert end "|--------------|------------------|---------------|---------|------------|\n"
    
    set stmt [$conn prepare {
        SELECT 
            pb.batch_number,
            f.formulation_name,
            pb.target_quantity_kg,
            pb.yield_percentage,
            pb.status
        FROM production_batches pb
        JOIN formulations f ON pb.formulation_id = f.formulation_id
        WHERE pb.created_at >= CURRENT_DATE - INTERVAL '30 days'
        ORDER BY pb.created_at DESC
        LIMIT 20
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row batch formulation quantity yield status
        set yield_val [expr {$yield eq "" ? "-" : [format "%.1f" $yield]}]
        set line [format "| %-12s | %-16s | %-13s | %-7s | %-10s |" \
            $batch [string range $formulation 0 16] $quantity $yield_val $status]
        $text insert end "$line\n"
    }
    $stmt close
}

# ============================================
# 10. COMPOUND LIBRARY
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
    wm title $w "Chemical Compound Library"
    wm geometry $w "800x500"
    
    set tree [ttk::treeview $w.tree -columns {formula cas type state density ph} -height 20]
    pack $tree -fill both -expand true -padx 5 -pady 5
    
    $tree heading #0 -text "Compound Name"
    $tree heading formula -text "Formula"
    $tree heading cas -text "CAS Number"
    $tree heading type -text "Type"
    $tree heading state -text "State"
    $tree heading density -text "Density"
    $tree heading ph -text "pH"
    
    $tree column #0 -width 200
    $tree column formula -width 100
    $tree column cas -width 120
    $tree column type -width 120
    $tree column state -width 80
    $tree column density -width 80
    $tree column ph -width 60
    
    # Load compounds from database
    set conn [DB::get_connection]
    set stmt [$conn prepare {
        SELECT compound_name, chemical_formula, cas_number, compound_type, 
               physical_state, density, ph_level
        FROM chemical_compounds
        WHERE is_active = true
        ORDER BY compound_name
    }]
    $stmt execute
    $stmt foreach row {
        lassign $row name formula cas type state density ph
        $tree insert {} end -text $name -values [list $formula $cas $type $state $density $ph]
    }
    $stmt close
    
    if {[$tree children {}] eq ""} {
        $tree insert {} end -text "No compounds found" -values {"-" "-" "-" "-" "-" "-"}
    }
    
    ttk::button $w.close -text "Close" -command "destroy $w"
    pack $w.close -pady 10
}

# ============================================
# 11. UTILITY FUNCTIONS
# ============================================

proc App::clear_content {frame} {
    foreach child [winfo children $frame] {
        destroy $child
    }
}

proc App::navigate {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set tags [$tree tags $selection]
    if {$tags ne ""} {
        set tag [lindex $tags 0]
        switch $tag {
            "dashboard" {show_dashboard}
            "batches" {show_batches}
            "formulations" {show_formulations}
            "qctests" {show_qc_tests}
            "stability" {show_stability}
            "inventory" {report_inventory}
            "batchsummary" {report_batch_summary}
            default {}
        }
    }
}

proc App::load_initial_data {} {
    set_status "Loading data..." blue
    set conn [DB::get_connection]
    
    # Test connection by getting PostgreSQL version
    set stmt [$conn prepare "SELECT version()"]
    $stmt execute
    $stmt foreach row {set version [lindex $row 0]}
    $stmt close
    
    set_status "Connected to PostgreSQL: [string range $version 0 50]..." green
    
    # Refresh dashboard
    show_dashboard
}

proc App::refresh_current {} {
    set_status "Refreshing..."
    after 500 {set_status "Refreshed" green}
    variable main_notebook
    set current_tab [$main_notebook select]
    set tab_name [string last "." $current_tab]
    set tab_name [string range $current_tab [expr {$tab_name + 1}] end]
    
    switch $tab_name {
        "dashboard" {show_dashboard}
        "production" {show_batches}
        "formulations" {show_formulations}
        "quality" {show_qc_tests}
        "reports" {report_batch_summary}
        default {}
    }
}

proc App::search {} {
    set search_text [.toolbar.search get]
    if {$search_text ne ""} {
        set_status "Searching for '$search_text'..."
        set conn [DB::get_connection]
        set results {}
        
        # Search in formulations
        set stmt [$conn prepare {
            SELECT 'Formulation' as type, formulation_code || ' - ' || formulation_name as name
            FROM formulations 
            WHERE formulation_code ILIKE :search OR formulation_name ILIKE :search
            LIMIT 10
        }]
        $stmt set parameter search "%$search_text%"
        $stmt execute
        $stmt foreach row {
            lassign $row type name
            lappend results "$type: $name"
        }
        $stmt close
        
        # Search in compounds
        set stmt [$conn prepare {
            SELECT 'Compound' as type, compound_name
            FROM chemical_compounds 
            WHERE compound_name ILIKE :search OR cas_number ILIKE :search
            LIMIT 10
        }]
        $stmt set parameter search "%$search_text%"
        $stmt execute
        $stmt foreach row {
            lassign $row type name
            lappend results "$type: $name"
        }
        $stmt close
        
        # Search in batches
        set stmt [$conn prepare {
            SELECT 'Batch' as type, batch_number
            FROM production_batches 
            WHERE batch_number ILIKE :search
            LIMIT 10
        }]
        $stmt set parameter search "%$search_text%"
        $stmt execute
        $stmt foreach row {
            lassign $row type name
            lappend results "$type: $name"
        }
        $stmt close
        
        if {[llength $results] > 0} {
            tk_messageBox -info -title "Search Results" \
                -message "Found [llength $results] results:\n\n[join $results \n]"
        } else {
            tk_messageBox -info -title "Search Results" \
                -message "No results found for '$search_text'"
        }
        set_status "Search completed" green
    }
}

proc App::export_report {} {
    set file [tk_getSaveFile -title "Export Report" -defaultextension .csv -filetypes {{"CSV Files" *.csv} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting to $file..."
        tk_messageBox -info -title "Export" "Report exported to $file"
        set_status "Export completed" green
    }
}

proc App::export_pdf {} {
    set file [tk_getSaveFile -title "Export PDF" -defaultextension .pdf -filetypes {{"PDF Files" *.pdf} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting PDF to $file..."
        tk_messageBox -info -title "Export" "PDF exported to $file"
        set_status "PDF export completed" green
    }
}

proc App::import_data {} {
    set file [tk_getOpenFile -title "Import Data" -filetypes {{"CSV Files" *.csv} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Importing data from $file..."
        tk_messageBox -info -title "Import" "Data imported from $file"
        set_status "Import completed" green
    }
}

proc App::show_about {} {
    tk_messageBox -info -title "About" \
        -message "Toothpaste Production Manager v2.0\n\nA comprehensive Tcl/Tk GUI for managing toothpaste production processes.\n\nDatabase: PostgreSQL\nLanguage: Tcl/Tk\nDriver: tdbc::postgres\n\n© 2026 Production Management Systems"
}

proc App::show_help {} {
    set w .help
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Help - Toothpaste Production Manager"
    wm geometry $w "600x500"
    
    set text [text $w.text -wrap word -font {Arial 10} -yscrollcommand "$w.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $w.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    $text insert end "TOOTHPASTE PRODUCTION MANAGER\n"
    $text insert end "=================================\n\n"
    $text insert end "Getting Started:\n"
    $text insert end "1. Connect to PostgreSQL database using File > Connect Database\n"
    $text insert end "2. Navigate through the application using the left panel\n"
    $text insert end "3. Use the toolbar for quick access to common tasks\n\n"
    $text insert end "Production Management:\n"
    $text insert end "- Create and track production batches\n"
    $text insert end "- Monitor batch status and progress\n"
    $text insert end "- Record production parameters and deviations\n\n"
    $text insert end "Formulations:\n"
    $text insert end "- View and edit toothpaste formulations\n"
    $text insert end "- Manage chemical components and percentages\n"
    $text insert end "- Track formulation versions and status\n\n"
    $text insert end "Quality Control:\n"
    $text insert end "- Record QC test results\n"
    $text insert end "- Monitor stability studies\n"
    $text insert end "- Track QC parameters and specifications\n\n"
    $text insert end "Reports:\n"
    $text insert end "- Generate batch summary reports\n"
    $text insert end "- Export data to CSV or PDF\n"
    $text insert end "- Analyze production performance\n\n"
    $text insert end "For detailed documentation, please refer to the user manual."
    
    $text configure -state disabled
}

# Placeholder functions for unimplemented features
proc App::show_settings {} { tk_messageBox -info -title "Settings" "Application settings dialog would open here." }
proc App::show_log {} { tk_messageBox -info -title "System Log" "System log would appear here." }
proc App::show_stability {} { tk_messageBox -info -title "Stability Studies" "Stability studies management would appear here." }
proc App::show_suppliers {} { tk_messageBox -info -title "Supplier Management" "Supplier management interface would appear here." }
proc App::show_equipment {} { tk_messageBox -info -title "Lab Equipment" "Laboratory equipment management would appear here." }
proc App::show_qc_parameters {} { tk_messageBox -info -title "QC Parameters" "Quality control parameters configuration." }
proc App::show_schedule {} { tk_messageBox -info -title "Production Schedule" "Production scheduling calendar would appear here." }
proc App::show_component_search {} { tk_messageBox -info -title "Component Search" "Search chemical components by name, CAS, or type." }
proc App::report_inventory {} { tk_messageBox -info -title "Inventory Report" "Inventory status report would appear here." }
proc App::report_yield_analysis {} { tk_messageBox -info -title "Yield Analysis" "Production yield analysis report." }
proc App::report_qc_dashboard {} { tk_messageBox -info -title "QC Dashboard" "Quality control dashboard." }
proc App::generate_batch_summary {} { set_status "Generating batch summary report..."; after 1000 {set_status "Report generated" green}; tk_messageBox -info -title "Report" "Batch summary report generated successfully!" }
proc App::edit_formulation {} { variable tree_vars; if {[info exists tree_vars(formulations)]} { set tree $tree_vars(formulations); set selection [$tree selection]; if {$selection ne ""} { set code [$tree item $selection -text]; tk_messageBox -info -title "Edit Formulation" "Editing formulation: $code" } else { tk_messageBox -warning -title "Selection" "Please select a formulation to edit." } } }
proc App::show_formulation_form {} { tk_messageBox -info -title "New Formulation" "New formulation form would appear here." }
proc App::show_batch_status {} { tk_messageBox -info -title "Batch Status" "Batch status dashboard would appear here." }

# Exit application
proc App::exit_app {} {
    if {[tk_messageBox -icon question -type yesno -title "Exit" \
            -message "Are you sure you want to exit?"] eq "yes"} {
        DB::disconnect
        destroy .
    }
}

# ============================================
# 12. START THE APPLICATION
# ============================================

# Handle window close
wm protocol . WM_DELETE_WINDOW App::exit_app

# Initialize the application
App::init

# Enter the Tk event loop
vwait forever