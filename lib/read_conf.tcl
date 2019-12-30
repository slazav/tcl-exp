# Read parameters from a configuration file into array.
# Usage:
#   read_conf $fname $arr $defs
# fname -- file name
# arr   -- array name
# defs  -- array with default values,
#   contains three values for each parameter:
#   name, default value, description (not used).
#
# configuration file structure:
# - lines which consist of 0 or more spaces are skipped
# - lines which start with 0 or more spaces followed by
#   '#'  character are skipped
# - if a line ends with '\' the next line will be
#   appended to it
# - Two first values are extracted frome each line,
#   key and vsalue. The key should match defs structure.

proc read_conf {fname arr defs} {
  set ff [open $fname]

  # set default values
  foreach {k v d} $defs {
    uplevel set ${arr}($k) [list $v]
  }

  while {![eof $ff]} {
    set line "[gets $ff]"

    # strings can be concatenated using \ symbol
    while {[string index "$line" end] == "\\"} {
      set line [string cat [string trimright $line "\\"] [gets $ff]]
    }

    # skip empty lines and comments
    if {[regexp {^\s*$} $line]} continue
    if {[regexp {^\s*#} $line]} continue

    set k [lindex $line 0]
    set v [lindex $line 1]

    if {[uplevel array names $arr -exact $k] == {}} {
      error "Unknown parameter '$k' in configuration file: '$fname'" }

    uplevel set ${arr}($k) [list $v]
  }

  close $ff
}
