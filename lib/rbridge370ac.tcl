package require itcl;

##########################################################################
## LakeShore370AC interface
## This class will me moved later to DeviceRole library?

itcl::class LakeShore370AC {

  variable dev; # device

  ###################################
  ## Some lists
  ## Lists should depend on the bridge model and
  ## on the switch option

  # channel excitation methods (voltage/current)
  method exc_list {} { return [list\
    {voltage} {current}\
  ]}

  # channel current excitation list (used if excitation method = current)
  method volt_list {} { return [list\
    {2.00 uV} {6.32 uV} {20.0 uV} {63.2 uV} {200.0 uV} {632 uV}\
    {2.00 mV} {6.32 mV} {20.0 mV} {63.2 mV} {200.0 mV} {632 mV}\
  ]}

  # channel current excitation list (used if excitation method = voltage)
  method curr_list {} { return [list\
    {1.00 pA} {3.16 pA} {10.0 pA} {31.6 pA} {100 pA} {316 pA}\
    {1.00 nA} {3.16 nA} {10.0 nA} {31.6 nA} {100 nA} {316 nA}\
    {1.00 uA} {3.16 uA} {10.0 uA} {31.6 uA} {100 uA} {316 uA}\
    {1.00 mA} {3.16 mA} {10.0 mA} {31.6 mA}\
  ]}

  # channel range settings
  method res_list {} { return [list\
    {2.00 mOhm} {6.32 mOhm} {20.0 mOhm} {63.2 mOhm} {200 mOhm} {632 mOhm}\
    {2.00 Ohm}  {6.32 Ohm}  {20.0 Ohm}  {63.2 Ohm}  {200 Ohm}  {632 Ohm}\
    {2.00 kOhm} {6.32 kOhm} {20.0 kOhm} {63.2 kOhm} {200 kOhm} {632 kOhm}\
    {2.00 MOhm} {6.32 MOhm} {20.0 MOhm} {63.2 MOhm}\
  ]}

  # channel status flags -- short names
  method ch_status_list {} { return [list\
    {CS_OVL} {VCM_OVL} {VDIF_OVL} {VMIX_OVL}\
    {R_OVER} {R_UNDER} {T_OVER} {T_UNDER}\
  ]}

  # alarm sources
  method alarm_src_list {} { return [list\
    {Kelvin} {Ohms} {Linear Data}\
  ]}

  # alarm latching setting
  method alarm_latch_list {} { return [list\
    {Non-latching} {latching}\
  ]}

  # monitor source flags -- short names
  method mon_src_list {} { return [list\
    {OFF} {CS_NEG} {CS_POS} {VAD}\
    {VCM_NEG} {VCM_POS} {VDIFF} {VMIX}\
  ]}

  ###################################

  # trim number, fix "octal" values (like 010)
  method trim_num {n} {
    set n [string trimright $n \r\n]
    set n [string trimleft $n " 0"]
    if {$n == {}} {return 0}
    return [expr $n]
  }

  ###################################

  constructor {d} { set dev $d }

  ###################################
  # device functions
  method get_id {} {
    return [string trimright [$dev cmd *IDN?] \r\n ]
  }

  method get_mon {} {
    set v [$dev cmd MONITOR?]
    return [lindex [mon_src_list] $v]
  }

  method set_mon {v} {
    set vn [lsearch -exact [mon_src_list] $v]
    if {$vn < 0} { error "set_mon: wrong setting: $v"}
    $dev cmd "MONITOR $vn"
  }

  method get_guard {} { return [expr {[$dev cmd GUARD?]}] }

  method set_guard {v} { $dev cmd "GUARD [expr {$v? 1:0}]" }

  method set_scan {ch auto} {
    if {$ch < 1 || $ch > 16} {
      error "set_scan: wrong autoscan setting: $auto"}
    if {$auto != 0 && $auto != 1} {
      error "set_scan: wrong autoscan setting: $auto"}
    $dev cmd "SCAN $ch,$auto"
  }

  method get_scan {} {
    set r [split [$dev cmd "SCAN?"] ,]
    set ch   [trim_num [lindex $r 0]]
    set auto [trim_num [lindex $r 1]]
    return [list $ch $auto]
  }

  # power-up self-test status
  method get_tst {} { return [expr {[$dev cmd "*TST?"]}] }

  ###################################
  # curve functions

  # read header, returns name,serial,
  method get_crv_hdr {n} {
    set d [lindex [$dev cmd CRVHDR? $n] 0]
    set r [split $d ,]
    set name   [lindex $r 0]
    set serial [lindex $r 1]
    set fmt    [trim_num [lindex $r 2]]
    set limit  [trim_num [lindex $r 3]]
    set coeff  [trim_num [lindex $r 4]]

    if     {$fmt == 3} {set fmt "Ohm/K"}\
    elseif {$fmt == 4} {set fmt "log(Ohm)/K"}\
    else   {set fmt "Unknown"}

    if     {$coeff == 1} {set coeff "Neg"}\
    elseif {$coeff == 2} {set coeff "Pos"}\
    else   {set coeff "Unknown"}

    return [list $name $serial $fmt $limit $coeff]
  }


  # trivial save function
  method save_curve {n fname} {
    set ff [open $fname {w}]
    set l [$dev cmd "CRVHDR? $n"]
    puts $ff [string trimright $l \r\n]
    for {set i 1} {$i<=200} {incr i} {
      set l [$dev cmd "CRVPT? $n, $i"]
      puts $ff [string trimright $l \r\n]
    }
    close $ff
  }

  # save all curves in a directory
  method save_all_curves {fdir} {
    for {set n 1} {$n<=20} {incr n} {
      save_curve $n [format "$fdir/curve_%02d" $n]
    }
  }

  # trivial load function, no checks
  # skip empty lines and lines which start with #
  method load_curve {n fname} {
    set ff [open $fname {r}]
    set l {}
    while {$l=={} || [string range $l 0 1] == "#"} {
      set l [gets $ff]
      if {[eof $ff]} return
    }
    $dev cmd "CRVDEL $n"
    $dev cmd "CRVHDR $n, $l"
    for {set i 1} {$i<=200} {incr i} {
      set l {}
      while {$l=={} || [string range $l 0 1] == "#"} {
        set l [gets $ff]
        if {[eof $ff]} return
      }
      $dev cmd "CRVPT $n, $i, $l"
    }
    close $ff
  }

  # load all curves from a directory
  method load_all_curves {fdir} {
    for {set n 1} {$n<=20} {incr n} {
      load_curve $n [format "$fdir/curve_%02d" $n]
    }
  }

  # delete a curve from the device
  method del_curve {n} {
    $dev cmd "CRVDEL $n"
  }


  ###################################
  # channel functions

  # get resistance reading
  method get_ch_res {chan} {
    set r [$dev cmd RDGR? $chan]
    return [expr $r]
  }

  # get temperature reading
  method get_ch_temp {chan} {
    set r [$dev cmd RDGK? $chan]
    return [expr $r]
  }

  # get excitation power reading
  method get_ch_pwr {chan} {
    set r [$dev cmd RDGPWR? $chan]
    return [expr $r]
  }

  # get channel status as a list of numbers
  method get_ch_status {chan} {
    set r [trim_num [$dev cmd RDGST? $chan]]
    set ret {}
    for {set i 0} {$i<8} {incr i} {
      if {$r & (1<<$i)} {lappend ret $i } }
    return $ret
  }


  # Get input channel parameters (INSET)
  method get_ch_inp {chan} {
    set r [split [$dev cmd INSET? $chan] ,]
    set onoff   [trim_num [lindex $r 0]]
    set dwell   [trim_num [lindex $r 1]]
    set pause   [trim_num [lindex $r 2]]
    set curve   [trim_num [lindex $r 3]]
    set tempco  [trim_num [lindex $r 4]]
    return [list $onoff $dwell $pause $curve $tempco]
  }

  method set_ch_inp {chan onoff dwell pause curve tempco} {
    if {$onoff!=0 && $onoff!=1} {
      error "set_ch_inp: wrong onoff setting: $onoff"}
    if {$dwell < 1 || $dwell > 200} {
      error "set_ch_inp: wrong dwell setting: $dwell"}
    if {$pause < 3 || $pause > 200} {
      error "set_ch_inp: wrong pause setting: $pause"}
    if {$curve < 0 || $curve > 20} {
      error "set_ch_inp: wrong curve setting: $curve"}
    $dev cmd "INSET $chan, $onoff, $dwell, $pause, $curve, $tempco"
  }

  # is channel on?
  method is_ch_on {chan} {
    return [lindex [get_ch_inp $chan] 0]
  }

  # switch channel on/off
  method ch_onoff {chan val} {
    set r [get_ch_inp $chan]
    lset r 0 [expr {$val? 1:0}]
    set_ch_inp $chan {*}$r
  }


  # Get channel range and excitation settings.
  # Returns list with 5 elements:
  #   mode excitation range autorange onoff
  # Codes are converted to text names.
  method get_ch_range {chan} {

    set r [split [$dev cmd RDGRNG? $chan] ,]
    set mod_n   [trim_num [lindex $r 0]]
    set exc_n   [trim_num [lindex $r 1]]
    set rng_n   [trim_num [lindex $r 2]]
    set autorng [trim_num [lindex $r 3]]
    set onoff   [expr ![lindex $r 4]]

    # convert from numbers to text values
    set mod [lindex [exc_list] $mod_n]
    if {$mod_n == 0} {
      set exc [lindex [volt_list] [expr $exc_n-1] ]
    } else {
      set exc [lindex [curr_list] [expr $exc_n-1] ]
    }
    set rng [lindex [res_list] [expr $rng_n-1]]

    return [list $mod $exc $rng $autorng $onoff]
  }

  # Set channel range and excitation settings.
  method set_ch_range {chan exc_type exc_range res_range arange exc_on} {
    set exc_type_n [lsearch -exact [exc_list] $exc_type]
    set res_range_n [lsearch -exact [res_list] $res_range]
    incr res_range_n

    if {$exc_type_n == 0} {
      set exc_range_n [lsearch -exact [volt_list] $exc_range]
      incr exc_range_n
    } else {
      set exc_range_n [lsearch -exact [curr_list] $exc_range]
      incr exc_range_n
    }

    if {$exc_type_n<0} {
      error "set_ch_range: wrong exc_type setting: $exc_type"}
    if {$exc_range_n<1} {
      error "set_ch_range: wrong exc_range setting: $exc_range"}
    if {$res_range_n<1} {
      error "set_ch_range: wrong res_range setting: $res_range"}
    if {$arange!=0 && $arange!=1} {
      error "set_ch_range: wrong autorange setting: $arange"}
    if {$exc_on!=0 && $exc_on!=1} {
      error "set_ch_range: wrong exc_on setting: $exc_on"}
    $dev cmd RDGRNG "$chan,$exc_type_n,$exc_range_n,$res_range_n,$arange,[expr !$exc_on]"
  }

  # Get channel filter parameters.
  # Returns list with 3 elements:
  #   onoff settle_time window
  method get_ch_filter {chan} {
    set r [split [$dev cmd FILTER? $chan] ,]
    set onoff   [trim_num [lindex $r 0]]
    set settle  [trim_num [lindex $r 1]]
    set window  [trim_num [lindex $r 2]]
    return [list $onoff $settle $window]
  }

  # Set channel filter parameters.
  method set_ch_filter {chan onoff settle window} {
    if {$onoff != 0 && $onoff != 1} {
      error "set_ch_filter: wrong onoff value: $onoff"}
    if {$settle < 1 || $settle > 200} {
      error "set_ch_filter: wrong settle value: $settle"}
    if {$window < 1 || $window > 80} {
      error "set_ch_filter: wrong window value: $window"}
    $dev cmd FILTER "$chan, $onoff, $settle, $window"
  }


  # get channel alarm parameters
  method get_ch_alarm_par {chan} {
    set r [split [$dev cmd ALARM? $chan] ,]
    set onoff   [expr [lindex $r 0]]
    set src_n   [expr [lindex $r 1]]
    set hval    [expr [lindex $r 2]]
    set lval    [expr [lindex $r 3]]
    set band    [expr [lindex $r 4]]
    set latch_n [expr [lindex $r 5]]
    # convert from numbers to text values
    set src   [lindex [alarm_src_list] $src_n]
    set latch [lindex [alarm_latch_list] $latch_n]
    return [list $onoff $src $hval $lval $band $latch]
  }

  # get channel alarm status (two bool values for low and high boundary)
  method get_ch_alarm_st {chan} {
    set r [split [$dev cmd ALARMST? $chan] ,]
    return $r
  }

}
