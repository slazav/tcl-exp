package require itcl
package require xBlt; # options

## Base class for a measurement interface
## Minimal GUI with on/off button, status line,
## single/regular measurements
##
## Usage:
##   Monitor <name> <widget path> <options>
## Options:
##   -name         program name
##   -period       measurement period
##   -onoff        initial state of main switch
##   -func_start   start function
##   -func_stop    stop function
##   -func_meas    measure function
##   -func_mkint   make interface function (argumentL: widget path)
## All func_* functions can throw errors, return values are ignored
## 

itcl::class Monitor {

  variable status_text {}; # full text in the status line
  variable onoff;          # on/off switch
  variable is_opened 0;    # are devices opened
  variable exit_fl 0;      # set to 1 to exit the program
  variable loop_handle {}; # non-empty only while waiting for next measurement
  variable root;           # tk root widget
  # default function handlers
  variable func_start;
  variable func_stop;
  variable func_meas;
  variable func_mkint;

  #########################
  ## Configuration parameters. Defaults are set in the constructor
  variable name;       # program name
  variable period;     # period setting (sec)
  variable dt;         # actual value (ms)

  #########################
  ## User-supplied functions.
  ## Default version implements a simple measurement
  ## with a DeviceRole gauge device.

  # Open devices (user-supplied function)
  # Can throw an error.
  method def_func_start {} { puts "Start" }

  # Close devices (user-supplied function)
  # Can throw an error.
  method def_func_stop {} { puts "Stop" }

  # Do a single measurement, return data (user-supplied function)
  # Can throw an error.
  method def_func_meas {} { puts "Measure" }

  # Build GUI frame in <wid> (user-supplied function)
  method def_func_mkint {wid} { }

  #########################
  ## Constructor/Destructor
  constructor {tkroot args} {
    # parse options
    set options [list \
      -name          name         {Default}\
      -period        period       {1.0}\
      -onoff         onoff        0\
      -func_start    func_start   def_func_start\
      -func_stop     func_stop    def_func_stop\
      -func_meas     func_meas    def_func_meas\
      -func_mkint    func_mkint   def_func_mkint\
    ]
    xblt::parse_options "monitor" $args $options
    apply_period

    ######
    ## interface
    # title frame
    set root $tkroot
    frame $root
    frame $root.n
    label $root.n.name -text "$name" -font {-size 14}
    pack $root.n.name -side left -padx 10
    pack $root.n -anchor w -expand 0 -side top

    # user frame
    frame $root.u
    $func_mkint $root.u
    pack $root.u -expand 1 -fill both -anchor w

    # control frame
    frame $root.ctl
    checkbutton $root.ctl.meas -text "run" -selectcolor "red"\
      -bd 1 -relief raised -width 6\
      -variable [itcl::scope onoff] -command "$this on_onoff"
    button $root.ctl.single -text "single"\
      -pady 0 -padx 2 -bd 1 -relief raised -width 6\
                -command "$this measure"
    label       $root.ctl.per_l -padx 10 -text "period (sec):"
    entry       $root.ctl.per_v -width 6 -textvariable [itcl::scope period]\
                -vcmd "$this validate_period %W %s %P" -validate {key}
    bind $root.ctl.per_v <Return> "$this apply_period"

    pack $root.ctl.meas $root.ctl.single -side left -padx 3
    pack $root.ctl.per_v $root.ctl.per_l -side right
    pack $root.ctl -anchor s -expand 0 -fill x -padx 0

    ## status line on the bottom
    frame $root.st -borderwidth 1 -relief sunken
    label $root.st.text -height 1 
    bind $root.st.text <ButtonPress> "$this show_status"
    grid $root.st.text

    pack $root.st  -anchor s -expand 1 -fill x
  }

  # validate function for the period field
  method validate_period { W old new} {
    if {[regexp {^[0-9.]*$} $new]} { return 1 }
    set $period $old
    return 0
  }

  ##########################
  ## set status line and update interface
  method set_status {msg {col black}} {
    set L $root.st.text; # the label widget
    set status_text $msg
    # We want to cut one line of the text
    set n [string first "\n" $msg]
    if {$n>0} {
      $L configure -text [string range $msg 0 [expr $n-1]]
    } else {
      $L configure -text $msg
    }
    $L configure -fg $col
    update idletasks
  }

  ##########################
  # Dialog with full text of the status line
  # (called from a button)
  method show_status { } {
    toplevel .top; #Make the window
    #Put things in it
    text .top.txt 
    .top.txt insert end $status_text
    # An option to close the window.
    button .top.btn -text "Close" -command { destroy .top }
    #Pack everything
    pack .top.txt .top.btn
  }

  ##########################
  ## run a command, catch error
  ## return 1 (success) or 0 (fail)
  method run_cmd {cmd} {
    set ::errorInfo {}
    if {![catch {set ret [$cmd]}]} {return $ret}
  }

  ##########################
  method main_loop {} {
    set loop_handle {}
    # Open devices if needed, return on failure
    if {$onoff && !$is_opened} {
      set is_opened 1
      set_status "Starting the measurement, opening devices..."
      run_cmd $func_start
      if {$::errorInfo != {}} {
        set is_opened 0
        onoff_btn 0
        set_status "Error while starting: $::errorInfo" red
        return
      }
    }

    # Close devices and return if checkbox was switched
    if {!$onoff || $exit_fl} {
      # stop do not modify status to keep previous message if any
      run_cmd $func_stop
      if {$::errorInfo != {}} {
        set_status "Error while stopping: $::errorInfo" red
      }
      set is_opened 0
      if {$exit_fl} {exit}
      return
    }

    # Do the measurement
    set_status "Measuring..."
    run_cmd $func_meas

    if {$::errorInfo == {}} {
      set_status "Waiting for the next measurement ([expr $dt/1000.0] s)..."
    } else {
      set_status "Error: $::errorInfo" red
    }
    # Set up the next iteration
    set loop_handle [after $dt $this main_loop]
  }

  #########################
  ## Do start and stop (useful if in the beginning we want to
  ## open devices and collect some information)
  method startstop {} {
    if {$is_opened} {return}
    set is_opened 1
    set_status "Checking devices..."
    run_cmd $func_start
    if {$::errorInfo != {}} {
      set is_opened 0
      onoff_btn 0
      set_status "Error while starting: $::errorInfo" red
      return
    }
    # stop do not modify status to keep previous message if any
    run_cmd $func_stop
    if {$::errorInfo != {}} {
      set_status "Error while stopping: $::errorInfo" red
    }
    set is_opened 0
  }

  #########################
  method set_checkbox_color {cb} {
    set v [set [$cb cget -variable]]
    $cb configure -selectcolor [expr $v?"green":"red"]
#	    $cb configure -text [expr $v?"stop":"start"]
  }

  #########################
  ## Low-level method for switching on/off button.
  ## If you want to switch the measurements
  ## use restart/stop/measure methods
  method onoff_btn {v} {
    set onoff $v
    set_checkbox_color $root.ctl.meas
    $root.ctl.meas configure -text [expr $v?"stop":"start"]
  }

  #########################
  ## method run when on/off button is pressed
  method on_onoff {} {
    onoff_btn $onoff
    # Run measurement loop if button was pressed and
    # measurement is not running (remember that user can press the button
    # faster then period setting)
    if {$onoff && !$is_opened} { main_loop }
    # If measurement is switched off and we are waiting for
    # next measurement, then interrupt the waiting and
    # restart main_loop to close devices
    if {!$onoff && $is_opened && $loop_handle != {}} {
      after cancel $loop_handle; $this main_loop }
  }

  #########################
  ## Restart the measurement
  method restart {} {
    # if measurement is running do nothing
    if {$onoff && $loop_handle == {}} { return }

    # If we are waiting for a next measurement interrupt the waiting
    if {$loop_handle != {}} { after cancel $loop_handle; }

    # Start measurement:
    onoff_btn 1
    main_loop
  }

  #########################
  ## Stop the measurement
  method stop {} {
    onoff_btn 0
    if {!$is_opened} {return}
    if {$loop_handle != {}} {
      after cancel $loop_handle; $this main_loop
    }
  }

  #########################
  ## close devices and exit
  method do_exit {} {
    if {!$is_opened} {exit}
    set exit_fl 1
    stop
  }

  #########################
  ## Run a single measurement:
  method measure {} {
    restart
    stop
  }


  #########################
  # This one is called when one changes period setting
  method apply_period {args} {
    if {[regexp {^[0-9.]+$} $period]} {
      set dt [expr {int($period*1000)}]
    } else {
      set period [expr {$dt/1000.}]
    }
    # if measurement is not running do nothing
    if {!$onoff} return
    restart
  }

}
