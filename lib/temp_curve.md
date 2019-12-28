### TCL library for working with temperature calibration curves.

The main purpose of the library is to work with calibraion curves for
loading into LakeShore 370 resistance bridge. Each curve contains header
and up to 200 points with two format-dependent values. The first value
should increase monotonically (the library can also read
monotonically-decreasing data and revert it).

Header fields:
- name -- 15 symbols
- serial -- 10 symbols
- data format -- 3 (Ohm) or 4 (log10(Ohm))
- setpoint limit -- used only for temperature control. Default value
  375K, LakeShore documentation also recommends value 9999 if not used.
- temperature coefficent -- not important because device
  get it from two first points.


### Blueforse format

```
Sensor Model:   PT1000
Serial Number:  VZ_N6PT
Data Format:    4      (Log Ohms/Kelvin)
SetPoint Limit: 100.0      (Kelvin)
Temperature coefficient:  2 (Positive)
Number of Breakpoints:   93

No.   Units      Temperature (K)
1 3.112935 350
2 3.106488 345
3 3.099933 340
4 3.093266 335
5 3.086486 330
6 3.079587 325
7 3.072566 320
```

### Simple format (same as when communicating with device)

```
PT1000, VZ_N6PT, 4, 350, 2
3.112935, 350
3.106488, 345
3.099933, 340
3.093266, 335
3.086486, 330
3.079587, 325
```

### TempCurve object

TempCurve object keeps header information an data points (as TCL lists)

Methods:
 - reset {} -- reset curve data
  # get name
 - get_name {} -- get curve name
 - get_serial {} -- get serial
 - get_fmt {} -- get format (3 of 4)
 - get_tlim {} -- get temperature limit

 - set_name {v}  -- set curve name (will be trimmed to 15 symbols)
 - set_serial {v} -- set serial (will be trimmed to 10 symbols)
 - set_fmt {v} -- set format (error is thrown if not 3 or 4)
 - set_tlim {v} -- set temperature limit (error if non-numeric value)

 - get_tcoeff {} -- Get temperature coefficent.
   The coefficent is calculated from first two points. Curve should be non-empty.

 - get_npts {} -- get number of points
 - append_point {x y} -- append point to the data

 - read_file {fname} - Read curve from file. Simple and Bluefors formats
   are supported. X column should be monotonic.

 - check_data {} -- check data (number of points, monotonic)

 - write_file_simple {fname} -- write file in the simple form

 - calc {xx} -- convert x -> y (can work with single values or lists)
