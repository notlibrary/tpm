#!/usr/bin/env tclsh
# ============================================
# TOOTHPASTE PRODUCTION MANAGER GUI
# Tcl/Tk with PostgreSQL Integration
# ============================================

package require Tk
package require ttk
package require sqlite3
# For PostgreSQL, we'll use the tdbc::postgres driver
# package require tdbc::postgres

# ============================================
# 1. DATABASE CONNECTION
# ============================================

namespace eval DB {
    variable conn ""
    variable connected 0
    
    proc connect {host port db user password} {
        variable conn
        variable connected
        
        catch {
            # Using tdbc::postgres driver
            # set conn [tdbc::postgres::connection new \
            #     -host $host -port $port -db $db \
            #     -user $user -password $password]
            # set connected 1
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
    
    proc exec_query {sql} {
        variable conn
        variable connected
        if {!$connected} {
            error "Not connected to database"
        }
        return [$conn prepare $sql]
    }
}

# ============================================
# 2. MAIN APPLICATION CLASS
# ============================================

namespace eval App {
    variable current_frame ""
    variable notebook ""
    variable status_var ""
    variable tree_vars
    
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
        set notebook [ttk::notebook $content_frame.notebook]
        pack $notebook -fill both -expand true
        
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
            set frame [ttk::frame $notebook.$name]
            $notebook add $frame -text $tab
        }
        
        variable notebook $notebook
        
        # Initially show dashboard tab
        $notebook select $notebook.dashboard
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
        variable status_var
        if {[winfo exists .statusbar.time]} {
            .statusbar.time configure -text [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        }
        after 1000 App::update_status_time
    }
    
    # Set status message
    proc set_status {msg {color black}} {
        variable status_var
        $status_var configure -text $msg -foreground $color
        update idletasks
    }
}

# ============================================
# 3. CONNECTION DIALOG
# ============================================

proc App::show_connection_dialog {} {
    set w .connection_dialog
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Database Connection"
    wm geometry $w "400x250"
    
    ttk::label $w.title -text "PostgreSQL Connection Settings" -font {Arial 12 bold}
    pack $w.title -pady 10
    
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
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .connection_dialog
    }
    pack $btn_frame.cancel -side right -padx 10
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
    variable notebook
    $notebook select $notebook.dashboard
    show_dashboard_content
}

