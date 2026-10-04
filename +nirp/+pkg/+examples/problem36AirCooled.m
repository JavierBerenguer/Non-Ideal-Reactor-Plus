function pkg = problem36AirCooled()
%PROBLEM36AIRCOOLED Return the two-reaction liquid package for problem 36.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 36 air-cooled CSTR") ;
    heatCapacities = [15 11 12 14 18] ;
    cp = arrayfun(@(value) struct('type',"constant",'value',value, ...
        'unit',"cal/(mol*K)"),heatCapacities,'UniformOutput',false) ;
    pkg.components = struct('name',{"A","B","R","S","W"}, ...
        'Mw',{[],[],[],[],18},'cp',cp,'hf',{[],[],[],[],[]}) ;
    pkg.reactions.stoich = [-2 -3 2 0 0;-2 -3 0 2 0] ;
    pkg.reactions.DH = struct('value',[-7530 -7710],'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',25,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"min") ;
    common = struct('type',"powerlaw",'k0',0, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',zeros(1,5), ...
        'reverse',[],'expression',"") ;
    pkg.reactions.kinetics(1) = common ;
    pkg.reactions.kinetics(1).k0 = 3.7e7 ;
    pkg.reactions.kinetics(1).Ea.value = 49000 ;
    pkg.reactions.kinetics(1).orders = [1.5 0.3 0 0 0] ;
    pkg.reactions.kinetics(2) = common ;
    pkg.reactions.kinetics(2).k0 = 1e7 ;
    pkg.reactions.kinetics(2).Ea.value = 50000 ;
    pkg.reactions.kinetics(2).orders = [0.5 1.8 0 0 0] ;
    feed = struct('name',"",'phase',"L",'T',struct('value',30,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',zeros(1,5),'valuesUnit',"mol/L", ...
        'Q',struct('value',50,'unit',"L/min")) ;
    pkg.feeds(1) = feed ; pkg.feeds(1).name = "Feed A" ;
    pkg.feeds(1).values = [20 0 0 0 36] ;
    pkg.feeds(2) = feed ; pkg.feeds(2).name = "Feed B" ;
    pkg.feeds(2).values = [0 40 0 0 25] ;
    nirp.pkg.validate(pkg) ;
end
