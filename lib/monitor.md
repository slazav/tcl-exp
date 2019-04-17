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

All func_* functions can throw errors, return values are ignored.

Useful methods:

* `set_status {msg {col black}}` -- set status-line message with color `col`.
* `method restart {}` -- restart the measurement
* `stop {}` -- stop the measurement
* `do_exit {}` -- close devices and exit
* `measure {}` -- do a single measurements