#include <stdlib.h>
#include <stdio.h>
#include <gsl/gsl_vector.h>
#include <gsl/gsl_matrix.h>
#include <gsl/gsl_blas.h>
#include <gsl/gsl_multifit_nlinear.h>
//#include <gsl/gsl_rng.h>
//#include <gsl/gsl_randist.h>

// modified Gaussian example from
//https://www.gnu.org/software/gsl/doc/html/nls.html#c.gsl_multifit_nlinear_fdf

struct data {
  double *w;
  double *x;
  double *y;
  size_t n;
};

/* model function:

(X + iY) = (A + iB) + (C + iD)/(i(w-w0) - dw)

X(w) = A - (C*dw - D*(w-w0))/((w-w0)**2 + dw**2)
Y(w) = B - (C*(w-w0) + D*dw)/((w-w0)**2 + dw**2)
*/

int
func_f (const gsl_vector * x, void *params, gsl_vector * f) {
  struct data *d = (struct data *) params;
  double A = gsl_vector_get(x, 0);
  double B = gsl_vector_get(x, 1);
  double C = gsl_vector_get(x, 2);
  double D = gsl_vector_get(x, 3);
  double w0 = gsl_vector_get(x, 4);
  double dw = gsl_vector_get(x, 5);
  size_t i;

  for (i = 0; i < d->n; ++i) {
      double wi = d->w[i];
      double Xi = d->x[i];
      double Yi = d->y[i];
      double z = (wi-w0)*(wi-w0) + dw*dw;
      double X = A - (C*dw - D*(wi-w0))/z;
      double Y = B - (C*(wi-w0) - D*dw)/z;

      gsl_vector_set(f, 2*i,   Xi - X);
      gsl_vector_set(f, 2*i+1, Yi - Y);
    }

  return GSL_SUCCESS;
}

// function derivative (TODO!)

int
func_df (const gsl_vector * x, void *params, gsl_matrix * J) {
  struct data *d = (struct data *) params;
  double A = gsl_vector_get(x, 0);
  double B = gsl_vector_get(x, 1);
  double C = gsl_vector_get(x, 2);
  double D = gsl_vector_get(x, 3);
  double w0 = gsl_vector_get(x, 4);
  double dw = gsl_vector_get(x, 5);
  size_t i;

  for (i = 0; i < d->n; ++i) {
      double wi = d->w[i];
      double Xi = d->x[i];
      double Yi = d->y[i];

      double z = (wi-w0)*(wi-w0) + dw*dw;

      gsl_matrix_set(J, 2*i, 0, 1);
      gsl_matrix_set(J, 2*i, 1, 0);
      gsl_matrix_set(J, 2*i, 2, -dw/z);
      gsl_matrix_set(J, 2*i, 3, (wi-w0)/z);
      gsl_matrix_set(J, 2*i, 4, -D/z - (C*dw - D*(wi-w0))*2*(wi-w0)/z/z);
      gsl_matrix_set(J, 2*i, 5, -C/z + (C*dw - D*(wi-w0))*2*dw/z/z);

      gsl_matrix_set(J, 2*i+1, 0, 0);
      gsl_matrix_set(J, 2*i+1, 1, 1);
      gsl_matrix_set(J, 2*i+1, 2, -(wi-w0)/z);
      gsl_matrix_set(J, 2*i+1, 3, dw/z);
      gsl_matrix_set(J, 2*i+1, 4, C/z - (C*(wi-w0) - D*dw)*2*(wi-w0)/z/z);
      gsl_matrix_set(J, 2*i+1, 5, D/z + (C*(wi-w0) - D*dw)*2*dw/z/z);
  }

  return GSL_SUCCESS;
}

/*
int
func_fvv (const gsl_vector * x, const gsl_vector * v,
          void *params, gsl_vector * fvv)
{
  struct data *d = (struct data *) params;
  double a = gsl_vector_get(x, 0);
  double b = gsl_vector_get(x, 1);
  double c = gsl_vector_get(x, 2);
  double va = gsl_vector_get(v, 0);
  double vb = gsl_vector_get(v, 1);
  double vc = gsl_vector_get(v, 2);
  size_t i;

  for (i = 0; i < d->n; ++i) {
      double ti = d->t[i];
      double zi = (ti - b) / c;
      double ei = exp(-0.5 * zi * zi);
      double Dab = -zi * ei / c;
      double Dac = -zi * zi * ei / c;
      double Dbb = a * ei / (c * c) * (1.0 - zi*zi);
      double Dbc = a * zi * ei / (c * c) * (2.0 - zi*zi);
      double Dcc = a * zi * zi * ei / (c * c) * (3.0 - zi*zi);
      double sum;

      sum = 2.0 * va * vb * Dab +
            2.0 * va * vc * Dac +
                  vb * vb * Dbb +
            2.0 * vb * vc * Dbc +
                  vc * vc * Dcc;

      gsl_vector_set(fvv, i, sum);
    }

  return GSL_SUCCESS;
}
*/
void
callback(const size_t iter, void *params,
         const gsl_multifit_nlinear_workspace *w) {
  gsl_vector *f = gsl_multifit_nlinear_residual(w);
  gsl_vector *x = gsl_multifit_nlinear_position(w);
  double avratio = gsl_multifit_nlinear_avratio(w);
  double rcond;

  (void) params; /* not used */

  /* compute reciprocal condition number of J(x) */
  gsl_multifit_nlinear_rcond(&rcond, w);

  fprintf(stderr, "iter %2zu: a = %.4f, b = %.4f, c = %.4f, |a|/|v| = %.4f cond(J) = %8.4f, |f(x)| = %.4f\n",
          iter,
          gsl_vector_get(x, 0),
          gsl_vector_get(x, 1),
          gsl_vector_get(x, 2),
          avratio,
          1.0 / rcond,
          gsl_blas_dnrm2(f));
}

