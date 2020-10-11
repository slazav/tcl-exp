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
##   -func_mkint   make interface function (argument: widget path)
##   -show_ctl     show control panel, buttons and period setting (default: 1)
##   -show_title   show title panel (default: 1)
##   -verb         verbosity level (0: show only errors in the status line,
##                 1(default): show status messages (Measure, Waiting, etc.)

## All func_* functions can throw errors, return values are ignored
## 

itcl::class Monitor {

  variable onoff;          # on/off switch
  variable is_opened 0;    # are devices opened
  variable exit_fl 0;      # set to 1 to exit the program
  variable loop_handle {}; # non-empty only while waiting for next measurement
  variable root {};        # tk root widget
  # default function handlers
  variable func_start;
  variable func_stop;
  variable func_meas;
  variable func_mkint;
  # status widget
  variable status_w;

  #########################
  ## Configuration parameters. Defaults are set in the constructor
  variable name;       # program name
  variable period;     # period setting (sec)
  variable dt;         # actual value (ms)
  variable verb;       # verbosity level (0,1,...)

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
      -func_mkint    func_mkint   {}\
      -show_ctl      show_ctl   1\
      -show_title    show_title 1\
      -verb          verb       1\
    ]
    xblt::parse_options "monitor" $args $options

    # return if we do not need interface
    set root $tkroot
    if {$root == {}} return

    ######
    ## interface
    # title frame
    frame $root

    # title frame
    if {$show_title} {
      frame $root.n
      label $root.n.name -text "$name" -font {-size 14}
      pack $root.n.name -side left -padx 10
    }

    # user frame
    if {$func_mkint != {}} {
      frame $root.u
      $func_mkint $root.u
    }

    # control frame
    if {$show_ctl} {
      frame $root.ctl
      button $root.ctl.restart -text "(re)start"\
        -pady 0 -padx 2 -bd 1 -relief raised\
        -command "$this restart"
      button $root.ctl.single -text "single"\
        -pady 0 -padx 2 -bd 1 -relief raised\
        -command "$this single"
      button $root.ctl.stop -text "stop"\
        -pady 0 -padx 2 -bd 1 -relief raised\
        -command "$this stop"
      label       $root.ctl.per_l -padx 10 -text "period (sec):"
      entry       $root.ctl.per_v -width 6 -textvariable [itcl::scope period]\
                  -vcmd "$this validate_period %W %s %P" -validate {key}
      pack $root.ctl.restart $root.ctl.single $root.ctl.stop -side left -padx 3
      pack $root.ctl.per_v $root.ctl.per_l -side right
    }

    ## status bar on the bottom
    set status_w [StatusBar #auto $root.st]

    if {$show_title}       {grid $root.n   -sticky we}
    if {$func_mkint != {}} {grid $root.u   -sticky wens}
    if {$show_ctl}         {grid $root.ctl -sticky we}
    grid $root.st  -sticky we
    grid rowconfigure $root 1 -weight 1
    grid columnconfigure $root 0 -weight 1

    onoff_btn $onoff
    main_loop
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
    if {$root == {}} return
    $status_w set_status $msg $col
  }

  ##########################
  ## run a command, catch error
  ## return 1 (success) or 0 (fail)
  method run_cmd {cmd} {
    if {$cmd == {}} return {}
    if {![catch {set ret [$cmd]}]} {
      # Note that non-zero ::errorInfo can come
      # from some catched errors inside $cmd
      set ::errorInfo {}
      return $ret
    }
  }

  ##########################
  method main_loop {} {
    set loop_handle {}
    # Open devices if needed, return on failure
    if {$onoff && !$is_opened} {
      set is_opened 1
      if {$verb>0} {set_status "Starting the measurement, opening devices..."}
      set ::errorInfo {}
      run_cmd $func_start
      if {$::errorInfo != {}} {
        set is_opened 0
        onoff_btn 0
        set_status "Error while starting: $::errorInfo" red
        return
      }
    }

    # Close devices if needed
    if {(!$onoff || $exit_fl) && $is_opened} {
      # stop do not modify status to keep previous message if any
      set ::errorInfo {}
      run_cmd $func_stop
      if {$::errorInfo != {}} {
        set_status "Error while stopping: $::errorInfo" red
      }
      set is_opened 0
    }
    if {$exit_fl} {exit}
    if {!$onoff} {return}

    # Do the measurement
    if {$verb>0} {set_status "Measuring..."}
    set ::errorInfo {}
    run_cmd $func_meas

    # Set up the next iteration
    if {[regexp {^[0-9.]+$} $period]} {
      set dt [expr {int($period*1000)}]
    } else {
      set period [expr {$dt/1000.}]
    }
    if {$::errorInfo == {}} {
      if {$verb>0} {set_status "Waiting for the next measurement ([expr $dt/1000.0] s)..."}
    } else {
      set_status "Error: $::errorInfo" red
    }
    set loop_handle [after $dt $this main_loop]
  }

  #########################
  ## Do start and stop (useful if in the beginning we want to
  ## open devices and collect some information)
  method startstop {} {
    if {$is_opened} {return}
    set is_opened 1
    if {$verb>0} {set_status "Checking devices..."}
    run_cmd $func_start
    if {$::errorInfo != {}} {
      set is_opened 0
      set_status "Error while starting: $::errorInfo" red
      return
    }
    # stop do not modify status to keep previous message if any
    run_cmd $func_stop
    if {$::errorInfo != {}} {
      set is_opened 0
      set_status "Error while stopping: $::errorInfo" red
      return
    }
    set_status {}
    set is_opened 0
  }

  #########################
  ## Low-level method for switching on/off button.
  ## If you want to switch the measurements
  ## use restart/stop/single methods
  method onoff_btn {v} {
    set onoff $v
    if {$root == {}} return
    if {$onoff} { $status_w set_img triangle_right green
    } else {      $status_w set_img square red }
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
    if {$::errorInfo == {}} {set_status {}}
    if {!$is_opened} { return }
    if {$loop_handle != {}} {
      after cancel $loop_handle;
      $this main_loop
    }
  }

  #########################
  ## Run a single measurement:
  method single {} {
    restart
    stop
  }

  #########################
  ## close devices and exit
  method do_exit {} {
    if {!$is_opened} {exit}
    set exit_fl 1
    stop
  }

}
