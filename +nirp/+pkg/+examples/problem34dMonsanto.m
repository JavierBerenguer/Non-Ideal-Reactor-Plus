function pkg = problem34dMonsanto()
%PROBLEM34DMONSANTO Return the jacketed liquid package for problem 34d.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 34d Monsanto reaction") ;
    cpA = struct('type',"constant",'value',40,'unit',"cal/(mol*K)") ;
    cpB = struct('type',"constant",'value',8.38,'unit',"cal/(mol*K)") ;
    cpProduct = struct('type',"constant",'value',28.38,'unit',"cal/(mol*K)") ;
    cpWater = struct('type',"constant",'value',18,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C","D","W"}, ...
        'Mw',{158.5,17.03,[],[],18.02}, ...
        'cp',{cpA,cpB,cpProduct,cpProduct,cpWater}, ...
        'hf',{[],[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -2 1 1 0] ;
    pkg.reactions.DH = struct('value',-5.9e5,'unit',"cal/mol") ;
    pkg.reactions.Tref = struct('value',298.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"min") ;
    activationEnergy = 11273*4.184 ;
    preexponential = 0.00017/exp(-activationEnergy/(8.314*461.15)) ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',preexponential, ...
        'Ea',struct('value',11273,'unit',"cal/mol"), ...
        'orders',[1 1 0 0 0],'reverse',[],'expression',"") ;
    volumetricFlow = (9.044*158.5+33.0*17.03+103.7*18.02)/1100 ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',15,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"molarFlows", ...
        'values',[9.044 33.0 0 0 103.7],'valuesUnit',"kmol/min", ...
        'Q',struct('value',volumetricFlow,'unit',"m^3/min")) ;
    nirp.pkg.validate(pkg) ;
end
