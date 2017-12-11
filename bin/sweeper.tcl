# current sweeper library

package require Device
package require DeviceRole 1.0
package require xBlt

#############################################################
## Command line options:
# -p -ps_dev1     -- power supply device
# -P -ps_dev2     -- power supply device - 2nd channel
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

set options [list \
{-p -ps_dev1}  ps_dev1  {}\
{-P -ps_dev2}  ps_dev2  {}\
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
  variable dt    0;   # actual time from last current setting
  variable rate  0;
  variable dest  0;
  variable dest2 0;
  variable msg "";  # message to be logged into database on the next step
  variable state 0; # set to 1 to measure current on the next step
  variable tstep;   # current time step

  # see options:
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


  ######################################
  # constructor - open and lock devices, get parameters
  # should call spp_server_async::ans or spp_server_async::err

  constructor {args} {
    # parse options
    global options
    xblt::parse_options "sweeper" $args $options

    # open secons PS device if needed and get its parameters
    if {$ps_dev1  == {} } { error "ps_dev1 is empty" }
    set dev1 [DeviceRole $ps_dev1 power_supply]
    $dev1 lock
    set min_i_step [$dev1 cget -min_i_step]
    set max_i [$dev1 cget -max_i]
    set min_i [$dev1 cget -min_i]

    # open secons PS device if needed
    if {$ps_dev2 != {}} {
      if {$ps_dev1 == $ps_dev2} {error "same devices for both channels"}
      set dev2 [DeviceRole $ps_dev2 power_supply]
      $dev2 lock
      set min_i_step2 [$dev2 cget -min_i_step]
      set max_i2 [$dev2 cget -max_i]
      set min_i2 [$dev2 cget -min_i]
    }

    # open gauge device if needed
    if {$g_dev != {}} {
      set gdev [DeviceRole $g_dev gauge]
    }

    # Open database if needed
    if {$db_dev != {} } { Device $db_dev }

    # reset the device and starm main loop
    set tstep $idle_tstep
    reset
  }

  destructor {
    $dev1 unlock
    itcl::delete object $dev1
    if {$dev2 != {}} {
      $dev2 unlock
      itcl::delete object $dev2
    }
  }

  ######################################
  ### internal DB functions

  # put comment into the database
  method put_comment {c} {
    set t [expr [clock milliseconds]/1000]
    if {$on_new_com != {}} { uplevel \#0 [eval $on_new_com $t $c]}
    if {$db_dev != {} && $db_ann != {} } {
      $db_dev cmd "put $db_ann $t $c"
      $db_dev cmd "sync"
    }
  }

  # put value into the database
  method put_value {} {
    set cm [expr {$cm1 + $cm2}]
    set cs [expr {$cs1 + $cs2}]
    set t [expr [clock milliseconds]/1000]
    if {$on_new_val != {}} { uplevel \#0 [eval $on_new_val $t $cm $cs $vm1 $mval]}
    if { $db_dev != {} && $db_val != {}} {
      $db_dev cmd "put $db_val $t $cm $cs $vm1 $mval"
      $db_dev cmd "sync"
    }
  }

  ######################################
  # Main loop

  method loop {} {

    # Errors in the loop can not go to the interface
    # Now I ignore them, then it may be useful
    # to catch them by bgerror and return as a program status

    after cancel $rh
    if {$rate==0} {set tstep $idle_tstep}\
    else          {set tstep $ramp_tstep}

    # measure all values
    set cm1 [ $dev1 get_curr ]
    if {$dev2 != {}} {
      set cm2 [$dev2 get_curr]
    }
    set vm1 [ $dev1 get_volt ]
    if {$dev2 != {}} {
      set vm2 [$dev2 get_volt]
    }
    set st [ $dev1 get_stat ]
    if {$dev2 != {}} {
      set st "$st:[ $dev2 get_stat ]"
    }
    # do measurement if needed
    if {$gdev != {}} { set mval [ $gdev get ] }\
    else { set mval {} }

    if {!$skip || $state==1 || $msg != {}} { put_value }
    set state 0

    if {$msg != {}} {
      put_comment $msg
      set msg {}
    }

    # stop ramping if the real current jumped outside the tolerance
    set cm1 [ $dev1 get_curr ]
    if {$dev2 != {}} { set cm2 [$dev2 get_curr] } else {set cm2 0}
    set tolerance  [expr 100*$min_i_step]
    set tolerance2 [expr 100*$min_i_step2]
    if { abs($cm1-$cs1) > $tolerance ||\
         abs($cm2-$cs2) > $tolerance2} {
      set cs1 $cm1
      set cs2 $cm2
      set rate 0
        put_comment "current jump to [expr $cs1+$cs2]"
    }

    if {$rate > 0} { step }
    set rh [after [expr int($tstep*1000)] "$this loop"]
  }


  # active step (rate>0)
  method step {} {
    # limit rate and destinations
    if {$dest > $max_i + $max_i2} {set dest [expr {$max_i+$max_i2}]}
    if {$dest < $min_i + $min_i2} {set dest [expr {$min_i+$min_i2}]}
    if {$dest2 > $max_i + $max_i2} {set dest2 [expr {$max_i+$max_i2}]}
    if {$dest2 < $min_i + $min_i2} {set dest2 [expr {$min_i+$min_i2}]}
    if {$rate > $max_rate} {set rate $max_rate}

    # find sweep direction
    if {[expr $cs1+$cs2] <= $dest} {set dir 1} else {set dir -1}

    # set current step we need
    set dt [expr $dt + $tstep]
    set di [expr {1.0*$dir*$rate*$dt}]

    # Now set where do we want to go on this step (in $c)
    # Are we near the destination?
    if { [expr {abs([expr $cs1+$cs2]-$dest)}] < [expr {abs($di)}] } {
      set c $dest
      # do we want to swap sweep direction?
      if {$dest==$dest2} {
        set rate 0
        set msg "sweep finished at $dest A"
      }\
      else {
        set c $dest
        # swap dest and dest2
        set dest  $dest2
        set dest2 $c
        set msg "sweep to $dest A at $rate A/s"
      }
    }\
    else {
      set c [expr {[expr $cs1+$cs2] + $di}]
    }

    # first try to sweep ch2:
    if { $dev2 != {} } {
      set v [expr {$c-$cs1}];
      if {$v < $min_i2} {set v $min_i2}
      if {$v > $max_i2} {set v $max_i2}
      # is step is too small?
      if { abs($v-$cs2) > $min_i_step2 || $rate==0 } {
        $dev2 set_curr $v
        set cs2 $v
        set state 1
        set dt 0
      }
    }
    # the same with ch1:
    if { $dev1 != {} } {
      set v [expr {$c-$cs2}];
      if {$v < $min_i} {set v $min_i}
      if {$v > $max_i} {set v $max_i}
      # is step is too small?
      if { abs($v-$cs1) > $min_i_step || $rate==0 } {
        $dev1 set_curr $v
        set cs1 $v
        set state 1
        set dt 0
      }
    }
    return
  }

  ######################################
  ## get current/voltage/status/measured value
  # get measured current (sum for both channels)
  method get_mcurr {} { return [expr {$cm1 + $cm2}] }

  # get current (sum for both channels)
  method get_scurr {} { return [expr {$cs1 + $cs2}] }

  # get voltage (1st channel only)
  method get_volt {} { return $vm1 }

  # get stat
  method get_stat {} { return $st }

  # get measured value
  method get_mval {} { return $mval }


  ######################################
  # reset device and stop sweep
  method reset {} {
    after cancel $rh

    $dev1 set_ovp $max_volt
    $dev1 cc_reset
    if {$dev2 != {}} {
      $dev2 set_ovp $max_volt
      $dev2 cc_reset
    }
    set cs1 [ $dev1 get_curr ]
    set cs2 0
    set dest [expr $cs1+$cs2]
    set rate 0

    set msg "reset"
    set rh [after idle $this loop]
  }

  ######################################
  # start sweep to some value
  method sweep {dest_ rate_} {
    sweep_between $dest_ $dest_ $rate_
  }

  ######################################
  # sweep between two values
  method sweep_between {dest_ dest2_ rate_} {
    if {$rate != $rate_ || $dest!=$dest_ || $dest2!=$dest2_} {
      after cancel $rh
      set rate [expr abs($rate_)]
      set dest $dest_
      set dest2 $dest2_
      set msg "sweep to $dest A at $rate A/s"
      set rh [after idle $this loop]
    }
    return
  }

  ######################################
  # stop sweep
  method sweep_stop {} {
    if {$rate != 0} {
      after cancel $rh
      set rate 0
      set msg "sweep stoped"
      set rh [after idle $this loop]
    }
    return
  }

}

#############################################################

