function pkg = problem33Gas()
%PROBLEM33GAS Return the cooled reversible gas package for problem 33b.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 33b reversible gas") ;
    cpA = struct('type',"constant",'value',25,'unit',"J/(mol*K)") ;
    cpB = struct('type',"constant",'value',15,'unit',"J/(mol*K)") ;
    cpC = struct('type',"constant",'value',20,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C"},'Mw',{[],[],[]}, ...
        'cp',{cpA,cpB,cpC},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 2] ;
    pkg.reactions.DH = struct('value',-20,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',298.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3", ...
        'time',"s") ;
    reverse = struct('k0',1.85e6, ...
        'Ea',struct('value',90000,'unit',"J/mol"),'orders',[0 0 2]) ;
    pkg.reactions.kinetics = struct('type',"reversible",'k0',1.45e7, ...
        'Ea',struct('value',70000,'unit',"J/mol"), ...
        'orders',[1 1 0],'reverse',reverse,'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',77,'unit',"C"), ...
        'P',struct('value',580.5,'unit',"kPa"),'basis',"molarFlows", ...
        'values',[20 20 0],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
