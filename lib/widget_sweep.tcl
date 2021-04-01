# Interface for a sweeper.
#
# The interface holds sweep parameters (vmin, vmax, nstep)
# On each step (do_step command) a new value is calculated.
#
# Constructor: widget_sweep <name> <tkroot> <options>
# Options:
#   -title -- frame title.
#   -vmin -vmax -npts -dt -dtf -mode   -- initial values for interface entries.
#   -limit_min -limit_max   -- min/max limit for the parameter.
#   -vmin_label -vmax_label -- interface labels for min/max values
#   -mode -- sweep mode ("Up" "Down" "Both", "Pair")
#   -on   -- initial state, 1|0, default 1
#   -idle_delay -- delay in OFF mode
#   -bar_w -bar_h -- dimensions of the progress bar. Defaultt 256,10. Set to 0 to hide the bar.
#   -color        -- configure interface color
#
# Methods:
#   restart {}    -- cancel current sweep, start new one
#   stop {}       -- cancel current sweep, stop
#
#   do_step {}    -- do a step
#   get_val {}    -- get sweeping parameter value
#   get_delay {}  -- get delay until the next step [s]
#
#   is_first {}   -- is it the first point of a sweep? (should be called after do_step)
#   is_last {}    -- is it the last point of a normal sweep? (should be called after do_step)
#   is_cancelled {} -- is it the last point of cancelled sweep? (should be called after do_step)
#   is_on {}      -- is sweep in progress
#
#   get_vmin {}
#   set_vmin {v}
#   get_vmax {}
#   set_vmax {v}
#   get_dt   {}
#   set_dt   {v}
#   get_dtf  {}
#   set_dtf  {v}
#   get_mode {}
#   set_mode {v}  -- sweep mode: "Up" "Down" "Both", "Pair"
#   get_dir  {}   -- sweep direction
#
# For usage example see widget_sweep_test or fork_cw program
#
# [do_step]
# if [is_cancelled] continue
# if [is_on] <prepare the measurement>
# if [is_first] <prepare storage for data>
# if [is_last]  <save collected data>
# [get_delay], wait
# if [is_on] <do measurement, collect data>

package require xBlt
package require itcl


