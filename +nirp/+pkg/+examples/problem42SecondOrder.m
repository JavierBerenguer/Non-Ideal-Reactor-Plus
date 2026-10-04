function pkg = problem42SecondOrder()
%PROBLEM42SECONDORDER Return the second-order package for problem 42.
%   PKG = nirp.pkg.examples.problem42SecondOrder() describes A -> P with
%   k = 0.5 L/(mol*min), Q = 1000 L/min, and C_A0 = 1 mol/L.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 42 second order") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","P"},'Mw',{[],[]}, ...
        'cp',{cp,cp},'hf',{[],[]}) ;
    pkg.reactions.stoich = [-1 1] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',25,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"min") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',0.5, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[2 0], ...
        'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',25,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',[1 0],'valuesUnit',"mol/L", ...
        'Q',struct('value',1000,'unit',"L/min")) ;
    nirp.pkg.validate(pkg) ;
end
