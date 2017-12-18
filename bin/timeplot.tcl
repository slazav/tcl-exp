# timeplot library

package require Device 1.3
package require xBlt
package require itcl

set options [list \
{-n -ncols}    ncols    1\
{-a -names}    names    {}\
{-t -titles}   titles   {}\
{-c -colors}   colors   {}\
{-h -hides}    hides    {}\
{-f -fmts}     fmts     {}\
{-l -logs}     logs     {}\
{-N -maxn}     maxn     0\
{-T -maxt}     maxt     0\
]

itcl::class TimePlot {
  # parameters /see options/
  variable ncols
  variable titles
  variable colors
  variable maxn
  variable maxt

  ##########################################################
  constructor {plot args} {
    # Parse options.
    global options
    xblt::parse_options "timeplot" $args $options

    # Check that ncols>0 and titles and colors have enough values
    if {$ncols<=0} {error "timeplot: ncols should be > 0: $ncols"}

    # create automatic column names
    for {set i [llength $names]} {$i < $ncols} {incr i} {
      lappend names "data-$i" }

    # create automatic column titles if needed
    for {set i [llength $titles]} {$i < $ncols} {incr i} {
      lappend titles "data-$i" }

    # create automatic column colors if needed
    set defcolors {red green blue cyan magenta yellow\
      darkred darkgreen darkblue darkcyan darkmagenta darkyellow black}
    for {set i [llength $colors]} {$i < $ncols} {incr i} {
      set c [lindex $defcolors [expr {$i%[llength $defcolors]} ] ]
      lappend colors $c }

    # create automatic format settings
    for {set i [llength $fmts]} {$i < $ncols} {incr i} {
      lappend fmts "%g" }

    # show all columns by default
    for {set i [llength $hides]} {$i < $ncols} {incr i} {
      lappend hides 0 }

    # non-log scale for all columns by default
    for {set i [llength $logs]} {$i < $ncols} {incr i} {
      lappend logs 0 }

    # configure interface
    frame $plot
    set graph  $plot.g
    set scroll $plot.s
    # BLT graph
    blt::graph $graph -leftmargin 60
    pack $graph -side top -expand yes -fill both
    # Scrollbar
    scrollbar $scroll -orient horizontal
    pack $scroll -fill x
    # clear button
    button $plot.clear -command "$this clear" -text Clear
    pack $plot.clear -side right -padx 2

    $graph legend configure -activebackground white

    # set up xBLT things
    xblt::plotmenu   $graph -showbutton 1 -buttonlabel Menu -buttonfont {Helvetica 12} -menuoncanvas 0
    xblt::legmenu    $graph
    xblt::hielems    $graph
    xblt::crosshairs $graph -variable v_crosshairs
    xblt::measure    $graph
    xblt::readout    $graph -variable v_readout -active 1;
    xblt::zoomstack  $graph -scrollbutton 2 -axes x -recttype x
    xblt::elemop     $graph
    xblt::scroll     $graph $scroll -timefmt 1

    # create BLT vectors for data, set up BLT plot
    blt::vector create "$this:T"
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector create "$this:D$i"
      set t [lindex $titles $i]
      set n [lindex $names $i]
      set c [lindex $colors $i]
      set f [lindex $fmts $i]
      set h [lindex $hides $i]
      set l [lindex $logs $i]
      # create vertical axis and the element, bind them
      $graph axis create $n -title $t -titlecolor black -logscale $l
      $graph element create $n -mapy $n -symbol circle -pixels 1.5 -color $c
      $graph element bind $n <Enter> [list $graph yaxis use [list $n]]
      # hide element if needed
      if {$h} {xblt::hielems::toggle_hide $graph $n}
      # set data vectors for the element
      $graph element configure $n -xdata "$this:T" -ydata "$this:D$i"
    }


  }

  ##########################################################
  destructor {
    blt::vector destroy "$this:T"
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector destroy "$this:D$i" }
  }

  ##########################################################
  # clear plot
  method clear {} {
    "$this:T" delete 0:end
    for {set i 0} {$i < $ncols} {incr i} {
      "$this:D$i" delete 0:end }
  }

  ##########################################################
  # add data to plot
  method add_data {t data} {

    # add zeros to data if needed
    for {set i [llength $data]} {$i < $ncols} {incr i} {
      lappend data 0 }

    # add data to BLT vectors
    "$this:T" append $t
    for {set i 0} {$i < $ncols} {incr i} {
      "$this:D$i" append [lindex $data $i] }

    # remove old values:
    if {$maxn > 0 } {
      set dn [expr ceil($maxn*0.1)]
      if {["$this:T" length] > [expr {$maxn + $dn}]} {
        "$this:T" delete 0:$dn
        for {set i 0} {$i < $ncols} {incr i} {
          "$this:D$i" delete 0:$dn }
      }
    }

    # remove old values:
    if {$maxt > 0} {
      set dt [expr ceil($maxt*0.1)]
      set t2 [clock seconds]
      set t1 [expr {$t2-$maxt}]

      # remove old data if needed
      if {["$this:T" length]>0 && ["$this:T" index end] - ["$this:T" index 0] > $maxt+$dt} {
        set i 0
        for {set i 0} {$i<["$this:T" length]} {incr i} {
          if {["$this:T" index $i]>=$t1} {break}
        }
        if {$i>0} {
          "$this:T" delete 0:$i
          for {set i 0} {$i < $ncols} {incr i} {
            "$this:D$i" delete 0:$i }
        }
      }
    }
  }

}
