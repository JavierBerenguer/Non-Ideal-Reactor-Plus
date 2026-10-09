function pkg = problem16EmpiricalGas()
%PROBLEM16EMPIRICALGAS Return the empirical gas-PFR package for problem 16.
%   4 A + B -> R + S at 3 atm and 150 C. The empirical extent rate is
%   (1+C_A*C_B)/(1+0.5*C_B/C_A) mol/(L*h), with concentration in mol/L.
%   Heat capacities are placeholders because both requested PFRs are
%   isothermal. F1 and F2 are identical feeds for the two diagram branches.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1, ...
        'name',"Problem 16 empirical gas PFR") ;
    cp = struct('type',"constant",'value',30,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","R","S"}, ...
        'Mw',{[],[],[],[]},'cp',{cp,cp,cp,cp},'hf',{[],[],[],[]}) ;
    pkg.reactions.stoich = [-4 -1 1 1] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',423.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"h") ;
    pkg.reactions.kinetics = struct('type',"expression",'k0',[], ...
        'Ea',[],'orders',[],'reverse',[],'expression', ...
        "(1+concentration(1)*concentration(2))/(1+0.5*concentration(2)/concentration(1))") ;
    feed = struct('name',"F1",'phase',"G", ...
        'T',struct('value',423.15,'unit',"K"), ...
        'P',struct('value',3,'unit',"atm"),'basis',"molarFlows", ...
        'values',[200 200 0 0],'valuesUnit',"kmol/h",'Q',[]) ;
    pkg.feeds = [feed feed] ;
    pkg.feeds(2).name = "F2" ;
    nirp.pkg.validate(pkg) ;
end
