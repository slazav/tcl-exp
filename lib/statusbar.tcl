package require itcl

### Status bar widget to be used in Monitor and other interfaces
### - Contains image + text + "..."-button.
### - Long messages can be shown by clicking on the button.

itcl::class StatusBar {

  variable status_text {}; # full text in the status line
  variable root {};        # root widget

  #########################
  ## Constructor/Destructor
  constructor {tkroot} {
    set root $tkroot
    frame $root -borderwidth 1 -relief sunken
    canvas $root.img -width 10 -height 10
    label $root.txt -height 1 -justify left -anchor w
    button $root.btn -height 1 -pady 0 -padx 2 -text {...} -command "$this show_status"
    bind $root.txt <ButtonPress> "$this show_status"
    grid $root.img $root.txt -sticky w -padx 3
    grid $root.btn -padx 0 -column 2 -row 0
    grid columnconfigure $root 1 -weight 1
  }

  ##########################
  ## set status text
  method set_status {msg {col black}} {
    set L $root.txt; # the label widget
    set status_text $msg
    # We want to cut one line of the text
    set n [string first "\n" $msg]
    if {$n>0} {
      $L configure -text [string range $msg 0 [expr $n-1]]
    } else {
      $L configure -text $msg
    }
    $L configure -fg $col
    update idletasks
  }

  ##########################
  ## get status text
  method get_status {} { return $status_text }

  ##########################
  ## set status image
  method set_img {shape color} {
    $root.img delete r
    if {$shape == "triangle_right"} {
      $root.img create polygon 1 1 10 5 1 10 -fill $color -tags r
      return
    }
    if {$shape == "square"} {
      $root.img create polygon 1 1 1 10 10 10 10 1 -fill $color -tags r
      return
    }
    update idletasks
  }

  ##########################
  # Dialog with full text of the status line
  # (called when pressing on the status line)
  method show_status { } {
    if {[winfo exists .log]} {
      raise .log
      return
    }
    toplevel .log; #Make the window

    text .log.txt -wrap char -width 80 -height 20\
       -yscrollcommand {.log.yscroll set}
    scrollbar .log.yscroll -orient vertical \
        -command [list .log.txt yview]
    button .log.btn -text "Close" -command { destroy .log }

    pack .log.btn -expand 0 -fill x -side bottom
    pack .log.yscroll -expand 0 -fill y -side right
    pack .log.txt -expand 1 -fill both

    .log.txt insert end $status_text

    # highklite some words with colors
    foreach patt {"Error:" "invoked from within" "while executing"}\
            col {"red" "green" "green"} {
      set t 0.0
      set cnt 0
      while {1} {
        set t [.log.txt search -exact -count cnt $patt "$t + $cnt chars" end]
        if {$t == {}} {break}
        .log.txt tag add t$t $t "$t + $cnt chars"
        .log.txt tag configure t$t -foreground $col
      }
    }
  }

}
