#ifndef FIT_RES_H
#define FIT_RES_H

/*
Fit resonance with Lorentzian curve
Arguments:
  n   - number of points
  freq - frequency data [0..n-1]
  real - X (real part) of the data [0..n-1]
  imag - Y (imag part) of the data [0..n-1]
  pars - array of size 6, fit parameters:
         base_real, base_imag, amp_real, amp_imag, res_freq, res_width
  pars_e
Return value:

*/

extern "C"
double fit_res (const size_t n,
                double * freq, double * real, double * imag,
                double pars[6], double pars_e[6]);

#endif
