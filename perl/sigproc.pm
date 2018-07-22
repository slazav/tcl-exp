package sigproc;
use JSON;

sub mk_name {
  my $sig = shift;
  my $ext = shift;
  $sig=~s/\.sigf?$//; $sig.=".$ext";
  return $sig
}

###############################################################
sub read_inf {
  my $f=shift;
  open INF, "$f" or die "can't open file: $f: $!\n";
  my $pars = decode_json(join "\n", (<INF>));
  close INF;
  return $pars;
}


###############################################################
sub read_sig_info {
  my $sig=shift;

  # read inf file for the signal
  my $inf = $sig; $inf=~s/\.sigf?$//; $inf.='.inf';
  `sig_get_info $sig` unless -f $inf;
  my $pars = read_inf($inf);

  # read inff
  my $inff = $sig; $inff=~s/\.sigf?$//; $inff.='.inff';
  my $pars1 = read_inf($inff);

  $pars = { (%{$pars}, %{$pars1}) };
  $pars->{sig} = $sig;
  return $pars;
}

###############################################################

# - rename l -> larm
# - add DF field to peaks
# - fit peaks
# - join peaks with same names, return a peak hash
# - do a combind fit

sub process_peaks {
  my $pars = shift;
  my @ret;
  my %names;

  my $dfdi = $pars->{dfdi};
  warn "No larmor mark at $pars->{sig}\n" if !exists $pars->{larm_i};
  my $I0   = $pars->{larm_i};

#  my $I0   = ${$pars->{nmr_i}}[0];

  foreach my $p (@{$pars->{fig_peaks}}){
    next unless $#{$p->{T}} >-1;

    warn "No peak name at $pars->{sig}\n" unless $p->{name};

    # skip larmor peak (old-style points with 'l' name)
    $p->{name} = "larm" if $p->{name} eq "l";
    next if $p->{name} eq "larm";

    # convert time to freq.shift, scale x2, x3 etc peaks:
    my @I = time2curr($pars->{nmr_t}, $pars->{nmr_i}, $p->{T});
    for (my $i=0; $i <= $#{$p->{T}}; $i++){
      ${$p->{DF}}[$i] = -($I[$i]-$I0)*$dfdi;
      ${$p->{F}}[$i]/=$1 if $p->{name}=~/(\d)$/;
      ${$p->{F}}[$i] = abs(${$p->{F}}[$i]);
    }
    # remove numbers from names:
    $p->{name}=~s/\d$//;


    # data length, Hz
    $p->{len} = abs(${$p->{DF}}[$#{$p->{DF}}]-${$p->{DF}}[0]);
    next if $p->{len} == 0;

    # fit the peak
    sigproc::fit_peak($p);

    # add to peaks array
    if (!exists $names{$p->{name}}) {
      push @ret, $p;
      $names{$p->{name}} = $#ret;
    }
    else {
      my $np = $names{$p->{name}};
      my $a1 = $p->{A};
      my $da1 = $p->{dA};
      my $b1 = $p->{B};
      my $db1 = $p->{dB};
      my $a2 = $ret[$np]->{A};
      my $da2 = $ret[$np]->{dA};
      my $b2 = $ret[$np]->{B};
      my $db2 = $ret[$np]->{dB};
      warn "Different peaks with same name $p->{name} in $pars->{sig}\n"
        if abs($a1-$a2) > 4*($da1+$da2)/2 || abs($b1-$b2) > 4*($db1+$db2)/2;
      push @{$ret[$np]->{T}},  @{$p->{T}};
      push @{$ret[$np]->{DF}}, @{$p->{DF}};
      push @{$ret[$np]->{F}},  @{$p->{F}};
      push @{$ret[$np]->{A}},  @{$p->{A}};
      push @{$ret[$np]->{Q}},  @{$p->{Q}};
    }
  }

  sigproc::fit_peak($p) foreach (@ret);
  return @ret;
}



###############################################################
# do a linear fit f^2 = a*(df-df0)
sub fit_peak {
  my $p = shift;
  my $df = $p->{DF}; # array reference
  my $f  = $p->{F}; # array reference

  my ($sx,$sxx,$sy,$syy,$sxy,$sn) = (0,0,0,0,0);

  return if $#{$df}<2;

  # find mean x value, it will be needed later
  for (my $i=0; $i <= $#{$df}; $i++ ) {
    $sx+=${$df}[$i]; $sn++;
  }
  return if $sn==0;
  my $x0 = $sx/$sn;
  $sx=0; $sn=0;

  # calculate all other sums with x-x0
  for (my $i=0; $i <= $#{$df}; $i++ ) {
    my $x = ${$df}[$i] - $x0;
    my $y = ${$f}[$i]*${$f}[$i];
    $sxx+=$x*$x; $sy+=$y; $syy+=$y*$y; $sxy+=$x*$y; $sn++;
  }

  # We are minimizing function s=sum[(Ax+B-y)^2)].
  # A and B can be found from
  # sA = ds/dA = sum[2x(Ax+B-y)] = 0
  # sB = ds/dB = sum[Ax+B-y] = 0

  return if $sxx*$sn==0;
  my $A = $sxy/$sxx;
  my $B = $sy/$sn;

  return if $A==0;
  my $df0 = -$B/$A + $x0;

  # near the minimum
  # s = s0 + sAA dA^2 + sBB dB^2 + sAB dAdB
  # where 
  # sAA = d2s/dA^2 = sum[4x^2]
  # sAB = d2s/dAdB = sum[2x] = 0  -- we subtracted x0!
  # sBB = d2s/dB^2 = sum[1]
  # then we can find errors in A and B, dA and dB at s=2*s0

  my $s0 = $A*$A*$sxx + $B*$B*$sn + $syy - 2*$A*$sxy - 2*$B*$sy;

  # mean square error
  my $err = sqrt($s0/$sn);

  # errors in A,B,df0
  my $dA = sqrt($s0/(4*$sxx));
  my $dB = sqrt($s0/$sn);

  my $ddf0 = $dB/$A + $dA*$B/$A/$A;

  $p->{A} = $A;
  $p->{df0} = $df0;
  $p->{dfc} = $x0;
  $p->{err} = $err;
  $p->{dA} = $dA;
  $p->{ddf0} = $ddf0;
  $p->{fitres} = 1;
}

###############################################################
# do a linear fit f^2 = a*(df-df0) with fixed df0
# do not modify errors!
sub fit_peak_fixdf {
  my $p = shift;
  my $df0 = shift;
  my $df = $p->{DF}; # array reference
  my $f  = $p->{F}; # array reference
  return if $#{$df}<1;

  my ($sx,$sxx,$sxy) = (0,0,0);

  # calculate all other sums with x-x0
  for (my $i=0; $i <= $#{$df}; $i++ ) {
    my $x = ${$df}[$i] - $df0;
    my $y = ${$f}[$i]*${$f}[$i];
    $sx+=$x; $sxx+=$x*$x; $sxy+=$x*$y;
  }
  return if $sxx==0;
  $p->{Af} = ($sxy-$df0*$sx)/$sxx;
  $p->{df0f} = $df0;
}

###############################################################
# Do a linear fit f^2 = A*(df-df0) of  many peaks with same A.
# argument: array of hashes with F and DF fields.
# add fields:
#   dfc, B, B_e, df0, df0_e
# return
#   res, A, A_e, err

sub fit_peaks {
  my @def=(0,0,0,0);
  my $peaks = shift;

  # s = sum_k sum_i (A x_ik + B_k - y_ik)^2
  # again shift all peaks to the mean value of x.
  # then
  #
  # ds/dA = 2 A sum_k sum_i (x_ik)^2 - 2 sum_k sum_i x_ik y_ik = 0
  # A = sum_k sum_i (x_ik)^2 / sum_k sum_i x_ik y_ik
  #
  # B_k = sum_i y_ik / sim_i 1
  #
  # errors:
  # sAB = d2s/(dA dB_k) = 2*A x_ik = 0
  # s = s0 + sAA dA^2 + sBB dB^2
  #
  # A_err = sqrt(s0/4 ssxx)
  # B_err_k = sqrt(s0/sn_k)


  #first calculate mean values of x for each peak
  foreach my $p (@{$peaks}) {
    next if $#{$p->{DF}} < 0;
    my ($sx,$sn) = (0,0);
    for (my $i=0; $i <= $#{$p->{DF}}; $i++ ) {
      $sx += ${$p->{DF}}[$i]; $sn++;
    }
    $p->{dfc} = $sx/$sn;
  }

  # now calculate all sums
  my ($ssxx, $ssxy, $ssn) = (0,0,0);
  my $s0 = 0;
  foreach my $p (@{$peaks}) {
    next if $#{$p->{DF}} < 0;
    my ($syy, $sy,$sn) = (0,0);
    for (my $i=0; $i <= $#{$p->{DF}}; $i++ ) {
      my $x = ${$p->{DF}}[$i] - $p->{dfc};
      my $y = ${$p->{F}}[$i]*${$p->{F}}[$i];
      $ssxx+=$x*$x; $ssxy+=$x*$y;
      $syy+=$y*$y; $sy+=$y; $sn++;
    }
    $ssn+=$sn;
    $p->{B} = $sy/$sn;
    $s0 += $syy + $p->{B}*$p->{B}*$sn - 2*$p->{B}*$sy;
  }
  return @def if $ssxx==0 || $ssn==0;
  my $A = $ssxy/$ssxx;
  $s0 -= $A*$ssxy;

  my $A_e = sqrt($s0/(4*$ssxx));

  return @def if $A==0;

  # mean square error
  my $err = sqrt($s0/$ssn);

  # B errors, df0
  foreach my $p (@{$peaks}) {
    next if $#{$p->{DF}} < 0;
    $p->{B_e} = sqrt($s0/($#{$p->{DF}}+1));
    $p->{df0} = - $p->{B}/$A + $p->{dfc};
    $p->{df0_e} = $p->{B_e}/$A + $A_e*$p->{B}/$A/$A;
  }
  return (1, $A, $dA, $err);
}


###############################################################
sub time2curr {
  my $nmr_t = shift;
  my $nmr_i = shift;
  my $T = shift;

  my @ret;
  my $tau = 0.2;
  my $k = 0;
  my $n = $#{$nmr_t};
  for (my $i = 0; $i<= $#{$T}; $i++){
    $k-- while ($k>0 && ${$nmr_t}[$k+1] > ${$T}[$i]);
    $k++ while ($k<$n-2 && ${$nmr_t}[$k+2] < ${$T}[$i]);
    # now k+1 points to previous time
    my $dt = ${$T}[$i]-${$nmr_t}[$k+1];
    my $i1 = ${$nmr_i}[$k];
    my $i2 = ${$nmr_i}[$k+1];
    # At k+1 current switched from i1 to i2.
    # then, after dt we have
    push @ret, $i2 - ($i2-$i1) * exp(-$dt/$tau);
  }
  return @ret;
}

###############################################################


# convert excitation voltage to frequency, V->Hz:
# attenuation: k = 0.05
# coil inductance L = 55uH
# frequency: f0 = 1120kHz
# current: I = U * k / (2*pi*f0*L),  0.129mA/V
# field: H = I * 16.6 [G]
# freq: f = 20378 * H/2/pi
#  result: 6.95 Hz/V
our $u2f = 6.95;

# convert gradient to frequency, mA->Hz
#  grad coil K = 15.7 GA/cm
#  cell size L = 0.9 cm
#    result: K*1e-3*I * 20378/2/pi  L/2  = 22.9 Hz/mA (1/2 cell)

our $g2f = 22.9;
our $fB = 290000;
our $f0 = 1120000;

1;
