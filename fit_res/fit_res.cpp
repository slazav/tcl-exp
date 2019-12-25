#include <stdlib.h>
#include <stdio.h>

#include <iostream>
#include <sstream>
#include <vector>
#include <string>

#include "fit.h"

int
main (void) {

  std::vector<double> freq, real, imag;
  std::vector<double> pars(6), pars_e(6);

  while (!std::cin.eof()){

    std::string l;
    getline(std::cin, l);

    std::istringstream ss(l);
    double t,f,x,y;
    ss >> t >> f >> x >> y;
    freq.push_back(f);
    real.push_back(x);
    imag.push_back(y);
  }

  double func_e = fit_res(freq.size(),
     freq.data(), real.data(), imag.data(),
     pars.data(), pars_e.data());

  for (size_t i = 0; i<6; i++)
    std::cout << " " << pars[0];

  std::cout << "\n";
  return 0;
}