double
solve_system(gsl_vector *x, gsl_multifit_nlinear_fdf *fdf,
             gsl_multifit_nlinear_parameters *params) {
  const gsl_multifit_nlinear_type *T = gsl_multifit_nlinear_trust;
  const size_t max_iter = 200;
  const double xtol = 1.0e-8;
  const double gtol = 1.0e-8;
  const double ftol = 1.0e-8;
  const size_t n = fdf->n;
  const size_t p = fdf->p;
  gsl_multifit_nlinear_workspace *work =
    gsl_multifit_nlinear_alloc(T, params, n, p);
  gsl_vector * f = gsl_multifit_nlinear_residual(work);
  gsl_vector * y = gsl_multifit_nlinear_position(work);
  int info;
  double chisq0, chisq, rcond;

  /* initialize solver */
  gsl_multifit_nlinear_init(x, fdf, work);

  /* store initial cost */
  gsl_blas_ddot(f, f, &chisq0);

  /* iterate until convergence */
  gsl_multifit_nlinear_driver(max_iter, xtol, gtol, ftol,
                              callback, NULL, &info, work);

  /* store final cost */
  gsl_blas_ddot(f, f, &chisq);

  /* store cond(J(x)) */
  gsl_multifit_nlinear_rcond(&rcond, work);

  gsl_vector_memcpy(x, y);

  /* print summary */

  fprintf(stderr, "NITER         = %zu\n", gsl_multifit_nlinear_niter(work));
  fprintf(stderr, "NFEV          = %zu\n", fdf->nevalf);
  fprintf(stderr, "NJEV          = %zu\n", fdf->nevaldf);
  fprintf(stderr, "NAEV          = %zu\n", fdf->nevalfvv);
  fprintf(stderr, "initial cost  = %.12e\n", sqrt(chisq0/n));
  fprintf(stderr, "final cost    = %.12e\n", sqrt(chisq/n));

  fprintf(stderr, "A  = %.12e\n", gsl_vector_get(x, 0));
  fprintf(stderr, "B  = %.12e\n", gsl_vector_get(x, 1));
  fprintf(stderr, "C  = %.12e\n", gsl_vector_get(x, 2));
  fprintf(stderr, "D  = %.12e\n", gsl_vector_get(x, 3));
  fprintf(stderr, "w0 = %.12e\n", gsl_vector_get(x, 4));
  fprintf(stderr, "dw = %.12e\n", gsl_vector_get(x, 5));

  fprintf(stderr, "final cond(J) = %.12e\n", 1.0 / rcond);

  gsl_multifit_nlinear_free(work);
  return sqrt(chisq/n);
}


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
double
fit_res (const size_t n,
         double * freq,
         double * real,
         double * imag,
         double pars[6],
         double pars_e[6]
        ) {

  const size_t p = 6;    /* number of model parameters */

  gsl_vector *f = gsl_vector_alloc(2*n);
  gsl_vector *x = gsl_vector_alloc(p);
  gsl_multifit_nlinear_fdf fdf;
  gsl_multifit_nlinear_parameters fdf_params =
    gsl_multifit_nlinear_default_parameters();
  size_t i;
  struct data fit_data;

  //

  fit_data.n = n;
  fit_data.w = freq;
  fit_data.x = real;
  fit_data.y = imag;

  /* define function to be minimized */
  fdf.f = func_f;
  fdf.df = NULL; //func_df;
  fdf.fvv = NULL; //func_fvv;
  fdf.n = 2*n;
  fdf.p = p;
  fdf.params = & fit_data;

  /* starting point */
  gsl_vector_set(x, 0, (fit_data.x[0] + fit_data.x[n-1])/2);
  gsl_vector_set(x, 1, (fit_data.y[0] + fit_data.y[n-1])/2);
  gsl_vector_set(x, 2, 1.0);
  gsl_vector_set(x, 3, 1.0);
  gsl_vector_set(x, 4, (fit_data.w[n-1] + fit_data.w[0])/2);
  gsl_vector_set(x, 5, abs(fit_data.w[n-1]-fit_data.w[0])/2);

//  fdf_params.trs = gsl_multifit_nlinear_trs_lmaccel;
  fdf_params.trs = gsl_multifit_nlinear_trs_lm;
  double res = solve_system(x, &fdf, &fdf_params);

  for (i=0; i<6; i++) pars[i] = gsl_vector_get(x, i);

  gsl_vector_free(f);
  gsl_vector_free(x);

  return res;
}

