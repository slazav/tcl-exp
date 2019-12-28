# TempCurve class -- a temperature calibration curve

package require itcl

itcl::class TempCurve {
  variable name;   # name   0..15 symbols
  variable serial; # serial 0..10 symbols
  variable fmt;    # 3 (Ohm/K) or 4 (log10(Ohm)/K)
  variable tlim;   # temperature limit
  variable xdata;  # list of resistance values
  variable ydata;  # list of temperature values

  constructor {} { reset }

  # reset curve
  method reset {} {
    set name   {}
    set serial {}
    set fmt    3
    set tlim   9999
    set xdata {}
    set ydata {}
  }

  # get name
  method get_name {} {return $name}

  # set name
  method set_name {v} {
    set name [string range $v 0 15]
  }

  # get serial
  method get_serial {} { return $serial}

  # set serial
  method set_serial {v} {
    set serial [string range $v 0 10]
  }

  # get format (3 of 4)
  method get_fmt {}    {return $fmt}

  # set format
  method set_fmt {v} {
    if {$v!=3 && $v!=4} {
      error "TempCurve: unsupported format: $v (3 or 4 expected)"}
    set fmt $v
  }

  # get temperature limit
  method get_tlim {} {return $tlim}

  # set temperature limit
  method set_tlim {v} {
    if {! [string is double -strict $v]} {
     error "TempCurve: bad temperature limit: $v (floating-point value expected)"}
    set tlim $v
  }

  # get temperature coefficent
  # (calculated from first two points, or 1)
  method get_tcoeff {} {
    if {[get_npts] < 2} {error "TempCurve: curve has <2 points"}
    return [expr {[lindex ydata 1] > [lindex ydata 0] ? 2:1}]
  }

  # get number of points
  method get_npts {} {return [llength $xdata]}

  # append point to the data
  method append_point {x y} {
    lappend xdata $x
    lappend ydata $y
  }

  # Read curve from file. (Simple and bluefors formats are supported)
  # X column should be monotonic.
  method read_file {fname} {
    set ff [open $fname]
    reset

    while {[gets $ff line]>-1} {
      # skip empty lines and lines started with #
      if {$line=={}} continue
      if {[regexp {^#} $line]} continue

      # Bluefors format headers:

      if {[regexp {^Sensor Model: *([^ ]*)} $line v1 v2]} {
        set_name $v2; continue }

      if {[regexp {^Serial Number: *(.*)} $line v1 v2]} {
        set_serial $v2; continue }

      if {[regexp {^Data Format: *([34])} $line v1 v2]} {
        set_fmt $v2; continue }

      if {[regexp {^SetPoint Limit: *([0-9.])} $line v1 v2]} {
        set_tlim $v2; continue }

      if {[regexp {^Temperature coefficient:} $line]} { continue }

      if {[regexp {^Number of Breakpoints:} $line]} { continue }

      # Simple format header: 3 or more comma-separated values
      # name, serial, fmt, tlim

      set clist [split $line ","]
      if {[llength $clist] > 2} {

        set_name   [string trim [lindex $clist 0] { }]
        set_serial [string trim [lindex $clist 1] { }]
        set_fmt    [expr {[lindex $clist 2]}]
        if {[llength $clist]>3} {set_tlim [expr [lindex $clist 3]]}
        continue
      }

      # simple data line: two comma-separated values
      if {[llength $clist] == 2 } {
        append_point [lindex $clist 0] [lindex $clist 1]
        continue
      }

      # Bluefors data: two space-separated values
      set clist [split $line " +"]
      if {[llength $clist] == 3} {
        append_point [lindex $clist 1] [lindex $clist 2]
        continue
      }

      # skip unknown lines
    }
    close $ff

    # reverse lists if $xdata[end] < $xdata[0]
    if {[lindex $xdata 0] > [lindex $xdata end]} {
      set xdata [lreverse $xdata]
      set ydata [lreverse $ydata]
    }

    check_data
  }


  # check data
  method check_data {} {
    if {[llength $xdata] != [llength $xdata]} {
      error "TempCurve: xdata and ydata have different size"}
    if {[llength $xdata] < 2} {
      error "TempCurve: curve has <2 points"}
    if {[llength $xdata] > 200} {
      error "TempCurve: data is too long (should be 2..200 points)"}
    set xp {}
    foreach x $xdata {
      if {$xp != {} && $xp >= $x} {
        error "TempCurve: xdata should grow monotonicaly"}
      set xp $x
    }
  }

  method write_file_simple {fname} {
    set ff [open $fname w]
    check_data

    puts $ff "[get_name],[get_serial],[get_fmt],[get_tlim],[get_tcoeff]"

    foreach x $xdata y $ydata {
    }
    close $ff
  }

  # convert x -> y (can work with single values or lists)
  method calc {xx} {
    check_data
    set yy {}
    foreach x $xx {
      set xp [lindex $xdata 0]
      set yp [lindex $ydata 0]
      if {[get_fmt] == 4} {set x [expr log($x)/log(10)]}
      if {$x <  $xp} {lappend yy {};  continue}
      if {$x == $xp} {lappend yy $yp; continue}

      set y {}
      for {set n 1} {$n<[get_npts]} {incr n} {
        set xn [lindex $xdata $n]
        set yn [lindex $ydata $n]
        if {$x > $xp && $x <= $xn} {
          set y [expr {$yp + ($x-$xp)*($yn-$yp)/($xn-$xp)}]
          break
        }
        set xp $xn
        set yp $yn
      }
      lappend yy $y
    }
    return $yy
  }

}
