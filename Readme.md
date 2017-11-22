# Useful scripts for my experimental setup and data processing

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
