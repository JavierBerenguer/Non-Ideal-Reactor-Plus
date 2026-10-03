function pkg = problem17AdiabaticGas()
%PROBLEM17ADIABATICGAS Return the adiabatic gas package for problem 17.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 17 adiabatic gas") ;
    cp = struct('type',"constant",'value',60,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"A","B","R","S"}, ...
        'Mw',{40,40,40,40},'cp',{cp,cp,cp,cp},'hf',{[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1 1] ;
    pkg.reactions.DH = struct('value',41.8,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',523.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"h") ;
    activationEnergy = 8.314*log(1000)/(1/373.15-1/773.15) ;
    expression = sprintf(['0.05*exp(-%.17g/8.314*(1/T-1/373.15))*' ...
        '(concentration(1)*0.082057*T)*(concentration(2)*0.082057*T)'], ...
        activationEnergy) ;
    pkg.reactions.kinetics = struct('type',"expression",'k0',[], ...
        'Ea',[],'orders',[],'reverse',[],'expression',string(expression)) ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',250,'unit',"C"), ...
        'P',struct('value',2,'unit',"atm"),'basis',"molarFlows", ...
        'values',[62.5 62.5 0 0],'valuesUnit',"mol/h",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
