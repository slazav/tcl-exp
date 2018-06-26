## Manual DB interface
#############################################################
## Arguments for constructor:
# -dbdev  -- database device
# -dbname -- database name
# -func_mkint -- function for making data interface
#                (takes tk frame address as argument, returns nothing)
# -func_get   -- function for extracting data from the interface
#                (no no arguments, returns data list)
# -func_set   -- function for putting data to the interface
#                (takes data list as argument, returns nothing)
# -func_fmt   -- function for formatting text version of the data
#                (takes data list as argument, returns a string representation of the data)
# -num   -- number of records to show

package require itcl
package require xBlt
package require Device

itcl::class manual_db {
  # parameters /see options/
  variable dbdev;
  variable dbname;
  variable func_mkint;
  variable func_get;
  variable func_set;
  variable func_fmt;
  variable num;
  variable tstamp;

  variable lst; # data list

  ##########################################################

  variable text; # variable for default mkint function

  # Default mkint function with a single text entry.
  # gets frame adress
  method func_mkint_text {root} {
    label $root.text_l -text "Text:" -width 12 -anchor w
    entry $root.text -textvariable [itcl::scope text]
    grid  $root.text_l $root.text -sticky we
  }

  # Default function for getting data
  method func_get_text {} {
    set v [itcl::scope text]
    return [set $v]
  }

  # Default function for setting data
  method func_set_text {data} {
    set text [lindex $data 0]
  }

  # Default function for setting data
  method func_fmt_text {data} {
    return $data
  }

  ##########################################################

  # constructor
  constructor {args} {

    # Parse options.
    set options [list\
      {-dbdev}      dbdev      {}\
      {-dbname}     dbname     {}\
      {-func_mkint} func_mkint func_mkint_text\
      {-func_get}   func_get   func_get_text\
      {-func_set}   func_set   func_set_text\
      {-func_fmt}   func_fmt   func_fmt_text\
      {-num}        num        10\
    ]
    xblt::parse_options "manual_db" $args $options

    # make interface
    ## title
    label .name  -text "Add comments to $dbname" -font {-size 12} -anchor w
    grid .name -columnspan 2 -sticky w
    grid columnconfigure . 1 -weight 1

    ## timestamp entry
    label .tstamp_l  -text "Timestamp:" -width 12 -anchor w
    entry .tstamp    -textvariable [itcl::scope tstamp]
    grid  .tstamp_l .tstamp -sticky we

    ## data entry
    frame .data
    $func_mkint .data
    grid .data -columnspan 2 -sticky w

    ## button frame1
    frame .f1
    grid .f1 -columnspan 2 -sticky ew

    button .f1.new_btn -text "Add new" -command "$this on_add" -width 6
    button .f1.mod_btn -text "Modify"  -command "$this on_mod" -width 6 -state disabled
    button .f1.del_btn -text "Delete"  -command "$this on_del" -width 6 -state disabled
    grid .f1.new_btn .f1.mod_btn .f1.del_btn -sticky ew

    ## recent comment list
    listbox .lb -selectmode browse -height $num -width 70 -exportselection 0
    grid .lb -columnspan 2 -sticky we
    bind .lb <<ListboxSelect>> "$this on_sel %W"
    .lb insert 0 "<add new>"

    ## button frame2
    frame .f2
    grid .f2 -columnspan 2 -sticky ew

    #button .f2.l_btn -text "<"        -command on_l -width 6  -state disabled
    button .f2.res_btn -text "Reread"  -command "$this on_reset" -width 6
    #button .f2.r_btn -text ">"        -command on_r -width 6  -state disabled
    #grid .f2.l_btn .f2.res_btn .f2.r_btn
    grid .f2.res_btn
    on_reset
  }

  ##########################################################
  #### button actions

  ## reread data
  method on_reset {} {
    Device $dbdev
    # update listbox
    set t {}
    for {set i 1} {$i<$num} {incr i} {
      set r [lindex [$dbdev cmd get_prev $dbname $t] 0]
      if {$r=={}} {break}
      set t [lindex $r 0]
      set v [$func_fmt [lrange $r 1 end]]
      set ts [clock format [expr int($t)] -format "%Y-%m-%d %H:%M:%S"]
      if {$i < [.lb size]} {.lb delete $i}
      .lb insert $i "$ts $v"
      set lst($i) $t
      set t "$t-"; # it will be passed to $dbdev command
    }
    itcl::delete object $dbdev

    # reset it to <add new> entry
    #  Note: on_sel opens the DB
    .lb selection set 0
    .lb activate 0
    on_sel .lb
  }

  method on_add {} {
    set v [$func_get]
    if {$v=={} || $tstamp=={}} return
    set nt [exec date -d "$tstamp" +%s]
    Device $dbdev
    $dbdev cmd put $dbname $nt $v
    itcl::delete object $dbdev
    on_reset
  }

  method on_mod {} {
    set i [.lb curselection]
    set t $lst($i)
    set nt [exec date -d "$tstamp" +%s]
    Device $dbdev
    $dbdev cmd del $dbname $t
    $dbdev cmd put $dbname $nt [$func_get]
    itcl::delete object $dbdev
    .lb delete $i
    on_reset
  }

  method on_del {} {
    set i [.lb curselection]
    .lb selection set 0
    .lb activate 0
    .lb delete $i
    set t $lst($i)

    Device $dbdev
    $dbdev cmd del $dbname $t
    itcl::delete object $dbdev

    on_reset
  }


  method on_sel {w} {
    # update time and text from the database
    set i [$w curselection]

    if {$i=={}} { return }

    if {$i!=0} {
      set t $lst($i)

      Device $dbdev
      set r [lindex [$dbdev cmd get_prev $dbname $t] 0]
      itcl::delete object $dbdev

      set t [lindex $r 0]
      $func_set [lrange $r 1 end]
      set tstamp [clock format [expr int($t)] -format "%Y-%m-%d %H:%M:%S"]
      .f1.new_btn configure -state disabled
      .f1.mod_btn configure -state active
      .f1.del_btn configure -state active
    }\
    else {
      set tstamp "now"
      $func_set {}
      .f1.new_btn configure -state active
      .f1.mod_btn configure -state disabled
      .f1.del_btn configure -state disabled
    }
  }

}



