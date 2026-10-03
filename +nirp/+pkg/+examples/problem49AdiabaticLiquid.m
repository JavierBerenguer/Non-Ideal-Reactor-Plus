function pkg = problem49AdiabaticLiquid()
%PROBLEM49ADIABATICLIQUID Return the reversible liquid package for problem 49.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 49 adiabatic liquid") ;
    cp = struct('type',"constant",'value',251,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C"}, ...
        'Mw',{[],[],[]},'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-2 1 1] ;
    pkg.reactions.DH = struct('value',-8000,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',311.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"h") ;
    reverse = struct('k0',0.204, ...
        'Ea',struct('value',40281,'unit',"J/mol"),'orders',[0 1 1]) ;
    pkg.reactions.kinetics = struct('type',"reversible",'k0',39363, ...
        'Ea',struct('value',32281,'unit',"J/mol"), ...
        'orders',[2 0 0],'reverse',reverse,'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',38,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',[24 0 0],'valuesUnit',"mol/L", ...
        'Q',struct('value',2.8,'unit',"m^3/h")) ;
    nirp.pkg.validate(pkg) ;
end
