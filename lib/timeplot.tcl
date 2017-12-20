# timeplot library

package require Device 1.3
package require xBlt
package require itcl


itcl::class TimePlot {
  # parameters /see options/
  # parameters /see options/
  variable ncols
  variable names
  variable titles
  variable colors
  variable hides
  variable logs
  variable fmts
  variable maxn
  variable maxt
  variable plots_x
  variable plots_y
  variable use_comm

  variable plot_type
  variable plot_types
  variable graph
  variable scroll

  ##########################################################
  constructor {plot args} {

    # Parse options.
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
    {-X -plots_x}  plots_x  {time}\
    {-Y -plots_y}  plots_y  {{}}\
    {-C -use_comm}  use_comm 0\
    ]
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
    # modes selection
    if {[llength $plots_x] > 0} {
      foreach x $plots_x y $plots_y {
        if {$y == {}} { lappend plot_types "all vs. $x" }\
        else { lappend plot_types "[join $y {, }] vs. $x" }
      }
      set plot_type [lindex $plot_types 0]
    } else {error "not enough plot types"}
    if {[llength $plot_types] > 1} {
      ttk::combobox $plot.modes -width 12\
          -textvariable [itcl::scope plot_type]\
          -values $plot_types
      pack $plot.modes -side left -padx 4
      bind $plot.modes <<ComboboxSelected>> "$this setup_plot"
    }
    # hystory entries
    if {$maxt > 0} {
      label $plot.mtl -text "History length, s:"
      entry $plot.mt -textvariable [itcl::scope maxt] -width 8
      pack $plot.mtl $plot.mt -side left -padx 2
    }
    if {$maxn > 0} {
      label $plot.mtl -text "History length, pts:"
      entry $plot.mt -textvariable [itcl::scope maxt] -width 8
      pack $plot.mtl $plot.mt -side left -padx 2
    }

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

    if {$use_comm == 1} {xblt::xcomments $graph}

    # create BLT vectors for data, create axis for each data column
    blt::vector create "$this:T"
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector create "$this:D$i"
      set t [lindex $titles $i]
      set n [lindex $names $i]
      set l [lindex $logs $i]
      $graph axis create $n -title $t -titlecolor black -logscale $l
    }

    setup_plot
  }

  ##########################################################
  destructor {
    blt::vector destroy "$this:T"
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector destroy "$this:D$i" }
  }

  ##########################################################
  # change plot type
  method setup_plot {} {

    # find plot type in plot_types list
    set n [lsearch -exact $plot_types $plot_type]
    if {$n == -1 } {error "Badly formed plot_types: $plot_types"}

    # what is x-axis?
    set x  [lindex $plots_x $n]; # name
    set ix [lsearch -exact $names $x]; # columns number (-1 for time)
    if {$ix == -1 && $x != "time"} {error "Bad column name in plot_x: $x"}

    # xBLT hacks
    set xblt::zoomstack::data($graph,axes) [expr {$x == "time"?"x":"x y"}]
    set xblt::rubberrect::data($graph,rr1,usey) [expr {$x == "time"?0:1}]
    set xblt::scroll::data($graph,timefmt) [expr {$x == "time"?1:0}]
    xblt::zoomstack::unzoom $graph
    if {$x != "time"} {
      $graph axis configure x -stepsize 0 -subdivisions 0 -majorticks "" -command ""\
                               -title [lindex $titles $ix]\
                               -titlecolor black\
                               -logscale [lindex $logs $ix]

    }

    # delete all elements
    foreach e [$graph element names *] {
      $graph element delete $e }

    # set up BLT plot
    set yy [lindex $plots_y $n]; # y columns
    if {[llength $yy] == 0} {set yy $names}
    foreach y $yy {
      set iy [lsearch -exact $names $y]; # column number
      if {$iy == -1 } {error "Bad column name in plot_y: $y"}
      if {$iy == $ix} {continue}
      # column parameters
      set n [lindex $names $iy]
      set c [lindex $colors $iy]
      set h [lindex $hides $iy]
      $graph element create $n -mapy $n -symbol circle -pixels 1.5 -color $c
      if {$x == "time"} {
        # For time plot we need a separate axis for each element
        $graph element bind $n <Enter> [list $graph yaxis use [list $n]]
        # set data vectors for the element
        $graph element configure $n -xdata "$this:T" -ydata "$this:D$iy" -mapy $n
      } else {
        $graph element bind $n <Enter> {}
        # set data vectors for the element
        $graph element configure $n -xdata "$this:D$ix" -ydata "$this:D$iy" -mapy y
      }
      # hide element if needed
      if {$h} {xblt::hielems::toggle_hide $graph $n}
    }
  }

  ##########################################################
  # clear plot
  method clear {} {
    if {["$this:T" length] > 0} { "$this:T" delete 0:end }
    for {set i 0} {$i < $ncols} {incr i} {
      if {["$this:D$i" length] > 0} { "$this:D$i" delete 0:end }
    }
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
        for {set n 0} {$n<["$this:T" length]} {incr n} {
          if {["$this:T" index $n]>=$t1} {break} }
        if {$n>0} {
          "$this:T" delete 0:$n
          for {set i 0} {$i < $ncols} {incr i} {
            "$this:D$i" delete 0:$n }
        }
      }
    }

    # remove old comments:
    if {["$this:T" length]>0} {
      xblt::xcomments::delete_range $graph 0 ["$this:T" index 0]
    }

  }

  ##########################################################
  # add comments
  method add_comment {t com} {
    if {$use_comm == 0} {return}
    xblt::xcomments::create $graph $t $com
  }

  ##########################################################
  # get time/data vectors names
  method get_tvec {} { return "$this:T" }
  method get_dvec {i} { return "$this:D$i" }
}
