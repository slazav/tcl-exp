# For a resonance curve (amp vs freq, BLT vectors) find
# the maximum f0,a0 (using a simple 3-pt quadratic fit)
# and q-factor Q=f0/df, where df is a width at a0*lvl.

proc fit_res {fv av {lvl 0.70711}} {
  # find index of point with maximal amplitude
  set maxi 0
  for {set i 0} {$i < [$fv length]} {incr i} {
    if {[$av index $i] > [$av index $maxi]} {set maxi $i} }
  if {$maxi == 0 || $maxi == [$fv length]-1} {error "fit_res: can't find maximum"}

  # calculate maximum (3-pt quadratic fit)
  set f1 [$fv index [expr $maxi-1]]
  set f2 [$fv index $maxi]
  set f3 [$fv index [expr $maxi+1]]
  set a1 [$av index [expr $maxi-1]]
  set a2 [$av index $maxi]
  set a3 [$av index [expr $maxi+1]]
  set D  [expr {$f1**2*($f2-$f3) + $f2**2*($f3-$f1) + $f3**2*($f1-$f2)}]
  if {$D==0} {error "fit_res: zero determinant in quadratic fit"}
  set A  [expr {($a1*($f2-$f3) + $a2*($f3-$f1) + $a3*($f1-$f2))/$D}]
  set B  [expr {($f1**2*($a2-$a3) + $f2**2*($a3-$a1) + $f3**2*($a1-$a2))/$D}]
  set C  [expr {($f1**2*($f2*$a3-$f3*$a2) + $f2**2*($f3*$a1-$f1*$a3) + $f3**2*($f1*$a2-$f2*$a1))/$D}]
  set f0 [expr {-$B/$A/2.0}]
  set a0 [expr {$C-$B**2/$A/4.0}]

  # calculate width at 1/2 amplitude
  set aa [expr {$a0*$lvl}]

  # right side
  set xr {}
  for {set i $maxi} {$i < [$fv length]-1} {incr i} {
    set a1 [$av index $i]
    set a2 [$av index [expr $i+1]]
    if {$a1 >= $aa && $a2 < $aa} {
      set f1 [$fv index $i]
      set f2 [$fv index [expr $i+1]]
      # linear interpolation between points
      set xr [expr {$f1 + ($f2-$f1)*($aa-$a1)/($a2-$a1)}]
    }
  }

  # left side
  set lr {}
  for {set i $maxi} {$i > 0} {set i [expr {$i-1}]} {
    set a1 [$av index $i]
    set a2 [$av index [expr $i-1]]
    if {$a1 >= $aa && $a2 < $aa} {
      set f1 [$fv index $i]
      set f2 [$fv index [expr $i-1]]
      # linear interpolation between points
      set xl [expr {$f1 + ($f2-$f1)*($aa-$a1)/($a2-$a1)}]
    }
  }
  if {$xr=={} || $xl=={}} {error "fit_res: can't get curve width"}
  set Q [expr {$f0/($xr-$xl)}]

  return [list $f0 $Q $a0 $xl $xr]
}
