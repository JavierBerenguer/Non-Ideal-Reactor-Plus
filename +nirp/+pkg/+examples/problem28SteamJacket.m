function pkg = problem28SteamJacket()
%PROBLEM28STEAMJACKET Return the endothermic liquid package for problem 28.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 28 steam jacket") ;
    heatCapacities = [83.7 83.7 167.4] ;
    cp = arrayfun(@(value) struct('type',"constant",'value',value, ...
        'unit',"J/(mol*K)"),heatCapacities,'UniformOutput',false) ;
    pkg.components = struct('name',{"A","B","C"},'Mw',{[],[],[]}, ...
        'cp',cp,'hf',{[],[],[]}) ;
    activationEnergy = 10000*8.314/(1.989*4.184) ;
    preexponential = 1.035/exp(-activationEnergy/(8.314*300)) ;
    pkg.reactions.stoich = [-1 -1 1] ;
    pkg.reactions.DH = struct('value',41.86,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',300,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"h") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',preexponential, ...
        'Ea',struct('value',activationEnergy,'unit',"J/mol"), ...
        'orders',[1 1 0],'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',300,'unit',"K"),'P',struct('value',1,'unit',"atm"), ...
        'basis',"concentrations",'values',[2 2 0],'valuesUnit',"mol/L", ...
        'Q',struct('value',30,'unit',"L/min")) ;
    nirp.pkg.validate(pkg) ;
end
