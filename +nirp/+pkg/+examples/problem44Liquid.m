function pkg = problem44Liquid()
%PROBLEM44LIQUID Return the adiabatic liquid package for problem 44.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 44 liquid") ;
    cpA = struct('type',"constant",'value',15,'unit',"cal/(mol*K)") ;
    cpC = struct('type',"constant",'value',30,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C"},'Mw',{[],[],[]}, ...
        'cp',{cpA,cpA,cpC},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1] ;
    pkg.reactions.DH = struct('value',-6,'unit',"kcal/mol") ;
    pkg.reactions.Tref = struct('value',273.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"s") ;
    k0 = 0.01*exp(10000*4.184/(8.314*300.15)) ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',k0, ...
        'Ea',struct('value',10000,'unit',"cal/mol"), ...
        'orders',[1 1 0],'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',27,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',[1 1 0],'valuesUnit',"mol/L", ...
        'Q',struct('value',2,'unit',"L/s")) ;
    nirp.pkg.validate(pkg) ;
end
