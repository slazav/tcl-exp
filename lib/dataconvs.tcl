
## data conversion functions

# PT 100 conversion function
# see PROJ/2018-ThermBox/calibration/Cal/pl_pt1000
proc PT100 {x} {
  set x [expr $x*10]; # pt100->pt1000
  if {$x < 9}    {return NaN}
  if {$x > 1300} {return NaN}
  set a 37.0249
  set b 0.211506
  set c 3.11259e-05
  set d -4.44629e-12
  set e 57.7821
  set f -4.866
  expr {$a + $b*$x + $c*$x**2 + $d*$x**4 - $e/sqrt($x+$f)}
}


# pfeiffer_APR262 pressure gauge (V -> mbar)
# /mnt/DOC/pressure/pfeiffer
proc pfeiffer_APR262 {x} {
  expr {2000*($x - 1)/8.0}
}


# Gems pressure gauge 0..1Bar 4..20mA (A -> mbar)
# /mnt/DOC/pressure/Gems
proc gems_1B_4-20mA {x} {
  expr {($x-4e-3)/(20e-3-4e-3)*1000}
}


# Gems pressure gauge 0..2.5Bar 4..20mA (A -> mbar)
# /mnt/DOC/pressure/Gems
proc gems_2B5_4-20mA {x} {
  expr {($x-4e-3)/(20e-3-4e-3)*2500}
}

