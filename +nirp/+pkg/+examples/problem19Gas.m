function pkg = problem19Gas()
%PROBLEM19GAS Return the adiabatic gas package for problem 19.
%   PKG = nirp.pkg.examples.problem19Gas() describes A + B -> C with the
%   inert I, Arrhenius kinetics, and heat-capacity data from the statement.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 19 gas") ;
    cpA = struct('type',"constant",'value',75,'unit',"J/(mol*K)") ;
    cpC = struct('type',"constant",'value',150,'unit',"J/(mol*K)") ;
    cpI = struct('type',"constant",'value',10,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C","I"}, ...
        'Mw',{[],[],[],[]},'cp',{cpA,cpA,cpC,cpI}, ...
        'hf',{[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1 0] ;
    pkg.reactions.DH = struct('value',50,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',298,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"s") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',9750, ...
        'Ea',struct('value',4000*8.314,'unit',"J/mol"), ...
        'orders',[1 1 0 0],'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',700,'unit',"C"), ...
        'P',struct('value',2,'unit',"atm"),'basis',"molarFlows", ...
        'values',[16 16 0 8],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
