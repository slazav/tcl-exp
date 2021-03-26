# Configurable interface for ac_source DeviceRole
#
# Constructor: widget_ac_source <name> <tkroot> <options>
# Options:
#  -d, -dev    -- ac_source device name (default: TEST)
#  -t, -title  -- frame title (default: {})
#  -show_offs  -- show offset entry (default: 0)
#  -show_phase -- show phase entry (default: 0)
#
# Methods:
#
#   readonly 1|0  -- activate/deactivate interface
#   enable 1|0  -- open/close device (no effect on the generator settings)
#   set_freq <v>
#   get_freq
#   set_volt <v>
#   get_volt
#   set_offs <v>
#   get_offs
#   set_phase <v>
#   get_phase
#   set_out 0|1   -- set generator output state (on/off)
#   get_out
#   set_ac <freq> <volt> [<offs>] [<phase>]

package require xBlt
package require itcl
package require DeviceRole


##########################################################
itcl::class widget_ac_source {

  variable dev_name   {}; # device name
  variable show_offs  {}; # show offset entry
  variable show_phase {}; # show phase entry
  variable title      {}; # frame title

  variable dev      {}; # DeviceRole object
  variable root     {}; # root widget path

  variable freq  0
  variable volt  0
  variable offs  0
  variable phase 0
  variable out   1


  # Constructor: parse options, build interface
  constructor {tkroot args} {

    # Parse options.
    set options [list \
      {-d -dev}      dev_name {TEST}\
      {-t -title}    title     {}\
      {-show_offs}   show_offs  0\
      {-show_phase}  show_phase 0\
    ]
    xblt::parse_options "widget_ac_source" $args $options

    # check parameters
    if {$dev_name eq {}} { error "ac_source: device name is empty" }

    # Main frame:
    set root $tkroot
    labelframe $root -text $title -font {-weight bold -size 10}

    # On/Off button
    checkbutton $root.out -text "Output ON"\
       -variable [itcl::scope out] -command "$this set_out $[itcl::scope out]"
    grid $root.out -padx 5 -pady 2 -sticky e

    # separator
    frame $root.sep -relief groove -borderwidth 1 -height 2
    grid $root.sep -padx 5 -pady 1 -columnspan 2 -sticky ew

    # Frequency/amplitude/offset/phase entries
    foreach n {freq volt offs phase}\
            t {"Frequency, Hz:" "Voltage, Vpp:" "Offset, V" "Phase, deg:"}\
            e [list 1 1 $show_offs $show_phase] {
      if {!$e} continue
      label $root.${n}_l -text $t
      entry $root.${n} -width 12 -textvariable [itcl::scope $n]
      grid $root.${n}_l $root.${n} -padx 5 -pady 2 -sticky e
    }

    # Apply/Update buttons
    button $root.abtn -text "Apply"  -command "$this on_apply"
    button $root.ubtn -text "Update" -command "$this on_update"
    grid $root.abtn $root.ubtn -padx 3 -pady 3

    widget_bg $root #F0E0E0
    widget_state $root disabled
  }

  # activate/deactivate interface
  method readonly {{state 1}} {
    if {$state} { widget_state $root disabled }\
    else { widget_state $root normal }
  }

  # same + open/close device
  method enable {{state 1}} {
    readonly [expr !$state]
    if {$state} {
      if {$dev eq {}} { set dev [DeviceRole $dev_name ac_source] }
      on_update
    }\
    else {
      if {$dev != {}} { itcl::delete object $dev }
      set dev {}
    }
  }


  # write settings to the device
  method on_apply {} {
    if {$dev eq {}} return
    $dev set_ac  $freq $volt $offs $phase
    on_update
  }

  # read settings from the device
  method on_update {} {
    if {$dev eq {}} return
    set volt  [$dev get_volt]
    set freq  [$dev get_freq]
    set offs  [$dev get_offs]
    set phase [$dev get_phase]
    set out   [$dev get_out]
  }

  # Other methods are just wrappers for DeviceRole
  # All set/get commands also modify values in the interface

  method get_volt {} {
    if {$dev eq {}} return {}
    set volt [$dev get_volt]
    return $volt
  }

  method get_freq {} {
    if {$dev eq {}} return {}
    set freq [$dev get_freq]
    return $freq
  }

  method get_offs {} {
    if {$dev eq {}} return {}
    set offs [$dev get_offs]
    return $offs
  }

  method get_phase {} {
    if {$dev eq {}} return {}
    set phase [$dev get_phase]
    return $phase
  }

  method get_out {} {
    if {$dev eq {}} return {}
    set out [$dev get_out]
    return $out
  }


  method set_ac {f v {o 0} {p {}}} {
    if {$dev eq {}} return {}
    $dev set_ac $f $v $o $p
    on_update
  }

  method set_volt {v} {
    if {$dev eq {}} return {}
    $dev set_volt $v
    get_volt
  }

  method set_freq {v} {
    if {$dev eq {}} return {}
    $dev set_freq $v
    get_freq
  }

  method set_offs {v} {
    if {$dev eq {}} return {}
    $dev set_offs $v
    get_offs
  }

  method set_phase {v} {
    if {$dev eq {}} return {}
    $dev set_phase $v
    get_phase
  }

  method set_out {v} {
    set out $v
    if {$dev eq {}} return {}
    $dev set_out $out
    get_out
  }

}

