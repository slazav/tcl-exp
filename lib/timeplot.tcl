# timeplot library

package require xBlt 3.1
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
  variable symbols
  variable ssizes
  variable fmts
  variable maxn
  variable maxt
  variable plots_x
  variable plots_y
  variable zstyles
  variable use_comm
  variable use_marker
  variable separate

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
    {-s -symbols}  symbols  {}\
    {-z -ssizes}   ssizes   {}\
    {-N -maxn}     maxn     0\
    {-T -maxt}     maxt     0\
    {-X -plots_x}  plots_x  {time}\
    {-Y -plots_y}  plots_y  {{}}\
    {-Z -zstyles}  zstyles  {x}\
    {-C -use_comm}   use_comm 0\
    {-M -use_marker} use_marker 0\
    {-separate}    separate 0\
    ]
    xblt::parse_options "timeplot" $args $options

    # Check that ncols>0 and titles and colors have enough values
    if {$ncols<=0} {error "timeplot: ncols should be > 0: $ncols"}

    # create automatic column names
    for {set i [llength $names]} {$i < $ncols} {incr i} {
      lappend names "data-$i" }

    # create automatic column titles if needed
    for {set i [llength $titles]} {$i < $ncols} {incr i} {
      lappend titles [lindex $names $i] }

    # create automatic column colors if needed
    set defcolors {red green blue cyan magenta yellow\
      darkred darkgreen darkblue darkcyan darkmagenta black}
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

    # xy zoom style for all columns by default
    for {set i [llength $zstyles]} {$i < $ncols} {incr i} {
      lappend zstyles xy }

    # empty symbols by default
    for {set i [llength $symbols]} {$i < $ncols} {incr i} {
      lappend symbols {} }

    # symbol size 1.5 by default
    for {set i [llength $ssizes]} {$i < $ncols} {incr i} {
      lappend ssizes 1.5 }

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
    button $plot.clear -command "$this clear" -text Clear -height 1
    pack $plot.clear -side right -padx 2
    # modes selection
    if {[llength $plots_x] > 0} {
      foreach x $plots_x y $plots_y {
        if {$y == {}} { lappend plot_types "all vs. $x" }\
        else { lappend plot_types "[join $y {, }] vs. $x" }
      }
      set plot_type [lindex $plot_types 0]
    } else {error "not enough plot types"}
    if {[llength $plot_types] > 1 && !$separate} {
      ttk::combobox $plot.modes -width 12\
          -textvariable [itcl::scope plot_type]\
          -values $plot_types
      pack $plot.modes -side left -padx 4
      bind $plot.modes <<ComboboxSelected>> "$this setup_plot"
    }
    # history entries
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

    # set up xBLT things valid for all plot types
    xblt::plotmenu   $graph -showbutton 1 -buttonlabel Menu -buttonfont {Helvetica 12} -menuoncanvas 0
    xblt::legmenu    $graph
    xblt::hielems    $graph
    xblt::crosshairs $graph -variable v_crosshairs
    xblt::measure    $graph
    xblt::readout    $graph -variable v_readout -active 1;
    xblt::scroll     $graph $scroll -timefmt 1
    xblt::zoomstack  $graph -scrollbutton 2 -axes x -recttype x
    xblt::elemop     $graph

    if {$use_comm == 1} {
      xblt::xcomments $graph -interactive 0 -show_x 1\
                             -time_fmt "%Y-%m-%d %H:%M:%S"
    }

    # Create BLT vectors for data, create axis for each data column:
    #   separate mode vectors: T0,D0, T1,D1, etc.
    #   normal mode vectors: T,D0,D1, etc.
    if {!$separate} {blt::vector create "$this:T"}
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector create "$this:D$i"
      if {$separate} {blt::vector create "$this:T$i"}
      set t [lindex $titles $i]
      set n [lindex $names $i]
      set c [lindex $colors $i]
      set l [lindex $logs $i]
      set s [lindex $symbols $i]
      set ss [lindex $ssizes $i]

      # For each column <n> we create axes <n> and x<n>.
      # In separate and normal modes x<n> has different meaning:
      #   normal: it is used when data is plotted as a function of this column
      #   separate: it is time axis used for this dataset
      $graph axis create $n -title $t -titlecolor black -logscale $l
      $graph element create $n -symbol $s -pixels $ss -color $c -mapy $n
      if {$separate} {
        $graph axis create x$n
      }\
      else {
        $graph axis create x$n -title $t -titlecolor black -logscale $l
      }

      if {$use_marker} {
        $graph marker create text -font {helvetica 16} -text *\
          -yoffset 4 -name $n -element $n -outline $c
      }
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
    set i [lsearch -exact $plot_types $plot_type]
    if {$i == -1 } {error "Badly formed plot_types: $plot_types"}

    # Reset all elements.
    foreach n [$graph element names *] { $graph element configure $n -hide 1 -label {} }

    # what is x-axis?
    set x  [lindex $plots_x $i]; # name
    set ix [lsearch -exact $names $x]; # columns number (-1 for time)
    if {$ix == -1 && $x != "time"} {error "Bad column name in plot_x: $x"}
    set xaxis [expr {$x == "time"? "x":"x$x"}]
    $graph xaxis use $xaxis

    # zoom style
    # xy - zoom both axes
    # x - zoom only x axis, drag plots in y independently
    set zstyle  [lindex $zstyles $i];
    if {$zstyle == {xy}} {
      xblt::zoomstack  $graph -usemenu 0 -scrollbutton 2 -axes "$xaxis y" -recttype xy
    }\
    else {
      xblt::zoomstack  $graph -usemenu 0 -scrollbutton 2 -axes $xaxis -recttype x
      xblt::elemop     $graph
    }

    # comments are shown only on time plot
    if {$use_comm} {
      if {$x == "time"} {xblt::xcomments::show_all $graph}\
      else { xblt::xcomments::hide_all $graph }
    }

    # xBLT hacks
    #set xblt::zoomstack::data($graph,axes) [expr {$x == "time"?"x":"x y"}]
    #set xblt::rubberrect::data($graph,rr1,usey) [expr {$x == "time"?0:1}]
    #xblt::zoomstack::unzoom $graph

    # set up BLT plot
    set yy [lindex $plots_y $i]; # y columns
    if {[llength $yy] == 0} {set yy $names}
    foreach y $yy {
      set iy [lsearch -exact $names $y]; # column number
      if {$iy == -1 } {error "Bad column name in plot_y: $y"}
      if {$iy == $ix} {continue}; # no need to plot X vs. X
      # column parameters
      set h [lindex $hides $iy]
      # configure xdata and show element
      if {$separate} {
        set xdata "$this:T$iy"
      } else {
        set xdata [expr {$x == "time"? "$this:T":"$this:D$ix"}]
      }
      # for xy zoom style all elements should be mapped to axis y
      set yaxis [expr {$zstyle == {xy}? "y":"$y"}]
      $graph element configure $y -hide 0 -label $y\
              -xdata $xdata -ydata "$this:D$iy" -mapx $xaxis -mapy $yaxis

      # in non-xy mode axis should change when entering the element
      if {$zstyle == {xy}} {
        $graph element bind $y <Enter> {}
      }\
      else {
        $graph element bind $y <Enter> [list $graph yaxis use [list $y]]
      }

      # hide element if needed
      if {$h} {xblt::hielems::toggle_hide $graph $y}
    }

    # what is y axis?
    # in x zoom style use 1st element's axis (when it can be switched by user)
    if {$zstyle == {xy}} { $graph yaxis use y }\
    else {$graph yaxis use [lindex $yy 0] }
  }

  ##########################################################
  # clear plot
  method clear {} {
    if {!$separate && ["$this:T" length] > 0} { "$this:T" delete 0:end }
    for {set i 0} {$i < $ncols} {incr i} {
      if {$separate && ["$this:D$i" length] > 0} { "$this:T$i" delete 0:end }
      if {["$this:D$i" length] > 0} { "$this:D$i" delete 0:end }
    }
  }

  ##########################################################
  # add data to plot
  method add_data {data} {

    if {$separate} {error "can't use add_data in separate mode, use add_data_sep instead"}

    # add zeros to data if needed
    for {set i [llength $data]} {$i < [expr $ncols+1]} {incr i} {
      lappend data 0 }

    # add data to BLT vectors
    "$this:T" append [lindex $data 0]
    for {set i 0} {$i < $ncols} {incr i} {
      "$this:D$i" append [lindex $data [expr $i+1]] }

    # reconfigure markers for all columns
    update_markers $names

    # remove old values:
    set dvecs {}
    for {set i 0} {$i < $ncols} {incr i} {append dvecs "$this:D$i"}
    clean_old_values "$this:T" $dvecs

  }

  ##########################################################
  # add data to plot in separate mode
  method add_data_sep {col tstamp value} {


    if {!$separate} {error "can't use add_data_sep in normal mode, use add_data instead"}

    # column number
    set nc [lsearch -exact $names $col];
    if {$nc <0} {error: "add_data_sep: unknown column name: $col. Use one of ($names)"}

    # add data to BLT vectors
    "$this:T$nc" append $tstamp
    "$this:D$nc" append $value

    # reconfigure marker for this column
    update_markers $col

    # remove old values:
    clean_old_values "$this:T$nc" "$this:D$nc"

  }

  ##########################################################
  ## remove old values
  method clean_old_values {tvec dvecs} {

    # remove old values:
    if {$maxn > 0 } {
      set dn [expr ceil($maxn*0.1)]
      if {[$tvec length] > [expr {$maxn + $dn}]} {
        $tvec delete 0:$dn
        foreach dvec $dvecs { $dvec delete 0:$dn }
      }
    }

    # remove old values:
    if {$maxt > 0} {
      set dt [expr ceil($maxt*0.1)]
      set t2 [clock seconds]
      set t1 [expr {$t2-$maxt}]

      # remove old data if needed
      if {[$tvec length]>0 && [$tvec index end] - [$tvec index 0] > $maxt+$dt} {
        for {set n 0} {$n<[$tvec length]} {incr n} {
          if {[$tvec index $n]>=$t1} {break} }
        if {$n>0} {
          $tvec delete 0:$n
          foreach dvec $dvecs { $dvec delete 0:$n }
        }
      }
    }

    # remove old comments:
    if {[$tvec length]>0} {
      xblt::xcomments::delete_range $graph 0 [$tvec index 0]
    }
  }

  ##########################################################
  # reconfigure markers
  method update_markers {columns} {
    if {!$use_marker} return
    foreach n $columns {
      set ax [$graph element cget $n -mapx]
      set ay [$graph element cget $n -mapy]
      set x [[$graph element cget $n -xdata] index end]
      set y [[$graph element cget $n -ydata] index end]
      $graph marker configure $n -coords [list $x $y]\
        -mapx $ax -mapy $ay
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
  method get_tvec  {{i 0}} {
    if {$separate} { return "$this:T$i" }\
    else {return "$this:T"}
  }
  method get_dvec  {i} { return "$this:D$i" }
  method get_graph {} { return $graph }

  method get_data {} {
    if {$separate} {
      for {set n 0} {$n < $ncols} {incr n} {
        set Tlength ["$this:T$n" length]
        set data "# time,s  [lindex $names $n]\n"
        for {set i 0} {$i < $Tlength} {incr i} {
          append data ["$this:T$n" index $i] " " ["$this:D$n" index $i] "\n"
        }
      }
    } else {
      set Tlength ["$this:T" length]
      set data "# time,s  "
      append data $names
      for {set i 0} {$i < $Tlength} {incr i} {
        append data "\n" ["$this:T" index $i]
        for {set n 0} {$n < $ncols} {incr n} {
          append data " "  ["$this:D$n" index $i]
        }
      }
    }
    return $data
  }
}
