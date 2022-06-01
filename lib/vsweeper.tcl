# voltage sweeper library

package require DeviceRole 1.0
package require xBlt

#############################################################
## Arguments for constructor:
# -p -ps_dev      -- power supply device
# -v -max_curr    -- max vcurrent, A (default 1)
# -m -max_rate    -- max rate, A/S (default 1)
# -r -ramp_tstep  -- ramping time step, s (default 1)
# -i -idle_tstep  -- idle time step, s (default 10)
# -s -skip        -- do not write points if voltage was not set (0)
# -on_new_val     -- function prefix for running with new values ($t $vm $vs $cm)
# -on_new_com     -- function prefix for running with new comment ($t $comm)
#
#  Other methods:

#  turn_on {}   -- open devices and start main loop
#  turn_off {}  -- stop main loop and close devices
#  get_mvolt {} -- get measured current (from the last loop step)
#  get_svolt {} -- get set current (from the last loop step)
#  get_curr {}  -- get measured voltage (from the last loop step)
#  get_stat {}  -- get device status
#  get_mval {}  -- get gauge data
#  get_dir  {}  -- get direction (-1,0,1)
#  get_rate {}  -- get rate
#  reset {}     -- reset devices

#  set_limits     -- set sweep limits
#  get_limits     -- get sweep limits
#  go <rate> <dir> <wait>
#                 -- start sweeping with <rate> in direction <dir>,
#                    if <wait> then wait after sweep
#  go_back        -- change sweep direction
#  stop           -- stop ramping current and wait

#############################################################

