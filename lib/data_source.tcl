package require Itcl
package require xBlt
package require BLT
package require Device2

# Datasource: loading data from a text file of graphene database to
# blt vectors.
#
# File source: comments: #, %, ;

itcl::class DataSource {
  # these variables are set from options (see above)
  variable name
  variable conn
  variable cols
  variable ncols

  # currently loaded min/max/step
  variable tmin
  variable tmax
  variable maxdt

  ######################################################################

  constructor {conn_ name_ cols_} {
    set conn $conn_
    set name $name_
    set cols $cols_
    set ncols [llength $cols]

    # create BLT vectors for data (main/load)
    blt::vector create "$this:MT"
    blt::vector create "$this:LT"
    for {set i 0} {$i < $ncols} {incr i} {
      blt::vector create "$this:M$i"
      blt::vector create "$this:L$i"
    }
    reset_data_info
  }

  method get_tvector {}  {return $this:MT}
  method get_dvector {i} {return $this:M$i}

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
  ## get data range (without loading data)
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
  # load data to L vectors
  method _vec_load {t1 t2 dt} {

    # cleanup vectors
    if {["$this:LT" length] > 0} {"$this:LT" delete 0:end}
    for {set i 0} {$i < $ncols} {incr i} {
      if {["$this:L$i" length] > 0} {"$this:L$i" delete 0:end}
    }

    ## for a graphene db
    #puts "load data $t1 $t2 $dt"
    if {$conn ne {}} { ## graphene db
      foreach line [split [Device2::ask $conn get_range $name $t1 $t2 $dt] "\n"] {
        # append data to vectors
        "$this:LT" append [lindex $line 0]
        for {set i 0} {$i < $ncols} {incr i} {
          set v [lindex $line [expr [lindex $cols $i]+1]]
          if {![string is double $v] || $v != $v} {set v 0}
          "$this:L$i" append $v
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
        "$this:LT" append $t
        for {set i 0} {$i < $ncols} {incr i} {
          set v [lindex $line [expr [lindex $cols $i]+1]]
          if {![string is double $v] || $v != $v} {set v 0}
          "$this:L$i" append $v
        }
      }
      close $fp
    }
  }

  # In a sorted vector find index of the first value larger or equal then v
  method _vec_search_l {vec v} {
    if {[$vec length] < 1} {return -1}
    if {[blt::vector expr max($vec)] < $v} {return -1}
    if {[blt::vector expr min($vec)] > $v} {return 0}
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

  # remove old values from M vectors if they are too far from view range
  method _vec_cleanup {t1 t2} {
    set min [blt::vector expr min($this:MT)]
    set max [blt::vector expr max($this:MT)]
    set lim [expr {$t1 - ($t2-$t1)}]
    if {$min < $lim} {
      set ii [_vec_search_l $this:MT $lim]
      if {$ii>0} {
        #puts "cleanup left: $min,$lim"
        $this:MT delete 0:$ii-1
        for {set i 0} {$i < $ncols} {incr i} { $this:M$i delete 0:$ii-1}
      }
    }
    set lim [expr {$t2 + ($t2-$t1)}]
    if {$max > $lim} {
      set ii [_vec_search_l $this:MT $lim]
      if {$ii>0} {
        #puts "cleanup right: $lim,$max"
        $this:MT delete $ii:end
        for {set i 0} {$i < $ncols} {incr i} { $this:M$i delete $ii:end}
      }
    }
  }

  ######################################################################
  # update data:
  #   if loaded data covers time range, then do nothing
  #   otherwise load data for 3x expanded time range
  method update_data {t1 t2 N} {
    set dt [expr {1.0*($t2-$t1)/$N}]
    if {$tmin!=$tmax && $t1 >= $tmin && $t2 <= $tmax && $dt >= $maxdt} {return}

    # expand the range:
    if {$t1<$tmin} {set t1 [expr {$t1 - ($t2-$t1)}]}
    if {$t1<0} {set t1 0}
    if {$t2>$tmax} {set t2 [expr {$t2 + ($t2-$t1)}]}

    # scroll right
    if {$t1>=$tmin && $t2>$tmax && $dt == $maxdt} {
      _vec_load [$this:MT index end] $t2 $maxdt
      if {[$this:LT length]==0} {return}
      $this:MT append $this:LT
      for {set i 0} {$i < $ncols} {incr i} { $this:M$i append $this:L$i }
      _vec_cleanup $t1 $t2
      set tmin  $t1
      set tmax  $t2
      return
    }

    # scroll left
    if {$t1<$tmin && $t2<=$tmax && $dt == $maxdt} {
      _vec_load $t1 [$this:MT index 0] $maxdt
      if {[$this:LT length]==0} {return}
      $this:MT insert 0 [$this:LT range 0 end]
      for {set i 0} {$i < $ncols} {incr i} { $this:M$i insert 0 [$this:L$i range 0 end]}
      _vec_cleanup $t1 $t2
      set tmin  $t1
      set tmax  $t2
      return
    }

    _vec_load $t1 $t2 $dt
    $this:MT set $this:LT
    for {set i 0} {$i < $ncols} {incr i} { $this:M$i set $this:L$i }
    set tmin  $t1
    set tmax  $t2
    set maxdt $dt
  }

  ######################################################################
  method scroll_right {t1 t2} {
    _vec_load $tmax $t2 $maxdt
    _vec_cleanup $t1 $t2
  }

  ######################################################################
  # delete data in the database (only graphene!)
  method delete_range {t1 t2} {
    if {$conn ne {}} { ## graphene db
      Device2::ask $conn del_range $name $t1 $t2
      Device2::ask $conn sync
      # reread data
      set N [expr {int(($tmax-$tmin)/$maxdt)}]
      set tmin_ $tmin
      set tmax_ $tmax
      reset_data_info
      update_data $tmin_ $tmax_ $N
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
          if {[llength $line]<=[expr [lindex $cols $i]+1]} continue
          set val [lindex $line [expr [lindex $cols $i]+1]]

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
