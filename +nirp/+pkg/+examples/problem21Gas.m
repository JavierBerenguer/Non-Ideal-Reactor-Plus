function pkg = problem21Gas()
%PROBLEM21GAS Return the gas-phase package for collection problem 21.
%   PKG = nirp.pkg.examples.problem21Gas() describes 2 A -> B with inert I.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 21 gas") ;
    cpA = struct('type',"constant",'value',20,'unit',"cal/(mol*K)") ;
    cpB = struct('type',"constant",'value',30,'unit',"cal/(mol*K)") ;
    cpI = struct('type',"constant",'value',10,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"A","B","I"},'Mw',{[],[],[]}, ...
        'cp',{cpA,cpB,cpI},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-2 1 0] ;
    pkg.reactions.DH = struct('value',3.5,'unit',"kcal/mol") ;
    pkg.reactions.Tref = struct('value',293.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"min") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',exp(14), ...
        'Ea',struct('value',7000*8.314,'unit',"J/mol"), ...
        'orders',[2 0 0],'reverse',[],'expression',"") ;
    totalFlow = (20/0.9)*100 ;
    pressure = (20/0.9)*1000*8.314*298.15 ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',298.15,'unit',"K"), ...
        'P',struct('value',pressure,'unit',"Pa"), ...
        'basis',"totalAndFractions", ...
        'values',[totalFlow 0.9 0 0.1],'valuesUnit',"mol/min",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