itcl::class VSweepController {
  variable dev {}; # device driver
  variable rh  {};    # ramping loop handler
  variable vs  0;     # set current - 1st chan
  variable vm  0;     # measured current - 1st chan
  variable cm  0;     # measured voltage - 1st chan
  variable st {};     # device state
  variable tstep;     # current time step

  # see options:
  variable ps_dev
  variable max_curr
  variable max_rate
  variable ramp_tstep
  variable idle_tstep
  variable skip
  variable on_new_val
  variable on_new_com

  # device parameters
  variable min_v_step  1;
  variable min_v  0;
  variable max_v  0;

  # Main loop control parameters
  variable rate     0; # rate
  variable minlim   0; # sweep limits
  variable maxlim   0;
  variable dir      0; # sweep direction "+1/0/-1"
  variable t_set    0; # time of last current setting
  variable nsweeps -1; # number of sweeps to do (-1 for infinite)
  variable state    0; # off/on
  variable msg     ""; # message to be logged into database on the next step
  variable changed  0; # set to 1 if current was changed
  variable in_the_loop 0;

  ######################################
  # constructor, set parameters
  constructor {args} {
    set options [list \
      {-p -ps_dev}  ps_dev  {}\
      {-c -max_curr} max_curr {1}\
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
    if {$ps_dev  == {} } { error "ps_dev is empty" }
    set dev [DeviceRole $ps_dev power_supply]
    set min_v_step [expr [$dev cget -min_v_step]]
    set max_v [expr [$dev cget -max_v]]
    set min_v [expr [$dev cget -min_v]]

    # initial current limits
    set_limits $min_v $max_v

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
  }

  # put value into the database
  method put_value {} {
    set t [expr [clock milliseconds]/1000.0]
    if {$on_new_val != {}} { uplevel \#0 [eval {$on_new_val $t $vm $vs $cm $st}]}
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
      if {[is_obj $dev]} {
        itcl::delete object $dev
        set dev {}
      }
      set in_the_loop 0
      return
    }

    if {$dir != 0} { step }

    # measure current
    set cm [$dev get_curr]

    # measure voltage
    set vm [ $dev get_volt]

    # get device state
    set st0 0
    set st [ $dev get_stat ]
    if {$st!="VC"} {set st0 1}

    if {!$skip || $changed==1 || $msg != {}} { put_value }
    set changed 0

    if {$msg != {}} {
      put_comment $msg
      set msg {}
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
    if {$maxlim > $max_v} {set maxlim $max_v}
    if {$minlim < $min_v} {set minlim $min_v}
    if {$rate > $max_rate} {set rate $max_rate}

    # are we outside the limits?
    if {$vs > $maxlim && $dir>0} {
       set dir -1
       set msg "sweep [expr {$dir>0?{up}:{down}}] with rate $rate V/s"
    }
    if {$vs < $minlim && $dir<0} {
      set dir +1
      set msg "sweep [expr {$dir>0?{up}:{down}}] with rate $rate V/s"
    }

    # set voltage step we need
    set t_cur [clock millisecond]
    set dt [expr {$t_cur-$t_set}]
    set dv [expr {$t_set==0? 0 : 1.0*$dir*$rate*$dt/1000.0}]
    if {$t_set==0} {set t_set $t_cur}
    # limit the voltage step
    if {abs($dv) > $max_rate*$ramp_tstep} {
      set dv [expr "$max_rate*$ramp_tstep*$dir"]
    }

    # Are we near the destination?
    if { ($dir>0 && abs($vs-$maxlim)<abs($dv)) ||\
         ($dir<0 && abs($vs-$minlim)<abs($dv))} {
      set c [expr $dir>0? $maxlim:$minlim]

      if {$nsweeps>0} {set nsweeps [expr $nsweeps-1]}
      # do we want to do back?
      if {$nsweeps==0 || $maxlim == $minlim} {
        set dir 0
        set msg "sweep finished at $c V"
      }\
      else {
        set dir [expr -$dir]
        set msg "sweep [expr {$dir>0?{up}:{down}}] with rate $rate V/s"
      }
    }\
    else {
      set c [expr {$vs + $dv}]
    }
    sweep_ch $c
  }

  ######################################

  method sweep_ch {v} {
    if { $dev == {} } {return}
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    # is step is too small?
    if { abs($v-$vs) > $min_v_step || $dir==0 } {
      $dev set_volt [expr $v]
      set vs $v
      set changed 1
      set t_set [clock millisecond]
    }
  }


  ######################################
  ## get current/voltage/status/measured value
  # get measured voltage
  method get_mvolt {} { return $vm }

  # get set voltage
  method get_svolt {} { return $vs }

  # get current
  method get_curr {} { return $cm }

  # get stat
  method get_stat {} { return $st }

  # get destination
  method get_dest {} {
    if {$dir==0} {return [get_svolt]}
    return [expr {$dir>0? $maxlim:$minlim}]
  }

  # get direction (-1,0,1)
  method get_dir {} { return $dir }

  # get rate
  method get_rate {} { return $rate }

  ######################################
  # reset device and stop sweep
  method reset {} {
    $dev set_ocp $max_curr
    $dev cv_reset
    set vs [$dev get_volt]
    set rate 0
    set msg "reset"
    set t_set 0
    loop_restart
  }

  ######################################
  # set limits
  method set_limits {v1 v2} {
    if {[catch {expr {abs($v1)}}]} {error "non-numeric limit: $v1"}
    if {[catch {expr {abs($v2)}}]} {error "non-numeric limit: $v2"}
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
  method get_limits {} { return "$minlim $maxlim" }

  ######################################
  # go to upper limit and then back
  method  go {rate_ {dir_ 1} {nsweeps_ -1}} {
    # if we are outside limits, then no need to change direction
    if {$dir>0 && [get_svolt]<$minlim} {set dir_ $dir}
    if {$dir<0 && [get_svolt]>$maxlim} {set dir_ $dir}

    # if some parameter is non-numeric, return error
    if {[catch {expr {abs($rate_)}}]} {error "non-numeric rate: $rate_"}
    if {![string is integer $dir_]} {error "non-integer dir (should be 1 or -1): $dir_"}
    if {![string is integer $nsweeps_]} {error "non-integer sweep number: $nsweeps_"}

    # rate should be positive, dir should be -1 or +1
    set rate_ [expr abs($rate_)]
    set dir_ [expr {$dir_>=0? 1:-1}]

    # update nsweeps parameter
    set nsweeps $nsweeps_

    # if direction and rate did not changed do nothing
    if {$dir==$dir_ && $rate==$rate_} { return }

    # change parameters and restart the loop
    set rate $rate_
    set dir $dir_
    set msg "sweep [expr {$dir_>0?{up}:{down}}] with rate $rate_ V/s"
    set t_set 0
    loop_restart
    return
  }
  ######################################
  # go back
  method  go_back {} {
    if {$dir==0} {return}
    # if we are outside limits, then no need to change direction
    if {$dir>0 && [get_svolt]<$minlim} {return}
    if {$dir<0 && [get_svolt]>$maxlim} {return}
    set dir [expr -$dir]
    set msg "sweep [expr {$dir>0?{up}:{down}}] with rate $rate V/s"
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

