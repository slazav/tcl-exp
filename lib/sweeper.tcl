# current sweeper library

package require Device
package require DeviceRole 1.0
package require xBlt

#############################################################
## Arguments for constructor:
# -p -ps_dev1     -- power supply device
# -P -ps_dev2     -- power supply device - 2nd channel
# -A -antipar     -- anti-parallel connection
# -G -gauge       -- gauge device
# -d -db_dev      -- database device (can be empty)
# -n -db_val      -- database name for numerical values
# -a -db_ann      -- database name for annatations
# -v -max_volt    -- max voltage, V (default 1)
# -m -max_rate    -- max rate, A/S (default 1)
# -r -ramp_tstep  -- ramping time step, s (default 1)
# -i -idle_tstep  -- idle time step, s (default 10)
# -s -skip        -- do not write points if current was not set (0)
# -on_new_val     -- function prefix for running with new values ($t $cm $cs $vm $meas)
# -on_new_com     -- function prefix for running with new comment ($t $comm)
#
#  Other methods:

#  turn_on {}   -- open devices and start main loop
#  turn_off {}  -- stop main loop and close devices
#  get_mcurr {} -- get measured current (from the last loop step)
#  get_scurr {} -- get set current (from the last loop step)
#  get_colt {}  -- get measured voltage (from the last loop step)
#  get_stat {}  -- get device status
#  get_mval {}  -- get gauge data
#  reset {}     -- reset devices

#  set_limits     -- set sweep limits
#  get_limits     -- get sweep limits
#  go <rate> <dir> <wait>
#                 -- start sweeping with <rate> in direction <dir>,
#                    if <wait> then wait after sweep
#  go_back        -- change sweep direction
#  stop           -- stop ramping current and wait

#############################################################

