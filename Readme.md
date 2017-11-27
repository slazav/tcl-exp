# Useful scripts for my experimental setup and data processing

TODO: split into two packages:
- scripts for office use (with tex dep etc)
- scripts for experiment (with Device dep)

## Files in `octave` folder (should be installed into `/usr/share/octave/site/m/`)

* find_figure.m -- find figure with given name or create new
  (modified script from /rota/programs/matlab)

## Files in `bin` folder (should be installed into `/usr/bin/`)

* data_join.pl -- simple script for joining two files with X-Y columns
assuming that X is the same

* ellps2dots -- Convert circles/ellipses into dots in xfig file. I use it for data plots
created by gnuplot. After conversion one can resize pictures without
getting ellipses instead of circles.

* epstex2eps -- Convert eps+tex into full eps. I use eps+tex for making pictures,
but sometimes a finished eps is also needed.

## Files in `exp` folder (should be installed into `/usr/bin/`)

Here I put scripts for actual measurements.

* fork_pulse -- A fork pulse controller with stdin/stdout interface. Uses
Device library and can be used as a device itself.
Works with 33511B Keysight generator, Pico 4224 oscilloscope
(see pico_rec repository) and graphene database.

* fork_pulse_int -- TCL GUI for fork pulse measurements.

* sweeper -- current sweeper for controlling magnets and making
measurements as a function of magnetic field. Can be used as a device in
the Device library. Uses DeviceRole for working with any supported power
supply and gauge devices, uses graphene database to store data.

* sweep_int -- TCL GUI for sweeper. Not finished yet.

* get_gain -- Script for simple gain measurement: sweep generator frequency and measure
response by lock-in amplifier.

* get_noise -- Script for simple noise measurement

* set_ac, set_dc -- cmdline interfaces to DeviceRole library
for seting AC/DC sources.
