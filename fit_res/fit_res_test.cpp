#include <stdlib.h>
#include <stdio.h>

#include <vector>

#include <gsl/gsl_rng.h>
#include <gsl/gsl_randist.h>

#include "fit.h"

int
main (void) {
  const size_t n = 300;  /* number of data points to fit */

  std::vector<double> freq(n), real(n), imag(n);
  std::vector<double> pars(6), pars_e(6);

  /* generate synthetic data with noise */
  {
    gsl_rng * r;
    const gsl_rng_type * T = gsl_rng_default;
    gsl_rng_env_setup ();
    r = gsl_rng_alloc (T);

    size_t i;
    double A = 1.1;
    double B = 0.1;
    double C = 1.2;
    double D = 2.2;
    double w0 = 1023;
    double dw = 11;
    for (i = 0; i < n; ++i) {

      double wi = w0 + 3*dw*( (double)i / (double) n - 0.5);
      double X0 = A - (C*dw - D*(wi-w0))/((wi-w0)*(wi-w0) + dw*dw);
      double Y0 = B - (C*(wi-w0) - D*dw)/((wi-w0)*(wi-w0) + dw*dw);

      double dx = gsl_ran_gaussian (r, 0.1);
      double dy = gsl_ran_gaussian (r, 0.1);

      freq[i] = wi;
      real[i] = X0 + dx;
      imag[i] = Y0 + dy;
    }
    gsl_rng_free(r);
  }

  double func_e = fit_res(n, freq.data(), real.data(), imag.data(),
                             pars.data(), pars_e.data());

  /* print data and model */
  {
    size_t i;
    double A  = pars[0];
    double B  = pars[1];
    double C  = pars[2];
    double D  = pars[3];
    double w0 = pars[4];
    double dw = pars[5];
    for (i = 0; i < n; ++i) {
        double wi = freq[i];
        double Xi = real[i];
        double Yi = imag[i];
        double z = (wi-w0)*(wi-w0) + dw*dw;
        double X = A - (C*dw - D*(wi-w0))/z;
        double Y = B - (C*(wi-w0) - D*dw)/z;
        printf("%f %f %f %f %f\n", wi, Xi, Yi, X, Y);
      }
  }

  return 0;
}
