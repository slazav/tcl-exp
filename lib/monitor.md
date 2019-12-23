`Monitor` -- Base class for a measurement interface. Minimal GUI with
on/off button, status line, single/regular measurements. User provides
four functions for making interface frame, opening devices, making
measurements, closing devices. `Monitor` class does periodic measurements
with correct open/measure/close function order, error handling.

Usage:
* `Monitor <name> <widget path> <options>`

Options:
* `-name`       -- program name
* `-period`     -- measurement period
* `-onoff`      -- initial state of main switch
* `-func_start` -- start function
* `-func_stop`  -- stop function
* `-func_meas`  -- measure function
* `-func_mkint` -- make interface function (argumentL: widget path)
* `-show_ctl`   -- show control panel, buttons and period setting (default: 1)
* `-show_title` -- show title panel (default: 1)
* `-verb`       -- verbosity level (0: show only errors in the status line,
*                  1(default): show status messages (Measure, Waiting, etc.)

All func_* functions can throw errors, return values are ignored.

Useful methods:

* `set_status {msg {col black}}` -- set status-line message with color `col`.
* `restart {}` -- (re)start the measurement
* `stop {}` -- stop the measurement
* `single {}` -- do a single measurements
* `do_exit {}` -- close devices and exit
* `startstop {}` -- Do start and stop without any measurement
  (useful if in the beginning we want to open devices and collect some information)

If <widget path> is empty then monitor does not create any interface.
User can create its own interface instead.