proc App::show_dashboard_content {} {
    set frame $notebook.dashboard
    
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
    
    # Stats boxes
    set stats_data {
        "Total Batches" "1,234" "#4CAF50"
        "Active Formulations" "15" "#2196F3"
        "QC Tests Today" "23" "#FF9800"
        "Rejected Batches" "3" "#f44336"
        "Materials in Stock" "45" "#9C27B0"
        "Pending Orders" "8" "#00BCD4"
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
    
    # Sample data
    $tree insert {} end -text "BT20260115-0001" -values {"15:30" "Production" "Active"}
    $tree insert {} end -text "BT20260115-0002" -values {"14:20" "QC Test" "Passed"}
    $tree insert {} end -text "BT20260114-0003" -values {"11:45" "Stability" "In Progress"}
    
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
    
    foreach {action cmd} $actions {
        ttk::button $right_frame.btn$idx -text $action -command $cmd -width 25
        pack $right_frame.btn$idx -pady 5 -padx 10
        incr idx
    }
    
    # Quick stats on right
    ttk::label $right_frame.stats_title -text "Today's Statistics" -font {Arial 10 bold}
    pack $right_frame.stats_title -pady 10 -anchor w
    
    set today_stats {
        "Batches Completed" 5
        "QC Tests Performed" 12
        "Materials Received" 3
        "Samples in Lab" 8
    }
    
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
# 5. BATCH MANAGEMENT
# ============================================

proc App::show_batch_form {} {
    set w .batch_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "New Production Batch"
    wm geometry $w "600x500"
    
    # Title
    ttk::label $w.title -text "Create New Production Batch" -font {Arial 14 bold}
    pack $w.title -pady 10
    
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
            # Populate with sample data
            if {$var eq "formulation"} {
                $widget configure -values {"Cavity Protection Classic" "Total Advanced Care" "Pro-Health Enamel" "3D White Professional"}
            } elseif {$var eq "facility"} {
                $widget configure -values {"New York Manufacturing Plant" "Ohio Production Facility" "UK Manufacturing Centre"}
            } elseif {$var eq "supervisor"} {
                $widget configure -values {"Dr. Smith" "Dr. Jones" "Dr. Kumar"}
            }
        } else {
            set widget [ttk::entry $f.entry -width 30]
        }
        pack $widget -side left -expand true -fill x
        set App::batch_form($var) $widget
        
        if {$var eq "start_date" || $var eq "end_date"} {
            # Add date picker (placeholder)
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
    
    if {$formulation eq "" || $quantity eq ""} {
        tk_messageBox -icon warning -title "Validation Error" \
            -message "Please fill in all required fields."
        return
    }
    
    # In production, this would call the database stored procedure
    # DB::exec_query "SELECT create_production_batch(...)"
    
    set_status "Batch created successfully!" green
    tk_messageBox -icon info -title "Success" \
        -message "Production batch created successfully!\nBatch Number: BT20260115-0001"
    destroy .batch_form
    show_batches
}

proc App::show_batches {} {
    variable notebook
    $notebook select $notebook.production
    
    set frame $notebook.production
    clear_content $frame
    
    # Title
    ttk::label $frame.title -text "Production Batches" -font {Arial 16 bold}
    pack $frame.title -pady 10
    
    # Filter toolbar
    set filter_frame [ttk::frame $frame.filters]
    pack $filter_frame -fill x -padx 10 -pady 5
    
    ttk::label $filter_frame.lbl -text "Status Filter:"
    pack $filter_frame.lbl -side left -padx 5
    
    ttk::combobox $filter_frame.status -values {"All" "Planned" "In Production" "QC Testing" "Completed" "Released"}
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
    
    # Sample data
    foreach batch {
        "BT20260115-0001" "Cavity Protection" "NY Plant" 2500 "2026-01-15" "2026-01-15" "Completed" 98.5
        "BT20260115-0002" "Total Advanced" "Ohio Plant" 3000 "2026-01-15" "2026-01-16" "In Production" "-"
        "BT20260114-0003" "Pro-Health" "NY Plant" 2000 "2026-01-14" "2026-01-14" "Completed" 97.2
        "BT20260114-0004" "3D White" "UK Plant" 1500 "2026-01-14" "2026-01-14" "QC Testing" "-"
    } {
        $tree insert {} end -text [lindex $batch 0] -values [lrange $batch 1 end]
    }
    
    # Double-click to view details
    bind $tree <<TreeviewSelect>> {App::show_batch_details %W}
    
    set App::tree_vars(batches) $tree
}

proc App::show_batch_details {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set batch [$tree item $selection -text]
    tk_messageBox -info -title "Batch Details" \
        -message "Batch: $batch\n\nDetails would be loaded from database."
}

# ============================================
# 6. FORMULATIONS MANAGEMENT
# ============================================

proc App::show_formulations {} {
    variable notebook
    $notebook select $notebook.formulations
    
    set frame $notebook.formulations
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
    
    # Sample formulations
    foreach form {
        "FRM-001" "Colgate Cavity Protection" "Regular" "Mint" 7.0 1000 "Active"
        "FRM-002" "Colgate Total" "Gum Care" "Peppermint" 6.8 1450 "Active"
        "FRM-003" "Crest Pro-Health" "Enamel Repair" "Clean Mint" 7.2 1100 "Active"
        "FRM-004" "Crest 3D White" "Whitening" "Radiant Mint" 6.5 1500 "Active"
        "FRM-005" "Sensodyne Relief" "Sensitive" "Mint" 7.0 0 "Active"
    } {
        $tree insert {} end -text [lindex $form 0] -values [lrange $form 1 end]
    }
    
    set App::tree_vars(formulations) $tree
}

proc App::show_formulation_form {} {
    set w .formulation_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "New Formulation"
    wm geometry $w "700x600"
    
    # Notebook for form sections
    set nb [ttk::notebook $w.nb]
    pack $nb -fill both -expand true -padx 10 -pady 10
    
    # General info tab
    set gen_frame [ttk::frame $nb.general]
    $nb add $gen_frame -text "General Info"
    
    set fields {
        "Formulation Code:" "code"
        "Formulation Name:" "name"
        "Brand:" "brand"
        "Product Type:" "type"
        "Flavor Profile:" "flavor"
        "Target pH:" "ph"
        "Fluoride (ppm):" "fluoride"
        "Status:" "status"
    }
    
    foreach {label var} $fields {
        set f [ttk::frame $gen_frame.$var]
        pack $f -fill x -pady 3 -padx 10
        
        ttk::label $f.lbl -text $label -width 20 -anchor e
        pack $f.lbl -side left
        
        set entry [ttk::entry $f.entry -width 30]
        pack $f.entry -side left -expand true -fill x
        set App::form_form($var) $entry
        
        if {$var eq "status"} {
            $entry insert 0 "Active"
        }
    }
    
    # Components tab
    set comp_frame [ttk::frame $nb.components]
    $nb add $comp_frame -text "Components"
    
    # Components list with percentages
    ttk::label $comp_frame.title -text "Formulation Components" -font {Arial 10 bold}
    pack $comp_frame.title -pady 5
    
    set comp_tree [ttk::treeview $comp_frame.tree -columns {cas function min max target phase} -height 10]
    $comp_tree heading #0 -text "Compound Name"
    $comp_tree heading cas -text "CAS"
    $comp_tree heading function -text "Function"
    $comp_tree heading min -text "Min %"
    $comp_tree heading max -text "Max %"
    $comp_tree heading target -text "Target %"
    $comp_tree heading phase -text "Phase"
    
    $comp_tree column #0 -width 150
    $comp_tree column cas -width 120
    $comp_tree column function -width 120
    $comp_tree column min -width 60
    $comp_tree column max -width 60
    $comp_tree column target -width 60
    $comp_tree column phase -width 80
    
    pack $comp_tree -fill both -expand true -padx 5 -pady 5
    
    # Add component button
    ttk::button $comp_frame.add -text "Add Component" -command {App::add_component}
    pack $comp_frame.add -pady 5
    
    # Buttons
    set btn_frame [ttk::frame $w.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.save -text "Save Formulation" -command {
        App::save_formulation
    }
    pack $btn_frame.save -side left -padx 10
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .formulation_form
    }
    pack $btn_frame.cancel -side right -padx 10
}

proc App::add_component {} {
    set w .add_comp
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Add Component"
    wm geometry $w "450x350"
    
    set fields {
        "Compound:" "compound"
        "Function:" "function"
        "Min %:" "min"
        "Max %:" "max"
        "Target %:" "target"
        "Phase:" "phase"
    }
    
    foreach {label var} $fields {
        set f [ttk::frame $w.$var]
        pack $f -fill x -pady 3 -padx 10
        
        ttk::label $f.lbl -text $label -width 15 -anchor e
        pack $f.lbl -side left
        
        if {$var eq "compound"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values {"Sodium Fluoride" "Glycerin" "Sorbitol" "Hydrated Silica" "SLS" "Peppermint Oil"}
        } elseif {$var eq "phase"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values {"Aqueous" "Oil" "Powder" "Additive" "Flavor" "Active"}
        } elseif {$var eq "function"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values {"Active Ingredient" "Humectant" "Abrasive" "Surfactant" "Flavor" "Binder" "Sweetener"}
        } else {
            set widget [ttk::entry $f.entry -width 30]
        }
        pack $widget -side left -expand true -fill x
        set App::comp_form($var) $widget
    }
    
    set btn_frame [ttk::frame $w.buttons]
    pack $btn_frame -fill x -pady 10
    
    ttk::button $btn_frame.add -text "Add" -command {
        # In production, add to component list
        tk_messageBox -info "Added" "Component added to formulation"
        destroy .add_comp
    }
    pack $btn_frame.add -side left -padx 10
    
    ttk::button $btn_frame.cancel -text "Cancel" -command {
        destroy .add_comp
    }
    pack $btn_frame.cancel -side right -padx 10
}

# ============================================
# 7. QUALITY CONTROL
# ============================================

proc App::show_qc_tests {} {
    variable notebook
    $notebook select $notebook.quality
    
    set frame $notebook.quality
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
    
    # Sample QC tests
    foreach test {
        "QC20260115-001" "BT20260115-0001" "pH Level" 6.9 6.5 7.5 "Passed" "2026-01-15"
        "QC20260115-002" "BT20260115-0001" "Viscosity" 95000 80000 120000 "Passed" "2026-01-15"
        "QC20260115-003" "BT20260115-0001" "Fluoride" 1010 950 1050 "Passed" "2026-01-15"
        "QC20260115-004" "BT20260115-0002" "pH Level" 7.8 6.5 7.5 "Failed" "2026-01-15"
        "QC20260114-001" "BT20260114-0003" "Density" 1.35 1.2 1.5 "Passed" "2026-01-14"
    } {
        $tree insert {} end -text [lindex $test 0] -values [lrange $test 1 end]
    }
    
    set App::tree_vars(qc_tests) $tree
}

proc App::show_qc_test_form {} {
    set w .qc_form
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "Record QC Test"
    wm geometry $w "500x400"
    
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
            $widget configure -values {"pH Level" "Viscosity" "Fluoride Content" "Density" "Microbial Count" "Appearance"}
        } elseif {$var eq "lab"} {
            set widget [ttk::combobox $f.cb -width 30]
            $widget configure -values {"R&D Lab" "QC Lab" "Stability Lab" "Micro Lab"}
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

# ============================================
# 8. REPORTING FUNCTIONS
# ============================================

proc App::report_batch_summary {} {
    variable notebook
    $notebook select $notebook.reports
    
    set frame $notebook.reports
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
    $param_frame.from_entry insert 0 "2026-01-01"
    
    ttk::label $param_frame.to -text "To:"
    pack $param_frame.to -side left -padx 5
    
    ttk::entry $param_frame.to_entry -width 15
    pack $param_frame.to_entry -side left
    $param_frame.to_entry insert 0 "2026-01-31"
    
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
    
    # Sample report
    $text insert end "= TOOTHPASTE PRODUCTION BATCH SUMMARY REPORT =\n"
    $text insert end "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]\n"
    $text insert end "Period: 2026-01-01 to 2026-01-31\n"
    $text insert end "-" * 60 "\n\n"
    
    $text insert end "Summary Statistics:\n"
    $text insert end "------------------\n"
    $text insert end "Total Batches      : 45\n"
    $text insert end "Total Production   : 95,500 kg\n"
    $text insert end "Average Yield      : 97.8%\n"
    $text insert end "QC Pass Rate       : 93.3%\n"
    $text insert end "Rejected Batches   : 3\n\n"
    
    $text insert end "Batch Details:\n"
    $text insert end "-------------\n"
    $text insert end "| Batch Number | Formulation      | Quantity (kg) | Yield % | Status     |\n"
    $text insert end "|--------------|------------------|---------------|---------|------------|\n"
    $text insert end "| BT20260115-001 | Cavity Protection | 2,500        | 98.5    | Released   |\n"
    $text insert end "| BT20260115-002 | Total Advanced   | 3,000        | 97.2    | QC Testing |\n"
    $text insert end "| BT20260114-003 | Pro-Health       | 2,000        | 96.8    | Released   |\n"
    $text insert end "| BT20260114-004 | 3D White        | 1,500        | 95.0    | Completed  |\n"
    
    $text configure -state disabled
    set App::report_text $text
}

# ============================================
# 9. UTILITY FUNCTIONS
# ============================================

# Clear content from a frame
proc App::clear_content {frame} {
    foreach child [winfo children $frame] {
        destroy $child
    }
}

# Navigation handler
proc App::navigate {tree} {
    set selection [$tree selection]
    if {$selection eq ""} return
    
    set item [$tree item $selection]
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
        }
    }
}

# Load initial data
proc App::load_initial_data {} {
    set_status "Loading data..."
    # In production, load from database
    set_status "Data loaded" green
}

# Refresh current view
proc App::refresh_current {} {
    set_status "Refreshing..."
    after 500 {set_status "Refreshed" green}
}

# Search function
proc App::search {} {
    set search_text [.toolbar.search get]
    if {$search_text ne ""} {
        set_status "Searching for '$search_text'..."
        # In production, perform search
        tk_messageBox -info -title "Search Results" \
            -message "Search for '$search_text' completed.\nFound 5 matching records."
    }
}

# Export report
proc App::export_report {} {
    set file [tk_getSaveFile -title "Export Report" -defaultextension .csv -filetypes {{"CSV Files" *.csv} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting to $file..."
        tk_messageBox -info -title "Export" "Report exported to $file"
        set_status "Export completed" green
    }
}

# Export PDF
proc App::export_pdf {} {
    set file [tk_getSaveFile -title "Export PDF" -defaultextension .pdf -filetypes {{"PDF Files" *.pdf} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Exporting PDF to $file..."
        tk_messageBox -info -title "Export" "PDF exported to $file"
        set_status "PDF export completed" green
    }
}

# Import data
proc App::import_data {} {
    set file [tk_getOpenFile -title "Import Data" -filetypes {{"CSV Files" *.csv} {"Excel Files" *.xlsx} {"All Files" *}}]
    if {$file ne ""} {
        set_status "Importing data from $file..."
        # In production, process import
        tk_messageBox -info -title "Import" "Data imported from $file"
        set_status "Import completed" green
    }
}

# Show about dialog
proc App::show_about {} {
    tk_messageBox -info -title "About" \
        -message "Toothpaste Production Manager v2.0\n\nA comprehensive Tcl/Tk GUI for managing toothpaste production processes.\n\nDatabase: PostgreSQL\nLanguage: Tcl/Tk\n\n© 2026 Production Management Systems"
}

# Show help
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

# Show settings
proc App::show_settings {} {
    tk_messageBox -info -title "Settings" \
        -message "Application settings dialog would open here.\n\nConfigure:\n- Database connections\n- UI preferences\n- Notification settings\n- Report templates"
}

# Show system log
proc App::show_log {} {
    set w .log
    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w "System Log"
    wm geometry $w "700x400"
    
    set text [text $w.text -wrap none -font {Courier 9} -yscrollcommand "$w.scroll set"]
    pack $text -side left -fill both -expand true
    
    set scrollbar [ttk::scrollbar $w.scroll -orient vertical -command "$text yview"]
    pack $scrollbar -side right -fill y
    
    # Sample log entries
    set log_entries {
        "[2026-01-15 15:30:45] INFO: User logged in"
        "[2026-01-15 15:31:12] INFO: Database connection established"
        "[2026-01-15 15:32:05] INFO: Created new batch BT20260115-0001"
        "[2026-01-15 15:35:20] INFO: QC Test recorded - Passed"
        "[2026-01-15 15:40:15] WARNING: Batch BT20260115-0002 - pH deviation detected"
        "[2026-01-15 15:45:00] INFO: Batch BT20260115-0001 - Completed"
        "[2026-01-15 15:50:30] INFO: Report generated - Batch Summary"
        "[2026-01-15 15:55:45] INFO: User logged out"
    }
    
    foreach entry $log_entries {
        $text insert end "$entry\n"
    }
    
    $text configure -state disabled
}

# Show stability studies
proc App::show_stability {} {
    # Placeholder - would show stability studies
    tk_messageBox -info -title "Stability Studies" \
        -message "Stability studies management would appear here.\n\nFeatures:\n- View ongoing stability studies\n- Record test results\n- Monitor expiration dates\n- Generate stability reports"
}

# Show compound library
proc App::show_compound_library {} {
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
    
    # Sample compounds
    foreach comp {
        "Sodium Fluoride" "NaF" "7681-49-4" "Fluoride" "Solid" 2.558 7.0
        "Glycerin" "C3H8O3" "56-81-5" "Humectant" "Liquid" 1.261 7.0
        "Sorbitol" "C6H14O6" "50-70-4" "Humectant" "Liquid" 1.489 7.0
        "Hydrated Silica" "SiO2·nH2O" "7631-86-9" "Abrasive" "Solid" 2.0 7.0
        "SLS" "C12H25NaO4S" "151-21-3" "Surfactant" "Solid" 1.01 7.0
        "Peppermint Oil" "-" "8006-90-4" "Flavor" "Liquid" 0.9 7.0
        "Sodium Benzoate" "C7H5NaO2" "532-32-1" "Preservative" "Solid" 1.44 7.5
    } {
        $tree insert {} end -text [lindex $comp 0] -values [lrange $comp 1 end]
    }
}

# Show suppliers
proc App::show_suppliers {} {
    tk_messageBox -info -title "Supplier Management" \
        -message "Supplier management interface would appear here.\n\nManage:\n- Chemical suppliers\n- Supplier contracts\n- Material pricing\n- Quality ratings"
}

# Show lab equipment
proc App::show_equipment {} {
    tk_messageBox -info -title "Lab Equipment" \
        -message "Laboratory equipment management would appear here.\n\nTrack:\n- Equipment inventory\n- Calibration schedules\n- Maintenance records\n- Equipment status"
}

# Show QC parameters
proc App::show_qc_parameters {} {
    tk_messageBox -info -title "QC Parameters" \
        -message "Quality control parameters configuration.\n\nDefine:\n- Test parameters\n- Specifications\n- Acceptance criteria\n- Sampling frequency"
}

# Show schedule
proc App::show_schedule {} {
    tk_messageBox -info -title "Production Schedule" \
        -message "Production scheduling calendar would appear here.\n\nPlan:\n- Weekly production runs\n- Resource allocation\n- Equipment scheduling\n- Staff assignments"
}

# Show component search
proc App::show_component_search {} {
    tk_messageBox -info -title "Component Search" \
        -message "Search chemical components by:\n\n- Name\n- CAS Number\n- Function\n- Type\n- Supplier"
}

# Report inventory
proc App::report_inventory {} {
    tk_messageBox -info -title "Inventory Report" \
        -message "Inventory status report would appear here.\n\nShow:\n- Raw material levels\n- Finished products\n- Low stock alerts\n- Expiry tracking"
}

# Report yield analysis
proc App::report_yield_analysis {} {
    tk_messageBox -info -title "Yield Analysis" \
        -message "Production yield analysis report.\n\nAnalyze:\n- Batch yields by formulation\n- Efficiency trends\n- Loss points\n- Improvement opportunities"
}

# Report QC dashboard
proc App::report_qc_dashboard {} {
    tk_messageBox -info -title "QC Dashboard" \
        -message "Quality control dashboard.\n\nMonitor:\n- Test results\n- Pass/fail rates\n- Trending analysis\n- Batch quality status"
}

# Generate batch summary
proc App::generate_batch_summary {} {
    set_status "Generating batch summary report..."
    after 1000 {set_status "Report generated" green}
    tk_messageBox -info -title "Report" "Batch summary report generated successfully!"
}

# Edit formulation
proc App::edit_formulation {} {
    variable tree_vars
    if {[info exists tree_vars(formulations)]} {
        set tree $tree_vars(formulations)
        set selection [$tree selection]
        if {$selection ne ""} {
            set code [$tree item $selection -text]
            tk_messageBox -info -title "Edit Formulation" \
                -message "Editing formulation: $code\n\nThe full editing interface would open here."
        } else {
            tk_messageBox -warning -title "Selection" "Please select a formulation to edit."
        }
    }
}

# View formulation components
proc App::view_formulation_components {} {
    variable tree_vars
    if {[info exists tree_vars(formulations)]} {
        set tree $tree_vars(formulations)
        set selection [$tree selection]
        if {$selection ne ""} {
            set code [$tree item $selection -text]
            tk_messageBox -info -title "View Components" \
                -message "Showing components for formulation: $code\n\nAll formulation components with percentages would be displayed."
        } else {
            tk_messageBox -warning -title "Selection" "Please select a formulation to view components."
        }
    }
}

# Load batches
proc App::load_batches {} {
    set_status "Loading batches..."
    after 500 {set_status "Batches loaded" green}
}

# Load QC tests
proc App::load_qc_tests {} {
    set_status "Loading QC tests..."
    after 500 {set_status "QC tests loaded" green}
}

# Save formulation
proc App::save_formulation {} {
    variable form_form
    
    set code [$form_form(code) get]
    set name [$form_form(name) get]
    
    if {$code eq "" || $name eq ""} {
        tk_messageBox -warning -title "Validation" \
            -message "Please fill in required fields (Code and Name)."
        return
    }
    
    set_status "Saving formulation..."
    after 500 {set_status "Formulation saved" green}
    tk_messageBox -info -title "Success" "Formulation saved successfully!"
    destroy .formulation_form
}

# Save QC test
proc App::save_qc_test {} {
    variable qc_form
    
    set batch [$qc_form(batch) get]
    set parameter [$qc_form(parameter) get]
    set result [$qc_form(result) get]
    
    if {$batch eq "" || $parameter eq "" || $result eq ""} {
        tk_messageBox -warning -title "Validation" \
            -message "Please fill in all required fields."
        return
    }
    
    set_status "Recording QC test..."
    after 500 {set_status "QC test recorded" green}
    tk_messageBox -info -title "Success" "QC test recorded successfully!"
    destroy .qc_form
}

# Exit application
proc App::exit_app {} {
    if {[tk_messageBox -icon question -type yesno -title "Exit" \
            -message "Are you sure you want to exit?"] eq "yes"} {
        DB::disconnect
        destroy .
    }
}

# ============================================
# 10. START THE APPLICATION
# ============================================

# Handle window close
wm protocol . WM_DELETE_WINDOW App::exit_app

# Initialize the application
App::init

# Enter the Tk event loop
vwait forever