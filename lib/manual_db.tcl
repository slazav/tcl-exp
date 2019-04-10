## Manual DB interface
##
## Manually insert some data to graphene database.
## By default works with text databases, but can be also used
## for any numerical values. Then three methods should be redefined:
## - func_mkint <root> -- creats a form for values in <root> tk widget
## - func_get          -- extracts data from the form
## - func_set <data>   -- fills the form from data
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
# -num        -- number of records to show
# -list_size  -- list size (it will be a scrollbar if list_size < num)

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
  variable list_size;
  variable tstamp;
  variable listbox

  variable lst; # data list

  ##########################################################

  variable text; # variable for default mkint function

  # Default mkint function with a single text entry.
  # gets frame adress
  method func_mkint_text {root} {
    label $root.text_l -text "Text:" -width 12 -anchor w
    entry $root.text -textvariable [itcl::scope text]
    grid  $root.text_l $root.text -sticky we
    grid columnconfigure $root 1 -weight 1
  }

  # Default function for getting data
  method func_get_text {} {
    set v [itcl::scope text]
    return [set $v]
  }

  # Default function for setting data
  method func_set_text {data} {
    set text $data
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
      {-list_size}  list_size  10\
    ]
    xblt::parse_options "manual_db" $args $options

    # make interface
    ## title
    label .name  -text "Add comments to $dbname" -font {-size 12} -anchor w
    grid .name -columnspan 3 -sticky w
    grid columnconfigure . 1 -weight 1

    ## timestamp entry
    label  .tstamp_l  -text "Timestamp:" -width 12 -anchor w
    entry  .tstamp    -textvariable [itcl::scope tstamp]
    button .tstamp_b  -text "Update" -command "$this on_update_time" -width 6
    grid   .tstamp_l .tstamp .tstamp_b -sticky we

    ## data entry
    frame .data
    $func_mkint .data
    grid .data -columnspan 3 -sticky we

    ## button frame1
    frame .f1
    grid .f1 -columnspan 3 -sticky we

    button .f1.new_btn -text "Add new" -command "$this on_add" -width 6
    button .f1.mod_btn -text "Modify"  -command "$this on_mod" -width 6 -state disabled
    button .f1.del_btn -text "Delete"  -command "$this on_del" -width 6 -state disabled
    grid .f1.new_btn .f1.mod_btn .f1.del_btn -sticky ew

    ## list with database records
    if {$num > $list_size} {
      frame .l
      listbox .l.lb -selectmode browse -height $list_size -width 70 -exportselection 0\
                    -yscrollcommand ".l.sb set"
      scrollbar .l.sb -command ".l.lb yview"
      grid .l.lb .l.sb -sticky we
      grid .l -columnspan 3 -sticky we
      set listbox .l.lb
    }\
    else {
      listbox .lb -selectmode browse -height $list_size -width 70 -exportselection 0
      grid .lb -columnspan 3 -sticky we
      set listbox .lb
    }
    $listbox insert 0 "<add new>"
    bind $listbox <<ListboxSelect>> "$this on_sel %W"

    ## button frame2
    frame .f2
    grid .f2 -columnspan 3 -sticky ew

    #button .f2.l_btn -text "<"        -command on_l -width 6  -state disabled
    button .f2.res_btn -text "Reread"  -command "$this on_reset" -width 6
    #button .f2.r_btn -text ">"        -command on_r -width 6  -state disabled
    #grid .f2.l_btn .f2.res_btn .f2.r_btn
    grid .f2.res_btn
    on_reset
  }

  ##########################################################
  #### button actions

  method on_update_time {} {
    set tstamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  }

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
      if {$i < [$listbox size]} {$listbox delete $i}
      $listbox insert $i "$ts $v"
      set lst($i) $t
      set t "$t-"; # it will be passed to $dbdev command
    }
    itcl::delete object $dbdev

    # reset it to <add new> entry
    #  Note: on_sel opens the DB
    $listbox selection set 0
    $listbox activate 0
    on_sel $listbox
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
    set i [$listbox curselection]
    set t $lst($i)
    set nt [exec date -d "$tstamp" +%s]
    Device $dbdev
    $dbdev cmd del $dbname $t
    $dbdev cmd put $dbname $nt [$func_get]
    itcl::delete object $dbdev
    $listbox delete $i
    on_reset
  }

  method on_del {} {
    set i [$listbox curselection]
    $listbox selection set 0
    $listbox activate 0
    $listbox delete $i
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



