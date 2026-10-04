function pkg = problem48ReversibleGas()
%PROBLEM48REVERSIBLEGAS Return the reversible gas package for problem 48.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 48 reversible gas") ;
    cpA = struct('type',"constant",'value',150,'unit',"cal/(mol*K)") ;
    cpR = struct('type',"constant",'value',100,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"A","R"},'Mw',{[],[]}, ...
        'cp',{cpA,cpR},'hf',{[],[]}) ;
    pkg.reactions.stoich = [-2 3] ;
    % -37600 J/mol A and two A per reaction extent.
    pkg.reactions.DH = struct('value',-75200,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',298.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"min") ;
    reverse = struct('k0',1.1e18, ...
        'Ea',struct('value',124200,'unit',"J/mol"),'orders',[0 3]) ;
    pkg.reactions.kinetics = struct('type',"reversible",'k0',1.6e7, ...
        'Ea',struct('value',49000,'unit',"J/mol"),'orders',[2 0], ...
        'reverse',reverse,'expression',"") ;
    pressure = 1000*8.314*298.15 ; % Pa, so pure-A C_A0 is 1 mol/L.
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',298.15,'unit',"K"), ...
        'P',struct('value',pressure,'unit',"Pa"),'basis',"molarFlows", ...
        'values',[1000 0],'valuesUnit',"mol/min",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
