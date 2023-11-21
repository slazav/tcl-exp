#!/usr/bin/wish

source autoupdater.tcl

# defauls updater: write a message every second
set updater1 [autoupdater #auto -update_proc [list puts "updater1 (1s)"]]

# with interval
autoupdater #auto -interval 5000 -update_proc [list puts "updater2 (5s)"]

# all options: write a message, control updater state and interval
proc u2 {} {puts "updater 3"}

set state 0
set interval 500

set updater3 [autoupdater #auto \
  -state_var ::state\
  -int_var   ::interval\
  -update_proc u2\
]

label .label1 -text "updater3 interval:"
set interval_e $interval
entry .int -textvariable interval_e
bind  .int <Key-Return> {set interval $interval_e}
# bind  .int <Key-Return> {$updater2 set_interval $interval_e}; ## same
grid .label1 .int

label .label2 -text "updater3 state:"
checkbutton .btn -variable state
grid .label2 .btn



