# Read parameters from a configuration file into array.
# Usage:
#   read_conf $fname $arr $defs
# fname -- file name
# arr   -- array name
# defs  -- array with default values,
#   contains three values for each parameter:
#   name, default value, description (not used).

proc read_conf {fname arr defs} {
  set ff [open $fname]

  # set default values
  foreach {k v d} $defs {
    uplevel set ${arr}($k) [list $v]
  }

  while {![eof $ff]} {
    set line [gets $ff]
    # skip empty lines and comments
    if {[regexp {^\s*$} $line]} continue
    if {[regexp {^\s*#} $line]} continue
    if {![regexp {^\s*(\S+)\s+(.*)} $line a k v]} continue

    if {[uplevel array names ${arr} -exact $k] == {}} {
      error "Unknown parameter '$k' in configuration file: '$fname'" }

    uplevel set ${arr}($k) [list $v]
  }

  close $ff
}
