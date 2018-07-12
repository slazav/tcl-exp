package sigproc;
use JSON;

sub mk_name {
  my $sig = shift;
  my $ext = shift;
  $sig=~s/\.sigf?$//; $sig.=".$ext";
  return $sig
}

###############################################################
sub read_sig_info {
  my $sig=shift;

  # read inf file for the signal
  my $inf = $sig; $inf=~s/\.sigf?$//; $inf.='.inf';
  `sig_get_info $sig` unless -f $inf;
  open INF, "$inf" or die "can't open file: $inf: $!\n";
  my $pars = decode_json(join "\n", (<INF>));
  close INF;

  # read inff
  my $inff = $sig; $inff=~s/\.sigf?$//; $inff.='.inff';
  open INF, "$inff" or die "can't open file: $inff: $!\n";
  my $pars1 = decode_json(join "\n", (<INF>));
  close INF;

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
  my %ret;

  my $dfdt = $pars->{dfdt};
  warn "No larmor mark at $pars->{sig}\n" if !exists $pars->{larm_df};
  my $df   = $pars->{larm_df};

  foreach my $p (@{$pars->{fig_peaks}}){
    next unless $#{$p->{T}} >-1;

    warn "No peak name at $pars->{sig}\n" unless $p->{name};

    # skip larmor peak
    $p->{name} = "larm" if $p->{name} eq "l";
    next if $p->{name} eq "larm";

    # convert time to freq.shift, scale x2, x3 etc peaks:
    for (my $i=0; $i <= $#{$p->{T}}; $i++){
      ${$p->{DF}}[$i] = -${$p->{T}}[$i]*$dfdt+$df;
      ${$p->{F}}[$i]/=$1 if $p->{name}=~/(\d)$/;
      ${$p->{F}}[$i] = abs(${$p->{F}}[$i]);
    }
    # remove numbers from names:
    $p->{name}=~s/\d$//;

    # data length, Hz
    $p->{len} = abs(${$p->{DF}}[$#{$p->{DF}}]-${$p->{DF}}[0]);

    # fit the peak
    ($p->{fitres}, $p->{A}, $p->{df0}, $p->{dfc}, $p->{err}, $p->{dA}, $p->{ddf0})
      = sigproc::fit_peak($p->{DF}, $p->{F});

    # skip bad peaks
#    next if $p->{ddf0}>15;
#    next if $p->{len}<100;

    # add to peaks array
    if (!exists $ret{$p->{name}}) {
      $ret{$p->{name}} = $p;
    }
    else {
      my $a1 = $p->{A};
      my $da1 = $p->{dA};
      my $b1 = $p->{B};
      my $db1 = $p->{dB};
      my $a2 = $ret{$p->{name}}->{A};
      my $da2 = $ret{$p->{name}}->{dA};
      my $b2 = $ret{$p->{name}}->{B};
      my $db2 = $ret{$p->{name}}->{dB};
      warn "Different peaks with same name $p->{name} in $pars->{sig}\n"
        if abs($a1-$a2) > 4*($da1+$da2)/2 || abs($b1-$b2) > 4*($db1+$db2)/2;
      push @{$ret{$p->{name}}->{T}},  @{$p->{T}};
      push @{$ret{$p->{name}}->{DF}}, @{$p->{DF}};
      push @{$ret{$p->{name}}->{F}},  @{$p->{F}};
      push @{$ret{$p->{name}}->{A}},  @{$p->{A}};
      push @{$ret{$p->{name}}->{Q}},  @{$p->{Q}};
    }
  }

  foreach (values %ret){
    ($p->{fitres}, $p->{A}, $p->{df0}, $p->{dfc}, $p->{err}, $p->{dA}, $p->{ddf0})
      = sigproc::fit_peak($p->{DF}, $p->{F});
  }

  return %ret;
}



###############################################################
# do a linear fit f^2 = a*(df-df0)
sub fit_peak {
  my @def=(0,0,0,0,0,0);
  my $df = shift; # array reference
  my $f  = shift; # array reference

  my ($sx,$sxx,$sy,$syy,$sxy,$sn) = (0,0,0,0,0);

  return @def if $#{$df}<2;

  # find mean x value, it will be needed later
  for (my $i=0; $i <= $#{$df}; $i++ ) {
    $sx+=${$df}[$i]; $sn++;
  }
  return @def if $sn==0;
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

  return @def if $sxx*$sn==0;
  my $A = $sxy/$sxx;
  my $B = $sy/$sn;

  return @def if $A==0;
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

  return (1, $A, $df0, $x0, $err, $dA, $ddf0);
}
###############################################################



1;
