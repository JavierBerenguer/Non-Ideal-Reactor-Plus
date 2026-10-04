function pkg = firstOrderLiquid()
%FIRSTORDERLIQUID Return the mixed-unit reference package from T-101.
%   PKG = nirp.pkg.examples.firstOrderLiquid() describes A -> B and an
%   exactly 300 K, 1 mol/s, 1e-3 m^3/s liquid feed.
%   Example: pkg = nirp.pkg.examples.firstOrderLiquid().
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"First-order liquid") ;
    cp = struct('type',"constant",'value',100,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B"},'Mw',{[],[]}, ...
        'cp',{cp,cp},'hf',{[],[]}) ;
    pkg.reactions.stoich = [-1 1] ;
    pkg.reactions.DH = struct('value',-50,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',26.85,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"min") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',0.6, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[1 0], ...
        'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',26.85,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"molarFlows", ...
        'values',[60 0],'valuesUnit',"mol/min", ...
        'Q',struct('value',60,'unit',"L/min")) ;
    nirp.pkg.validate(pkg) ;
end
