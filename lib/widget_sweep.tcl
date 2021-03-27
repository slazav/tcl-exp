# Interface for a sweeper.
#
# The interface holds sweep parameters (vmin, vmax, nstep)
# On each step (do_step command) a new value is calculated.
#
# Constructor: widget_sweep <name> <tkroot> <options>
# Options:
#   -title -- frame title.
#   -vmin -vmax -npts -dt -mode   -- initial values for interface entries.
#   -limit_min -limit_max   -- min/max limit for the parameter.
#   -vmin_label -vmax_label -- interface labels for min/max values
#   -mode -- sweep mode ("OFF" "Up" "Down" "Both", "Pair")
#   -idle_delay -- delay in OFF mode
#   -bar_w -bar_h -- dimensions of the progress bar. Defaultt 256,10. Set to 0 to hide the bar.
#
# Methods:
#   readonly 0|1  -- activate/deactivate widget (default - active)
#   restart {}    -- start new sweep
#   do_step {}    -- do a step
#   get_val {}    -- get sweeping parameter value
#   is_first {}   -- is it the first point of a sweep? (should be called after do_step)
#   is_last {}    -- is it the last point of a normal sweep? (should be called after do_step)
#   is_restart {} -- is it the last point of restarted sweep? (should be called after do_step)
#   is_on {}      -- is sweep in progress
#   get_del {}    -- get delay until the measurement [s]
#
#   get_vmin, set_vmin, get_vmax, set_vmax -- get/set parameters
#
# For usage example see widget_sweep_test program

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
  variable dt0   1
  variable t1    0

  variable cnt  0; # point counter
  variable scnt 0; # sweep counter (reset by mode change or reset button)
  variable v0  0; # start of the current sweep
  variable dv 0;  # step
  variable  v 0;  # current value
  variable dir   1
  variable restart_fl 0

  # interface values
  variable vmin_i  0
  variable vmax_i  10
  variable npts_i  11
  variable dt_i    1
  variable mode_i "OFF"
  variable lim_min
  variable lim_max
  variable bar_w
  variable bar_h

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
      {-mode}        mode_i    "OFF"\
      {-limit_max}   lim_max   +inf\
      {-limit_min}   lim_min   -inf\
      {-idle_delay}  dt0       1\
      {-bar_w}       bar_w     256\
      {-bar_h}       bar_h     10\
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

    # mode combobox
    ttk::combobox $root.mode -width 9 -textvariable [itcl::scope mode_i] -state readonly
    bind $root.mode <<ComboboxSelected>> "set [itcl::scope scnt] 0"
    $root.mode  configure -values {"OFF" "Up" "Down" "Both" "Pair"}

    # Apply/restart buttons
    button $root.rbtn -text "Restart" -command "$this restart"
    grid $root.rbtn $root.mode -padx 3 -pady 3 -columnspan 2

    widget_bg $root #E0F0E0
  }

  method update_bar {} {
    if {$bar_w>0} {
      $root.bar delete data
      if {$mode_i eq "OFF" && $cnt==0} return
      set x [expr {($v-$vmin)/($vmax-$vmin)}]
      if {$x<0 || $x>1} return
      set x1 [expr {$bar_w*$x - $bar_h/2}]
      set x2 [expr {$bar_w*$x + $bar_h/2}]
      #$root.bar create oval $x1 1 $x2 $bar_h -fill green -outline black -tags data
      $root.bar create polygon $x1 1 $x1 $bar_h $x2 $bar_h $x2 1 -fill green -outline black -tags data
    }
  }

  # activate/deactivate interface
  method readonly {{state 1}} {
    if {$state} { widget_state $root normal }\
    else { widget_state $root disabled }
  }

  # restart sweep
  method restart {} {
    set cnt 0
    set scnt 0
    set restart_fl 1
  }

  method do_step {} {
    # start new sweep
    if {$cnt == 0} {
      incr scnt

      # set direction
      switch $mode_i {
        "OFF"  {set dir 0}
        "Up"   {set dir +1}
        "Down" {set dir -1}
        "Both" {set dir [expr {$dir!=0? -$dir:1}]}
        "Pair" {set dir [expr {$scnt%2? +1:-1}]}
        default {error "unknown sweep mode: $mode_i"}
      }
      if {$dir != 0} {
        # copy values from the interface
        if {![string is integer $npts_i] || $npts_i < 2} {set npts_i $npts}
        if {![string is double $dt_i] || $dt_i <= 0} {set dt_i $dt}
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

        # set starting value and step
        if {$dir>0} {set v0 [expr min($vmin,$vmax)]}
        if {$dir<0} {set v0 [expr max($vmin,$vmax)]}
        set dv [expr {abs($vmax-$vmin)/($npts-1.0)}]
      }
    }

    set restart_fl 0
    set v [expr {$v0 + $dir*$dv*$cnt}]
    update_bar
    if {$dir != 0} {incr cnt}
    if {$cnt >= $npts} {
      set cnt 0
      if {$mode_i eq "Pair" && $scnt>1} { set mode_i "OFF" }
    }
    set t1 [expr [clock microseconds]/1e6]
  }

  # should be called after do_step
  method is_first {} { return [expr {$cnt == 1}] }
  method is_last {}    { return [expr {$cnt == 0 && $dir != 0 && !$restart_fl}] }
  method is_restart {} { return [expr {$cnt == 0 && $dir != 0 && $restart_fl}] }
  method is_on {}    { return [expr {$dir != 0}] }

  method get_val {} {return $v}

  method get_vmin {} {return $vmin_i}
  method get_vmax {} {return $vmax_i}
  method set_vmin {v} {set vmin_i $v}
  method set_vmax {v} {set vmax_i $v}

  method get_delay {} {
    if {$dir == 0} {return [expr $dt0]}
    set dt1 [expr [clock microseconds]/1e6 - $t1]
    if {$dt1 > $dt} {return 0}
    return [expr $dt-$dt1]
  }

}