itcl::class SweepController {
  variable dev1 {}; # device driver
  variable dev2 {}; # device driver -- 2nd chan
  variable gdev {}; # gauge device driver
  variable rh   {}; # ramping loop handler
  variable cs1 0;     # set current - 1st chan
  variable cs2 0;     # set current - 2nd chan
  variable cm1 0;     # measured current - 1st chan
  variable cm2 0;     # measured current - 2nd chan
  variable vm1 0;     # measured voltage - 1st chan
  variable vm2 0;     # measured voltage - 2nd chan
  variable st {};     # device state
  variable mval {};   # measured value
  variable tstep;   # current time step

  # see options:
  variable ps_dev1
  variable ps_dev2
  variable antipar
  variable g_dev
  variable db_dev
  variable db_val
  variable db_ann
  variable max_volt
  variable max_rate
  variable ramp_tstep
  variable idle_tstep
  variable skip
  variable on_new_val
  variable on_new_com

  # device parameters
  variable min_i_step  1;
  variable min_i_step2 1;
  variable min_i  0;
  variable min_i2 0;
  variable max_i  0;
  variable max_i2 0;

  # Main loop control parameters
  variable rate   0; # rate
  variable minlim 0; # sweep limits
  variable maxlim 0;
  variable dir    0; # sweep direction "+1/0/-1"
  variable t_set  0; # time of last current setting
  variable wait_at_dest 0; # should we stop at destination
  variable state 0; # off/on
  variable msg "";  # message to be logged into database on the next step
  variable changed 0; # set to 1 if current was changed
  variable in_the_loop 0;

  ######################################
  # constructor, set parameters
  constructor {args} {
    set options [list \
      {-p -ps_dev1}  ps_dev1  {}\
      {-P -ps_dev2}  ps_dev2  {}\
      {-A -antipar}  antipar  0\
      {-G -gauge}    g_dev    {}\
      {-d -db_dev}   db_dev   {}\
      {-n -db_val}   db_val   {}\
      {-a -db_ann}   db_ann   {}\
      {-v -max_volt} max_volt {1}\
      {-m -max_rate} max_rate {1}\
      {-r -ramp_tstep} ramp_tstep {1}\
      {-i -idle_tstep} idle_tstep {10}\
      {-s -skip}     skip     {0}\
      {-on_new_val}  on_new_val {}\
      {-on_new_com}  on_new_com {}\
    ]
    xblt::parse_options "sweeper" $args $options
  }
  destructor { turn_off }


  ######################################
  # open devices an start main loop
  method turn_on {} {
    if {$state == 1 } {return}

    # open first PS device get its parameters
    if {$ps_dev1  == {} } { error "ps_dev1 is empty" }
    set dev1 [DeviceRole $ps_dev1 power_supply]
#    $dev1 lock
    set min_i_step [$dev1 cget -min_i_step]
    set max_i [$dev1 cget -max_i]
    set min_i [$dev1 cget -min_i]

    # open secons PS device if needed
    if {$ps_dev2 != {}} {
      if {$ps_dev1 == $ps_dev2} {error "same device for both channels"}
      set dev2 [DeviceRole $ps_dev2 power_supply]
#      $dev2 lock
      set min_i_step2 [$dev2 cget -min_i_step]
      set max_i2 [$dev2 cget -max_i]
      set min_i2 [$dev2 cget -min_i]
      if {$antipar} {
        set max_i2 [expr {-[$dev2 cget -min_i]}]
        set min_i2 [expr {-[$dev2 cget -max_i]}]
      }
    }

puts stderr "O"

    # initial current limits
    set_limits [expr {$min_i+$min_i2}] [expr {$max_i+$max_i2}]

    # open gauge device if needed
    if {$g_dev != {}} {
      set gdev [DeviceRole $g_dev gauge]
    }

    # Open database if needed
    if {$db_dev != {} } { Device $db_dev }

    # reset the device and starm main loop
    set tstep $idle_tstep
    set state 1
    reset
  }

  ######################################
  method turn_off {} {
    set state 0
    loop_restart
  }


  ######################################
  ### internal DB functions

  # put comment into the database
  method put_comment {c} {
    set t [expr [clock milliseconds]/1000.0]
    if {$on_new_com != {}} { uplevel \#0 [eval {$on_new_com $t $c}]}
    if {$db_dev != {} && $db_ann != {} } {
      $db_dev cmd "put $db_ann $t $c"
      $db_dev cmd "sync"
    }
  }

  # put value into the database
  method put_value {} {
    set cm [expr {$cm1 + $cm2}]
    set cs [expr {$cs1 + $cs2}]
    set vm [expr {abs($vm1)>abs($vm2)? $vm1:$vm2}]
    set t [expr [clock milliseconds]/1000.0]
    if {$on_new_val != {}} { uplevel \#0 [eval {$on_new_val $t $cm $cs $vm $mval}]}
    if { $db_dev != {} && $db_val != {}} {
      $db_dev cmd "put $db_val $t $cm $cs $vm $mval"
      $db_dev cmd "sync"
    }
  }

  ######################################
  # restart loop if it runs
  method loop_restart {} {
    after cancel $rh
    set rh [after idle $this loop]
  }

  ######################################
  # Main loop

  method is_obj {o} { return [expr {$o!={} && [itcl::find objects $o]!={}}] }

  method loop {} {
    if {$in_the_loop} {return}
    set in_the_loop 1
    after cancel $rh
    set t0 [clock millisecond]

    # remove device and stop the loop
    if {$state == 0} {
      if {[is_obj $dev1]} { $dev1 unlock }
      if {[is_obj $dev2]} { $dev2 unlock }

      if {[is_obj $dev1]} {
        itcl::delete object $dev1
        set dev1 {}
      }

      if {[is_obj $dev2]} {
        itcl::delete object $dev2
        set dev2 {}
      }
      if {[is_obj $db_dev]} { itcl::delete object $db_dev }
      if {[is_obj $g_dev]}  { itcl::delete object $g_dev }
      set in_the_loop 0
      return
    }

    if {$dir != 0} { step }

    # measure all values
    set cm1 [ $dev1 get_curr ]
    if {$dev2 != {}} {
      set cm2 [$dev2 get_curr]
      if {$antipar} {set cm2 [expr -$cm2]}
    }\
    else {set cm2 0}

    set vm1 [ $dev1 get_volt ]
    if {$dev2 != {}} {
      set vm2 [$dev2 get_volt]
      if {$antipar} {set vm2 [expr -$vm2]}
    }\
    else {set vm2 0}

    set st [ $dev1 get_stat ]
    if {$dev2 != {}} { set st "$st:[ $dev2 get_stat ]" }

    # do measurement if needed
    if {$gdev != {}} { set mval [ $gdev get ] }\
    else { set mval {} }

    if {!$skip || $changed==1 || $msg != {}} { put_value }
    set changed 0

    if {$msg != {}} {
      put_comment $msg
      set msg {}
    }

    # stop ramping if the real current jumped outside the tolerance
    set tolerance  [expr 100*$min_i_step]
    set tolerance2 [expr 100*$min_i_step2]
    if { abs($cm1-$cs1) > $tolerance ||\
         abs($cm2-$cs2) > $tolerance2} {
      set cs1 $cm1
      set cs2 $cm2
      set rate 0
        put_comment "current jump to [expr $cs1+$cs2]"
    }

    if {$dir==0} {set tstep $idle_tstep}\
    else         {set tstep $ramp_tstep}

    set t1 [clock millisecond]
    set dt [expr {int($tstep*1000-($t1-$t0))}]
    if {$dt<0} {set dt 0}
    set in_the_loop 0
    set rh [after $dt "$this loop"]
  }


  # active step (dir!=0)
  method step {} {
    # limit rate and destinations
    if {$maxlim > $max_i + $max_i2} {set maxlim [expr {$max_i+$max_i2}]}
    if {$minlim < $min_i + $min_i2} {set minlim [expr {$min_i+$min_i2}]}
    if {$rate > $max_rate} {set rate $max_rate}

    # are we outside the limits?
    if {$cs1+$cs2 > $maxlim && $dir>0} {
       set dir -1
       set msg "sweep to [expr {$dir>0? $maxlim:$minlim}] A"
    }
    if {$cs1+$cs2 < $minlim && $dir<0} {
      set dir +1
      set msg "sweep to [expr {$dir>0? $maxlim:$minlim}] A"
    }

    # set current step we need
    set t_cur [clock millisecond]
    set dt [expr {$t_cur-$t_set}]
    set di [expr {$t_set==0? 0 : 1.0*$dir*$rate*$dt/1000.0}]
    if {$t_set==0} {set t_set $t_cur}
    # limit the current step
    if {abs($di) > $max_rate*$ramp_tstep} {
      set di [expr "$max_rate*$ramp_tstep*$dir"]
    }


    # Are we near the destination?
    if { ($dir>0 && abs([expr $cs1+$cs2]-$maxlim)<abs($di)) ||\
         ($dir<0 && abs([expr $cs1+$cs2]-$minlim)<abs($di))} {
      set c [expr $dir>0? $maxlim:$minlim]

      # do we want to do back?
      if {$wait_at_dest} {
        set dir 0
        set msg "sweep finished at $c A"
      }\
      else {
        set dir [expr -$dir]
        set msg "sweep to [expr {$dir>0? $maxlim:$minlim}] A"
      }
    }\
    else {
      set c [expr {[expr $cs1+$cs2] + $di}]
    }

    # Sweep method is different for parallel and for anti-parallel
    # power supply connection. First is used for accurate sweep with low-range
    # second device. We should always sweep ch2 first if it is possible.
    # In the anti-parallel connection we want to sweep first the device which
    # has opposite sign then the the destination.

    if {$antipar && $dest<0} {
      sweep_ch1 $c
      sweep_ch2 $c
    }\
    else {
      sweep_ch2 $c
      sweep_ch1 $c
    }
  }

  ######################################

  method sweep_ch2 {c} {
    if { $dev2 == {} } {return}
    set v [expr {$c-$cs1}];
    if {$v < $min_i2} {set v $min_i2}
    if {$v > $max_i2} {set v $max_i2}
    # is step is too small?
    if { abs($v-$cs2) > $min_i_step2 || $dir==0 } {
      if {$antipar} { $dev2 set_curr [expr -$v] }\
      else {$dev2 set_curr $v}
      set cs2 $v
      set changed 1
      set t_set [clock millisecond]
    }
  }

  method sweep_ch1 {c} {
    if { $dev1 == {} } {return}
    set v [expr {$c-$cs2}];
    if {$v < $min_i} {set v $min_i}
    if {$v > $max_i} {set v $max_i}
    # is step is too small?
    if { abs($v-$cs1) > $min_i_step || $dir==0 } {
      $dev1 set_curr $v
      set cs1 $v
      set changed 1
      set t_set [clock millisecond]
    }
  }


  ######################################
  ## get current/voltage/status/measured value
  # get measured current (sum for both channels)
  method get_mcurr {} { return [expr {$cm1 + $cm2}] }

  # get current (sum for both channels)
  method get_scurr {} { return [expr {$cs1 + $cs2}] }

  # get voltage (max absolute value)
  method get_volt {} { return [expr {abs($vm1)>abs($vm2)? $vm1:$vm2}] }

  # get stat
  method get_stat {} { return $st }

  # get measured value
  method get_mval {} { return $mval }


  ######################################
  # reset device and stop sweep
  method reset {} {
    $dev1 set_ovp $max_volt
    $dev1 cc_reset
    if {$dev2 != {}} {
      $dev2 set_ovp $max_volt
      $dev2 cc_reset
    }
    set cs1 [ $dev1 get_curr ]
    if {$dev2 != {}} {
      set cs2 [$dev2 get_curr]
      if {$antipar} {set cs2 [expr -$cs2]}
    }\
    else {set cs2 0}

    set dest [expr $cs1+$cs2]
    set rate 0

    set msg "reset"
    set t_set 0
    loop_restart
  }

  ######################################
  # set limits
  method set_limits {v1 v2} {
    if {$v1 >= $v2} {
      set minlim $v2
      set maxlim $v1
    } else {
      set minlim $v1
      set maxlim $v2
    }
  }
  ######################################
  # get limits
  method get_limits {} { return $minlim $maxlim }

  ######################################
  # go to upper limit and then back
  method  go {rate_ {dir_ 1} {wait_at_dest_ 0}} {
    if {$dir==$dir_ && $wait_at_dest==$wait_at_dest_ && $rate==$rate_} {return}
    set dir [expr {$dir_>=0? 1:-1}]
    set wait_at_dest $wait_at_dest_
    set rate [expr abs($rate_)]
    set msg "sweep to [expr {$dir>0? $maxlim:$minlim}] A"
    set t_set 0
    loop_restart
    return
  }
  ######################################
  # go back
  method  go_back {} {
    if {$dir==0} {return}
    set dir [expr -$dir]
    set msg "sweep to [expr {$dir>0? $maxlim:$minlim}] A"
    set t_set 0
    loop_restart
    return
  }

  ######################################
  # go back
  method stop {} {
    if {$dir==0} {return}
    set dir 0
    set msg "stop"
    set t_set 0
    loop_restart
    return
  }

}

#############################################################

