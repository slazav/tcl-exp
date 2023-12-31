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
# -list_h     -- initial heigth of the list (number of records), default 10
# -list_w     -- initial heigth of the list (number of chars), default 70

package require itcl
package require xBlt
package require DeviceRole

itcl::class manual_db {
  # parameters /see options/
  variable dbdev;
  variable dbname;
  variable func_mkint;
  variable func_get;
  variable func_set;
  variable func_fmt;
  variable num;
  variable list_w;
  variable list_h;
  variable tstamp;
  variable listbox

  variable lst;  # text list
  variable data; # data list

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
      {-name}       name       {}\
      {-func_mkint} func_mkint func_mkint_text\
      {-func_get}   func_get   func_get_text\
      {-func_set}   func_set   func_set_text\
      {-func_fmt}   func_fmt   func_fmt_text\
      {-num}        num        10\
      {-list_h}     list_h     10\
      {-list_w}     list_w     70\
    ]
    xblt::parse_options "manual_db" $args $options

    # make interface
    ## title
    frame .title
    label .title.name  -text "$name" -font {-size 12} -anchor w
    label .title.dbname  -text "db: $dbname" -anchor w
    pack .title.name  -side left -fill x
    pack .title.dbname -side right -fill x
    grid .title -columnspan 3 -sticky ew

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
    button .f1.res_btn -text "Reread"  -command "$this on_reset" -width 6
    grid .f1.new_btn .f1.mod_btn .f1.del_btn x .f1.res_btn -sticky ew
    grid columnconfigure .f1 3 -weight 1

    ## list with database records
    frame .l
    listbox .l.lb -selectmode browse -height $list_h -width $list_w -exportselection 0\
                  -yscrollcommand ".l.sb set"
    scrollbar .l.sb -command ".l.lb yview"
    grid .l.lb .l.sb -sticky wens
    grid columnconfigure .l 0 -weight 1
    grid rowconfigure .l 0 -weight 1
    set listbox .l.lb
    grid .l -columnspan 3 -sticky wens

    grid rowconfigure . 4 -weight 1;   # last row, list
    grid columnconfigure . 1 -weight 1; # second column, entries

    $listbox insert 0 "<add new>"
    bind $listbox <<ListboxSelect>> "$this on_sel %W"

#    ## button frame2
    #    frame .f2
#    grid .f2 -columnspan 3 -sticky ew
#    #button .f2.l_btn -text "<"        -command on_l -width 6  -state disabled
#    button .f2.res_btn -text "Reread"  -command "$this on_reset" -width 6
#    #button .f2.r_btn -text ">"        -command on_r -width 6  -state disabled
#    #grid .f2.l_btn .f2.res_btn .f2.r_btn
#    grid .f2.res_btn
    on_reset
  }

  ##########################################################
  #### button actions

  method on_update_time {} {
    set tstamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  }

  ## reread data
  method on_reset {} {
    if {$dbdev == {}} {return}
    Device $dbdev
    # update listbox
    set t {}
    for {set i 1} {$i<$num} {incr i} {
      set r [lindex [$dbdev cmd get_prev $dbname $t] 0]
      if {$r=={}} {break}
      regexp {^ *(\S+) +(.*)$} $r x t v
      set ts [clock format [expr int($t)] -format "%Y-%m-%d %H:%M:%S"]
      if {$i < [$listbox size]} {$listbox delete $i}
      $listbox insert $i "$ts [$func_fmt $v]"
      set lst($i) $t
      set data($i) $v
      set t "$t-"; # it will be passed to $dbdev command
    }
    DeviceDelete [namespace current]::$dbdev

    # reset it to <add new> entry
    #  Note: on_sel opens the DB
    $listbox selection set 0
    $listbox activate 0
    on_sel $listbox
  }

  method on_add {} {
    if {$dbdev == {}} {return}
    set v [$func_get]
    if {$v=={} || $tstamp=={}} return
    set nt [exec date -d "$tstamp" +%s]
    Device $dbdev
    $dbdev cmd put $dbname $nt "$v"
    DeviceDelete [namespace current]::$dbdev
    on_reset
  }

  method on_mod {} {
    if {$dbdev == {}} {return}
    set i [$listbox curselection]
    set t $lst($i)
    set nt [exec date -d "$tstamp" +%s]
    Device $dbdev
    $dbdev cmd del $dbname $t
    $dbdev cmd put $dbname $nt "[$func_get]"
    DeviceDelete [namespace current]::$dbdev
    $listbox delete $i
    on_reset
  }

  method on_del {} {
    if {$dbdev == {}} {return}
    set i [$listbox curselection]
    $listbox selection set 0
    $listbox activate 0
    $listbox delete $i
    set t $lst($i)
    Device $dbdev
    $dbdev cmd del $dbname $t
    DeviceDelete [namespace current]::$dbdev
    on_reset
  }

  method on_sel {w} {
    set i [$w curselection]
    if {$i=={}} { return }
    if {$i!=0} {
      set t $lst($i)
      $func_set $data($i)
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



