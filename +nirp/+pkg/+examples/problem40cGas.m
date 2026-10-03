function pkg = problem40cGas()
%PROBLEM40CGAS Return problem 40 kinetics with the problem 40c feed rate.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg = nirp.pkg.examples.problem40Gas() ;
    pkg.meta.name = "Problem 40c gas" ;
    pkg.feeds.values = [2 0.41 0.41 0 0.18] ;
    pkg.feeds.valuesUnit = "mol/min" ;
    pkg.feeds.Q = [] ;
    nirp.pkg.validate(pkg) ;
end
