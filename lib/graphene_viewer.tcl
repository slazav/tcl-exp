package provide GrapheneViewer 1.0

package require Itcl
package require xBlt 3
package require Device2

namespace eval graphene {

######################################################################
itcl::class viewer {

  variable data_sources; # data source objects
  variable comm_source;  # comment source

  # widgets: root, plot, top menu, scrollbar:
  variable rwid
  variable graph
  variable mwid
  variable swid
  private variable goto_val {}

  variable maxwidth;  # max window size
  variable update_interval;

  ######################################################################

  constructor {} {
    set data_sources {}
    set comm_source {}
    set update_interval 1000
    set maxwidth     1500

    ### create and pack interface elements:
#    set rwid $root_widget
    set rwid {}
    if {$rwid ne {}} {frame $rwid}
    set graph $rwid.p
    set mwid $rwid.f
    set swid $rwid.sb

    ## upper menu frame
    frame $mwid
    button $mwid.exit -command "$this finish" -text Exit
    pack $mwid.exit -side right -padx 2
    pack $mwid -side top -fill x -padx 4 -pady 4

    ## autoupdate checkbutton
    checkbutton $mwid.autoupdate -text "Auto update" -variable autoupdate
    pack $mwid.autoupdate -side right -padx 2
    autoupdater #auto\
      -state_var ::autoupdate\
      -interval  $update_interval\
      -update_proc [list $this on_update]\

    ## goto window
    label $mwid.goto_l -text "Go to date: "
    entry $mwid.goto -width 20 -textvariable [itcl::scope goto_val]
    bind $mwid.goto <Return> [list $this goto_date {}]
    pack $mwid.goto   -side right -padx 2
    pack $mwid.goto_l -side right -padx 2

    ## scrollbar
    scrollbar $swid -orient horizontal
    pack $swid -side bottom -fill x

    ## set graph size
    set swidth [winfo screenwidth .]
    set graphth [expr {$swidth - 80}]
    if {$graphth > $maxwidth} {set graphth $maxwidth}

    ## main graph
    blt::graph $graph -width $graphth -height 600 -leftmargin 60
    pack $graph -side top -expand yes -fill both

    $graph legend configure -activebackground white

    # configure standard xBLT things:
    xblt::plotmenu   $graph -showbutton 1 -buttonlabel Menu -buttonfont {Helvetica 12} -menuoncanvas 0
    xblt::legmenu    $graph
    xblt::hielems    $graph
    xblt::crosshairs $graph -variable v_crosshairs
    xblt::measure    $graph
    xblt::readout    $graph -variable v_readout -active 1;
    xblt::zoomstack  $graph -scrollbutton 2 -axes x -recttype x
    xblt::elemop     $graph
    xblt::scroll     $graph $swid -on_change [list $this on_scroll] -timefmt 1

    ## range menu
    ## create xblt::rubberrect
    xblt::rubberrect::add $graph -type x -modifier Shift \
      -configure {-outline blue} \
      -invtransformx x\
      -command "$this show_rangemenu"\
      -cancelbutton ""
    $graph marker create polygon -name rangemarker -dashes 5 -fill "" \
        -linewidth 2 -mapx x -mapy xblt::unity -outline blue -hide 1
    set rangemenu [menu $graph.rangemenu -tearoff 0]
    bind $rangemenu <Unmap> [list $this on_rangemenu_close]
    $rangemenu add command -label "Zoom" -command [list $this on_range_zoom]
    $rangemenu add command -label "Save data to file" -command [list $this on_range_save]
    $rangemenu add command -label "Fit data"          -command [list $this on_range_fit]
    $rangemenu add separator
    $rangemenu add command -label "Delete data"       -command [list $this on_range_del_data]
    $rangemenu add command -label "Delete comments"   -command [list $this on_range_del_comm]

    bind . <Alt-Key-q>     "$this finish"
    bind . <Control-Key-q> "$this finish"
    wm protocol . WM_DELETE_WINDOW "$this finish"
  }

  destructor {
  }

  ######################################################################

  # add data source
  method add_data {conn name cols args} {

    set ds [DataSource #auto $conn $name $cols]
    # parse options

    set opts {
      -cnames  cnames  {}
      -ctitles ctitles {}
      -ccolors ccolors {}
      -cfmts   cfmts   {}
      -chides  chides  {}
      -clogs   clogs   {}
      -verbose verbose  1
    }
    if {[catch {xblt::parse_options "graphene::data_source" \
      $args $opts} err]} { error $err }

    set ncols [llength $cols]

    if {$verbose} {
      puts "Add data source \"$name\" with $ncols columns" }

    # create automatic column names
    for {set i [llength $cnames]} {$i < $ncols} {incr i} {
      lappend cnames "$name:[lindex $cols $i]" }

    # create automatic column titles
    for {set i [llength $ctitles]} {$i < $ncols} {incr i} {
      lappend ctitles "$name:[lindex $cols $i]" }

    # create automatic column colors
    set defcolors {red green blue cyan magenta yellow}
    for {set i [llength $ccolors]} {$i < $ncols} {incr i} {
      set c [lindex $defcolors [expr {$i%[llength $defcolors]} ] ]
      lappend ccolors $c }

    # create automatic format settings
    for {set i [llength $cfmts]} {$i < $ncols} {incr i} {
      lappend cfmts "%g" }

    # show all columns by default
    for {set i [llength $chides]} {$i < $ncols} {incr i} {
      lappend chides 0 }

    # non-log scale for all columns by default
    for {set i [llength $clogs]} {$i < $ncols} {incr i} {
      lappend clogs 0 }

    ## configure plot
    set vT [$ds get_tvector]
    for {set i 0} {$i < $ncols} {incr i} {
      set vD [$ds get_dvector $i]
      set n [lindex $cnames $i]
      set t [lindex $ctitles $i]
      set c [lindex $ccolors $i]
      set f [lindex $cfmts $i]
      set h [lindex $chides $i]
      set l [lindex $clogs $i]
      # create vertical axis and the element, bind them
      $graph axis create $n -title $t -titlecolor black -logscale $l
      $graph element create $n -mapy $n -symbol circle -pixels 1.5 -color $c
      $graph element bind $n <Enter> [list $graph yaxis use [list $n]]
      # hide element if needed
      if {$h} {xblt::hielems::toggle_hide $graph $n}
      # set data vectors for the element
      $graph element configure $n -xdata $vT -ydata $vD
      #
    }

#   $ds reset_data_info

    expand_range {*}[$ds range]
    lappend data_sources $ds
  }

  # add comment source
  method add_comm {args} {
    set comm_source [CommSource #auto $graph {*}$args]
    expand_range {*}[$comm_source range]
  }

  ## expand plot range
  method expand_range {min max} {
    set mino [$graph axis cget x -scrollmin]
    set maxo [$graph axis cget x -scrollmax]
    if {$min != {} && ($mino=={} || $mino > $min)} {
      $graph axis configure x -scrollmin $min
    } else {set min $mino}
    if {$max != {} && ($maxo=={} || $maxo < $max)} {
      $graph axis configure x -scrollmax $max
    } else {set max $maxo}
    # change scrollbal position
    if {$mino!={} && $maxo!={} && $min!={} && $max!={}} {
      set sb [$swid get]
      set sbmin [lindex $sb 0]
      set sbmax [lindex $sb 1]
      set sbmin [expr {($mino-$min + $sbmin*($maxo-$mino))/($max-$min)}]
      set sbmax [expr {($mino-$min + $sbmax*($maxo-$mino))/($max-$min)}]
      $swid set $sbmin $sbmax
    }
  }

  ## This function is called after zooming the graph.
  ## It loads data in a lazy way and do not update data limits.
  method on_scroll {x1 x2 t1 t2 w} {
    foreach d $data_sources { $d update_data $t1 $t2 $w }
    if {$comm_source!={}} { $comm_source update_data $t1 $t2 $w }
  }

  ## This function is called from autoupdater
  method on_update {} {
    # expand plot limits to the current time
    set now [expr [clock milliseconds]/1000.0]
    expand_range {} $now

    set ll [$graph axis limits x]
    set min [lindex $ll 0]
    set max [lindex $ll 1]
    set min [expr {$min + $now-$max}]
    set max $now
    $graph axis configure x -min $min -max $max

    # update data
    foreach d $data_sources { $d scroll_right $min $max }
    if {$comm_source!={}} { $comm_source scroll $min $max }

  }

  ## Zoom to full range
  method full_scale {} {
    set min [$graph axis cget x -scrollmin]
    set max [$graph axis cget x -scrollmax]
    $graph axis configure x -min $min -max $max -stepsize 0
  }

  ## goto year, month, day, hour
  method goto_date {date} {
    if {$date=={}} {set date $goto_val}
    if     {[ regexp {^\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}:\S+\d{1,2}} $date]} { set dt 60}\
    elseif {[ regexp {^\d{4}-\d{1,2}-\d{1,2}\s+\d{1,2}$} $date]} { set dt 3600}\
    elseif {[ regexp {^\d{4}-\d{1,2}-\d{1,2}$} $date]} { set dt [expr 24*3600]}\
    elseif {[ regexp {^\d{4}-\d{1,2}$} $date]} {set dt [expr 12*24*3600]; set date "$date-01"}\
    elseif {[ regexp {^\d{4}$} $date]} { set dt [expr 366*24*3600]; set date "$date-01-01"}\
    else { full_scale; return }
    set t1 [clock scan $date]
    puts "goto $t1 [expr $t1+$dt]"
    $graph axis configure x -min $t1 -max [expr $t1+$dt] -stepsize 0
  }

  ######################################################################
  ## range menu functions

  variable t1
  variable t2
  variable rangemenu
  method show_rangemenu {graph x1 x2 y1 y2} {
    set t1 $x1
    set t2 $x2
    $graph marker configure rangemarker -hide 0 -coords "$x1 0 $x1 1 $x2 1 $x2 0" 
    tk_popup $rangemenu [winfo pointerx .p] [winfo pointery .p]
  }

  method on_rangemenu_close {} {
    $graph marker configure rangemarker -hide 1
  }

  method on_range_zoom {} {
    $graph axis configure x -min $t1 -max $t2 -stepsize 0
  }

  method on_range_del_data {} {
    $graph marker configure rangemarker -hide 0
    if {[tk_messageBox -type yesno -message "Delete all data in the range?"] == "yes"} {
      foreach d $data_sources { $d delete_range $t1 $t2 }
    }
    $graph marker configure rangemarker -hide 1
  }

  method on_range_del_comm {} {
    $graph marker configure rangemarker -hide 0
    if {[tk_messageBox -type yesno -message "Delete all comments in the range?"] == "yes"} {
      if {$comm_source!={}} { $comm_source delete_range $t1 $t2 }
    }
    $graph marker configure rangemarker -hide 1
  }

  method on_range_save {} {
    $graph marker configure rangemarker -hide 0
    set fname [tk_getSaveFile]
    if {$fname != {}} {
      foreach d $data_sources { $d save_file ${fname}_${d} $t1 $t2 }
    }
    $graph marker configure rangemarker -hide 1
  }

  method on_range_fit {} {
    $graph marker configure rangemarker -hide 0
    foreach d $data_sources { puts [$d fit_data $t1 $t2] }
    $graph marker configure rangemarker -hide 1
  }

  ######################################################################

  method finish {} { exit }
}
}
