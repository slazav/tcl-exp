package require Itcl
package require xBlt
package require BLT

# set graphene or text data source,
# update BLT vectors if needed.
#
# Options:
#   -name    - file/db name
#   -conn    - graphene connection for a database source
#   -ncols   - number of data columns (time column is not included)
#   -cnames  - list of unique names for all data columns (time is not included)
#   -ctitles - list of titles for all data columns
#   -ccolors - list of colors for all data columns
#   -cfmts   - list of format settings for all data columns
#   -chides  - list of hide settings for all data columns
#   -clogs   - list of logscale settings for all data columns
#   -verbose - be verbose
#
# File source:
#  comments: #, %, ;

itcl::class DataSource {
  # these variables are set from options (see above)
  variable name
  variable conn
  variable ncols
  variable cnames
  variable ctitles
  variable ccolors
  variable cfmts
  variable chides
  variable clogs
  variable verbose

  # currently loaded min/max/step
  variable tmin
  variable tmax
  variable maxdt

  variable graph

  ######################################################################

  constructor {graph_ args} {
    # parse options
    set opts {
      -name    name    {}
      -conn    conn    {}
      -ncols   ncols    1
      -cnames  cnames  {}
      -ctitles ctitles {}
      -ccolors ccolors {}
      -cfmts   cfmts   {}
      -chides  chides  {}
      -clogs   clogs   {}
      -verbose verbose  1
    }
    set graph $graph_
    if {[catch {xblt::parse_options "graphene::data_source" \
      $args $opts} err]} { error $err }

    if {$verbose} {
      puts "Add data source \"$name\" with $ncols columns" }

    # create automatic column names
    for {set i [llength $cnames]} {$i < $ncols} {incr i} {
      lappend cnames "$name:$i" }

    # create automatic column titles
    for {set i [llength $ctitles]} {$i < $ncols} {incr i} {
      lappend ctitles "$name:$i" }

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

    # create BLT vectors for data
    blt::vector create "$this:T"
    for {set i 0} {$i < $ncols} {incr i} {
      set n [lindex $cnames $i]
      blt::vector create "$this:$i"
    }

    ## configure plot
    for {set i 0} {$i < $ncols} {incr i} {
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
      $graph element configure $n -xdata "$this:T" -ydata "$this:$i"
      #
    }
    reset_data_info
  }

  ######################################################################
  # functions for reading files:

  # split columns
  method split_line {l} {
    # skip comments
    if {[regexp {^\s*[%#;]} $l]} {return {}}
    return [regexp -all -inline {\S+} $l]
  }

  # get next data line for the file position in the beginning of a line
  method get_line {fp} {
    while {[gets $fp line] >= 0} {
      set sl [split_line $line]
      if {$sl ne {}} { return $sl }
    }
    return {}
  }

  # get prev/next data line for an arbitrary file position
  method get_prev_line {fp} {
    while {[tell $fp] > 0} {
      # go one line back
      while { [read $fp 1] ne "\n" } { seek $fp -2 current }
      set pos [tell $fp]
      set sl [split_line [gets $fp]]
      if {$sl ne {}} { return $sl }\
      else { seek $fp [expr {$pos-2}] start }
    }
    return {}
  }
  method get_next_line {fp} {
    # find beginning of a line
    if { [tell $fp]>0 } {
       seek $fp -1 current
       while { [read $fp 1] ne "\n" } {}
    }
    return [get_line $fp]
  }

  ######################################################################
  ## call this if you want to update data even if it was loaded already
  method reset_data_info {} {
    set tmin 0
    set tmax 0
    set maxdt 0
  }

  ######################################################################
  ## get data range
  method range {} {
    if {$conn ne {}} { ## graphene db
       set tmin0 [lindex [Device2::ask $conn get_next $name] 0 0]
       set tmax0 [lindex [Device2::ask $conn get_prev $name] 0 0]
    } else { ## file
      set fp [open $name r ]
      set tmin0 [lindex [get_next_line $fp] 0]
      seek $fp 0 end
      set fsize [tell $fp]
      set tmax0 [lindex [get_prev_line $fp] 0]
      close $fp
    }
    return [list $tmin0 $tmax0]
  }

  ######################################################################
  # update data
  method update_data {t1 t2 N} {
    set dt [expr {1.0*($t2-$t1)/$N}]
    if {$tmin!=$tmax && $t1 >= $tmin && $t2 <= $tmax && $dt >= $maxdt} {return}
    if {$verbose} {
      puts "update_data $t1 $t2 $N $dt $name" }

    # expand the range:
    set t1 [expr {$t1 - ($t2-$t1)}]
    if {$t1<0} {set t1 0}
    set t2 [expr {$t2 + ($t2-$t1)}]
    set tmin $t1
    set tmax $t2
    set maxdt   $dt

    # reset data vectors
    if {["$this:T" length] > 0} {"$this:T" delete 0:end}
    for {set i 0} {$i < $ncols} {incr i} {
      if {["$this:$i" length] > 0} {"$this:$i" delete 0:end}
    }

    ## for a graphene db
    if {$conn ne {}} { ## graphene db

      foreach line [split [Device2::ask $conn get_range $name $t1 $t2 $dt] "\n"] {
        # append data to vectors
        "$this:T" append [lindex $line 0]
        for {set i 0} {$i < $ncols} {incr i} {
          set v [lindex $line [expr $i+1]]
          if {![string is double $v] || $v != $v} {set v 0}
          "$this:$i" append $v
        }
      }

    ## for a text file
    } else {

      # open and read the file line by line
      set fp [open $name r ]
      set to {}
      while { [gets $fp line] >= 0 } {

        # skip comments
        set line [ split_line $line ]
        if {$line == {}} {continue}

        # check the range
        set t [lindex $line 0]
        if {$t < $t1 || $t > $t2 } {continue}
        if {$to ne {} && $t-$to < $dt} {continue}
        set to $t

        # append data to vectors
        "$this:T" append $t
        for {set i 0} {$i < $ncols} {incr i} {
          "$this:$i" append [lindex $line [expr $i+1]]
        }
      }
      close $fp
    }
  }

  ######################################################################
  method delete_range {t1 t2} {
    if {$conn ne {}} { ## graphene db
      Device2::ask $conn del_range $name $t1 $t2
      Device2::ask $conn sync
      # reread data
      set N [expr {int(($tmax-$tmin)/$maxdt)}]
      reset_data_info
      update_data $tmin $tmax $N
    }
  }

  # In a sorted vector find index of the first value larger or equal then v
  method svec_search_l {vec v} {
    if {[$vec length] < 1} {return -1}
    if {[blt::vector expr max($this:T)] < $v} {return -1}
    if {[blt::vector expr min($this:T)] > $v} {return 0}
    set i1 0
    set i2 [expr [$vec length]-1]
    while {$i2-$i1 > 1} {
      set i [expr {int(($i2+$i1)/2)}]
      set val [$vec index $i]
      if {$val == $v} {return $i}
      if {$val > $v} {set i2 $i} else {set i1 $i}
    }
    return $i2
  }

  ######################################################################
  method scroll {t1 t2} {

    #get first and last timestamps in our vectors
    set min [blt::vector expr min($this:T)]
    set max [blt::vector expr max($this:T)]

    if {$conn ne {}} { ## graphene db
      foreach line [split [Device2::ask $conn get_range $name $max $t2 $maxdt] "\n"] {
        set t [lindex $line 0]
        if {t==$max} continue; # no need to insert existing value
        # append data to vectors
        "$this:T" append [lindex $line 0]
        for {set i 0} {$i < $ncols} {incr i} {
          "$this:$i" append [lindex $line [expr $i+1]]
        }
      }
    }

    # remove old values if it is more then tice longer then needed
    if {$t1-$min > $t2-$t1} {
      set ii [svec_search_l $this:T $t1]
      if {$ii>0} {
        $this:T delete 0:$ii-1
        for {set i 0} {$i < $ncols} {incr i} { $this:$i delete 0:$ii-1}
      }
    }

  }

  ######################################################################
  ## save all data in the range to a file
  method save_file {fname t1 t2} {
    set fp [::open $fname w]
    puts $fp "# time, [join $cnames {, }]"

    if {$conn ne {}} { ## graphene db
      foreach line [split [Device2::ask $conn get_range $name $t1 $t2] "\n"] {
        puts $fp $line
      }
    }
    close $fp
  }

  ######################################################################
  ## fit all data in the range

  ## now only mean value is calculated
  method fit_data {t1 t2} {

    set t0 {};   # "zero time"
    if {$conn ne {}} { ## graphene db
      foreach line [split [Device2::ask $conn get_range $name $t1 $t2] "\n"] {
        # get time point
        if {[llength $line]<1} continue
        set t [lindex $line 0]

        # save initial value if needed, subtract it from all data points
        if {$t0=={}} { set t0 $t }
        set t [expr {$t-$t0}]

        for {set i 0} {$i<$ncols} {incr i} {
          # get data point
          if {[llength $line]<=[expr $i+1]} continue
          set val [lindex $line [expr $i+1]]

          # save initial value if needed, subtract it from all data points
          if {![info exists val0($i)]} { set val0($i) $val }
          set val [expr {$val-$val0($i)}]

          # add value to sum
          if {![info exists sum0($i)]} { set sum0($i) $val }\
          else { set sum0($i) [expr {$val+$sum0($i)}] }

          # add 1 to num
          if {![info exists num0($i)]} { set num0($i) 1 }\
          else { incr num0($i) }
        }
      }
    }
    set res {}
    for {set i 0} {$i<$ncols} {incr i} {
      if {[info exists val0($i)] &&\
          [info exists sum0($i)] &&\
          [info exists num0($i)]} {
        lappend res [expr {1.0*$sum0($i)/$num0($i)+$val0($i)}]
      }\
      else { lappend res NaN }
    }
    return $res
  }


  ######################################################################
  method get_ncols {} { return $ncols }
}