##########################################################
itcl::class widget_sweep {
  variable root     {}; # root widget path

  # values used in calculations
  variable vmin  0
  variable vmax  10
  variable npts  11
  variable dt    1
  variable dtf   1
  variable dt0   1
  variable t1    0

  variable cnt  0; # point counter
  variable scnt 0; # sweep counter (reset by mode change or reset button)
  variable v0  0; # start of the current sweep
  variable dv 0;  # step
  variable  v 0;  # current value
  variable dir   1
  variable restart_fl 0; # set by "restart" method/button
  variable stop_fl 0;    # set by "stop" method/button
  variable finished 0;

  # interface values
  variable vmin_i  0
  variable vmax_i  10
  variable npts_i  11
  variable dt_i    1
  variable dtf_i   1
  variable mode_i "OFF"
  variable lim_min
  variable lim_max
  variable bar_w
  variable bar_h

  variable on

  # Constructor: parse options, build interface
  constructor {tkroot args} {

    # Parse options.
    set options [list \
      {-t -title}    title     {}\
      {-vmin}        vmin_i      0\
      {-vmax}        vmax_i      10\
      {-vmin_label}  vmin_label {V1}\
      {-vmax_label}  vmax_label {V2}\
      {-npts}        npts_i      11\
      {-dt}          dt_i        1\
      {-dtf}         dtf_i       1\
      {-mode}        mode_i    "Both"\
      {-on}          on        1\
      {-limit_max}   lim_max   +inf\
      {-limit_min}   lim_min   -inf\
      {-idle_delay}  dt0       1\
      {-bar_w}       bar_w     256\
      {-bar_h}       bar_h     10\
      {-color}       color     {}\
    ]
    xblt::parse_options "widget_sweep" $args $options

    # Main frame:
    set root $tkroot
    labelframe $root -text $title -font {-weight bold -size 10}

    # Progress bar
    if {$bar_w>0 && $bar_h>0} {
      canvas $root.bar -width $bar_w -height $bar_h
      $root.bar create rectangle 1 1 $bar_w $bar_h -fill white -outline grey
      grid $root.bar -padx 5 -pady 2 -sticky e -columnspan 4
    }

    label $root.vmin_l -text $vmin_label
    entry $root.vmin -width 12 -textvariable [itcl::scope vmin_i]
    label $root.vmax_l -text $vmax_label
    entry $root.vmax -width 12 -textvariable [itcl::scope vmax_i]
    grid $root.vmin_l $root.vmin $root.vmax_l $root.vmax\
      -padx 5 -pady 2 -sticky e

    label $root.npts_l -text "N"
    entry $root.npts -width 12 -textvariable [itcl::scope npts_i]
    label $root.dt_l -text "dt"
    entry $root.dt -width 12 -textvariable [itcl::scope dt_i]
    grid $root.npts_l $root.npts $root.dt_l $root.dt\
      -padx 5 -pady 2 -sticky e

    label $root.dtf_l -text "first point delay:"
    entry $root.dtf -width 12 -textvariable [itcl::scope dtf_i]
    grid $root.dtf_l $root.dtf -columnspan 3 -padx 5 -pady 2 -sticky e

    frame $root.btns
    button $root.btns.rbtn -text "(Re)start" -command "$this restart"
    button $root.btns.sbtn -text "Stop"    -command "$this stop"

    # mode combobox
    ttk::combobox $root.btns.mode -width 9 -textvariable [itcl::scope mode_i] -state readonly
    bind $root.btns.mode <<ComboboxSelected>> "set [itcl::scope scnt] 0"
    $root.btns.mode  configure -values {"Up" "Down" "Both" "Pair"}

    pack $root.btns.rbtn $root.btns.sbtn $root.btns.mode -side left -anchor e -fill x -expand 1
    grid $root.btns -columnspan 4 -sticky ew

    if {$color ne {}} {widget_bg $root $color}
    set v0 $vmin_i
  }

  method update_bar {} {
    if {$bar_w>0} {
      $root.bar delete data
      set x [expr {($v-$vmin)/($vmax-$vmin)}]
      if {$x<0 || $x>1} return
      set x1 [expr {$bar_w*$x - $bar_h/2}]
      set x2 [expr {$bar_w*$x + $bar_h/2}]
      set y1 [expr {$bar_h/2}]
      if {!$on} {
        $root.bar create oval $x1 1 $x2 $bar_h -fill red -outline black -tags data
      }\
      else {
        if {$dir>0} {
          $root.bar create polygon $x1 1 $x2 $y1 $x1 $bar_h -fill green -outline black -tags data
        } else {
          $root.bar create polygon $x2 1 $x1 $y1 $x2 $bar_h $x2 1 -fill green -outline black -tags data
        }
      }
    }
  }


  # restart sweep
  method restart {} { set restart_fl 1 }

  # stop sweep
  method stop {} { set stop_fl 1 }

  method do_step {} {

    # reset finished flag
    set finished 0

    # if restart flag is set abort the sweep
    if {$restart_fl} {
      set on 1
      set cnt 0
      set scnt 0
      set restart_fl 0
      return
    }

    # same for stop
    if {$stop_fl} {
      set on 0
      set cnt 0
      set scnt 0
      set stop_fl 0
      return
    }

    # start new sweep
    if {$cnt == 0 && $on} {
      incr scnt
      # set direction
      switch $mode_i {
        "Up"   {set dir +1}
        "Down" {set dir -1}
        "Both" {set dir [expr {$dir<0?  +1:-1}]}
        "Pair" {set dir [expr {$scnt%2? +1:-1}]}
        default {error "unknown sweep mode: $mode_i"}
      }
      # copy values from the interface
      if {![string is integer $npts_i] || $npts_i < 2} {set npts_i $npts}
      if {![string is double $dt_i]  || $dt_i <= 0} {set dt_i $dt}
      if {![string is double $dtf_i] || $dtf_i <= 0} {set dtf_i $dtf}
      if {![string is double $vmin_i]} {set vmin_i $vmin}
      if {![string is double $vmax_i]} {set vmax_i $vmax}
      if {$vmin_i < $lim_min} {set vmin_i $lim_min}
      if {$vmin_i > $lim_max} {set vmin_i $lim_max}
      if {$vmax_i < $lim_min} {set vmax_i $lim_min}
      if {$vmax_i > $lim_max} {set vmax_i $lim_max}
      if {![string is double $vmax_i]} {set vmax_i $vmax}

      set vmin $vmin_i
      set vmax $vmax_i
      set npts $npts_i
      set dt   $dt_i
      set dtf  $dtf_i

      # set starting value and step
      if {$dir>0} {set v0 [expr min($vmin,$vmax)]}
      if {$dir<0} {set v0 [expr max($vmin,$vmax)]}
      set dv [expr {abs($vmax-$vmin)/($npts-1.0)}]
    }

    # update value and picture on the bar

    if {$on} {
      set v [expr {$v0 + $dir*$dv*$cnt}]
      incr cnt
    }
    update_bar

    # finish sweep
    if {$cnt >= $npts} {
      set cnt 0
      set finished 1
      if {$mode_i eq "Pair" && $scnt>1} { set on 0 }
    }
    set t1 [expr [clock microseconds]/1e6]
  }

  # should be called after do_step
  method is_first {} { return [expr {$cnt == 1}] }
  method is_last {}    { return [expr {$cnt == 0 &&  $finished}] }
  method is_cancelled {} { return [expr {$cnt == 0 && !$finished}] }
  method is_on {}    { return $on }

  method get_val {} {return $v}

  method get_vmin {} {return $vmin_i}
  method get_vmax {} {return $vmax_i}
  method get_dt  { } {return $dt_i}
  method get_dtf  {} {return $dtf_i}
  method get_mode {} {return $mode_i}
  method get_dir  {} {return $dir}
  method set_vmin {v} {set vmin_i $v}
  method set_vmax {v} {set vmax_i $v}
  method set_dt   {v} {set dt_i $v}
  method set_dtf  {v} {set dtf_i $v}
  method set_mode {v} {set mode_i $v}

  method get_delay {} {
    if {$dir == 0} {return [expr $dt0]}
    set dt1 [expr [clock microseconds]/1e6 - $t1]
    set ret [expr {($cnt==1? $dtf:$dt) - $dt1}]
    if {$ret < 0} {return 0}
    return $ret
  }

}

