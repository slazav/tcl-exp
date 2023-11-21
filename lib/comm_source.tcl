package require Itcl
package require xBlt

# set graphene of text comment source,
# update data if needed.
#
# Options:
#   -name    - file/db name
#   -conn    - graphene connection for a database source
#   -verbose - be verbose
#
# File source:
#  comments: #, %, ;

itcl::class CommSource {
  # these variables are set from options (see above)
  variable name
  variable conn
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
      -verbose verbose  1
    }
    set graph $graph_
    if {[catch {xblt::parse_options "graphene::comment_source" \
      $args $opts} err]} { error $err }

    if {$verbose} {
      puts "Add comment source \"$name\"" }


    xblt::xcomments $graph -on_add [list $this on_add] -on_del [list $this on_del]

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

    if {$t1 >= $tmin && $t2 <= $tmax && $dt >= $maxdt} {return}
    if {$verbose} {
      puts "update_data $t1 $t2 $N $dt $name" }

    # expand the range:
    set t1 [expr {$t1 - ($t2-$t1)}]
    set t2 [expr {$t2 + ($t2-$t1)}]
    set tmin $t1
    set tmax $t2
    set maxdt $dt


    # clear comment data
    xblt::xcomments::clear $graph

    # add comments
    ## for a graphene db
    if {$conn ne {}} { ## graphene db

      foreach line [split [Device2::ask $conn get_range $name $t1 $t2 $dt] "\n"] {
        # append data to vectors
        set t [lindex $line 0]
        set text {}
        append text {*}[lrange $line 1 end]
        xblt::xcomments::create $graph $t $text
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
        set text {}
        append text {*}[lrange $line 1 end]
        xblt::xcomments::create $graph $t $text
      }
      close $fp
    }
  }

  ######################################################################
  method scroll {t1 t2} {
    set N [expr {int(($tmax-$tmin)/$maxdt)}]
    reset_data_info
    update_data $t1 $t2 $N
  }

  ######################################################################


  method on_add {t text} {
    if {$conn ne {}} { ## graphene db
      Device2::ask $conn put $name $t $text
      Device2::ask $conn sync
    } else {
    }
  }

  method on_del {t text} {
    if {$conn ne {}} { ## graphene db
      Device2::ask $conn del $name $t
      Device2::ask $conn sync
    } else {
    }
  }

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

  ######################################################################
}
