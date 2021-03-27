# Configurable interface for Lancaster-style drive box for vibrating wires.
#
# Classical drive box contains input connector, audio transformer 1:6.3 to
# separate signal ground, rotary switch "OFF", "0", "1k", "10k", "100k",
# "1M" with resistors (which work as V to I converter), 100 Ohm resistor
# with calibration connector, and output.
#
# This widget is based on ac_source widget. It also includes 
# the box calibration and can be used to calculate current through the wire.
#
# The drive box can be also used with tuning forks, but calculations
# in this widget are not very useful because of high impedance of the fork.
# (impedance of wibrating wires are about 0).
#
#
# Constructor: widget_drive_box <name> <tkroot> <options>
# Options:
#  -d, -dev     -- ac_source device name (default: TEST)
#  -t, -title   -- frame title (default: Drive)
#  -switch_list -- list of switch values (Default: "OFF 0 1k 10k 100k 1M")
#  -switch_cal  -- list of switch calibrations, V/I (Default: "Inf 6.30e2 6.93e3 6.36e4 6.31e5 6.30e6")
#  -switch_val  -- switch position (Default: 10k)
#
# Methods:
#
#  get_curr     -- get current (A) according with calibration
#  set_curr <v> -- set current (A) according with calibration
#  + methods of widget_ac_source

package require xBlt
package require itcl
package require DeviceRole


##########################################################
itcl::class widget_drive_box {

  inherit widget_ac_source

  variable switch_list
  variable switch_cal
  variable switch_val
  variable switch_r
  variable curr;    # current
  variable curr_fmt; # formatted value for the interface

  # Constructor: parse options, build interface
  constructor {tkroot args} {
    # Parse options.
    set options [list \
      {-d -dev}      dev_name {TEST}\
      {-t -title}    title     {}\
      {-switch_list}   switch_list {OFF 0 1k 10k 100k 1M}\
      {-switch_cal}    switch_cal  {Inf 6.30e2 6.93e3 6.36e4 6.31e5 6.30e6}\
      {-switch_val}    switch_val  10k\
    ]
    xblt::parse_options "widget_drive_box" $args $options
    widget_ac_source::constructor $tkroot\
         -show_offs 0 -show_phase 0 -dev $dev_name -title $title
    } {

      # # temporary remove buttons from the grid:
      # grid forget $tkroot.ubtn
      # grid forget $tkroot.abtn
      # ...
      # # add buttons back:
      # grid $tkroot.ubtn $tkroot.abtn

      # separator
      frame $root.sep2 -relief groove -borderwidth 1 -height 2
      grid $root.sep2 -padx 5 -pady 1 -columnspan 2 -sticky ew

      # Switch
      label $root.switch_l -text "Switch setting:"
      ttk::combobox $root.switch -width 12 -textvariable [itcl::scope switch_val]\
                                 -values $switch_list
      bind $root.switch <<ComboboxSelected>> "$this on_switch"
      grid $root.switch_l $root.switch -padx 5 -pady 2 -sticky e

      # Calibration
      label $root.switch_c_l -text "Calibration, V/I:"
      label $root.switch_c -textvariable [itcl::scope switch_r]
      grid $root.switch_c_l $root.switch_c -padx 5 -pady 2 -sticky e

      # Current
      label $root.curr_l -text "Current, A:"
      label $root.curr -textvariable [itcl::scope curr_fmt]
      grid $root.curr_l $root.curr -padx 5 -pady 2 -sticky e

      # check values
      if {[llength $switch_list] != [llength $switch_cal]} {
        error "-switch_list and -switch_cal have different length" }
      on_switch
      widget_bg $root #F0E0E0
      widget_state $root disabled
  }

  method on_switch {} {
    set n [lsearch -exact $switch_list $switch_val]
    if {$n < 0} {error "bad switch setting: $switch_val"}
    set switch_r [lindex $switch_cal $n]
    get_volt
  }

  method get_curr {} {
    return $curr
  }

  method set_curr {v} {
    if {$switch_r eq Inf} {return}
    set_volt $v*$switch_r
  }

  method update_curr {} {
    if {$switch_r eq Inf || !$out} {
      set curr_fmt 0
      set curr 0
    } else {
      set curr_fmt [format %.4e [expr $volt/$switch_r]]
      set curr [format %.6e [expr $volt/$switch_r]]
    }
  }

  # Redefine get methods, update current when changing generator voltage
  method on_update {} {
    set switch_val
    chain
    update_curr
  }
  method get_volt {} {
    set ret [chain]
    update_curr
    return $ret
  }
  method get_out {} {
    set ret [chain]
    update_curr
    return $ret
  }

}

