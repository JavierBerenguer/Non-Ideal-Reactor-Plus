function pkg = problem23ButaneIsomerization()
%PROBLEM23BUTANEISOMERIZATION Return the reversible liquid package for problem 23.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 23 butane isomerization") ;
    cpN = struct('type',"constant",'value',141,'unit',"J/(mol*K)") ;
    cpI = struct('type',"constant",'value',161,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"n-C4","i-C4","i-C5"}, ...
        'Mw',{[],[],[]},'cp',{cpN,cpN,cpI},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 1 0] ;
    pkg.reactions.DH = struct('value',-6900,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',293,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"h") ;
    reverse = struct('k0',6.9e11, ...
        'Ea',struct('value',72.6,'unit',"kJ/mol"),'orders',[0 1 0]) ;
    pkg.reactions.kinetics = struct('type',"reversible",'k0',1.7e11, ...
        'Ea',struct('value',65.7,'unit',"kJ/mol"), ...
        'orders',[1 0 0],'reverse',reverse,'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',330,'unit',"K"), ...
        'P',struct('value',20,'unit',"atm"),'basis',"totalAndFractions", ...
        'values',[163 0.9 0 0.1],'valuesUnit',"kmol/h", ...
        'Q',struct('value',0.9*163/9.3,'unit',"m^3/h")) ;
    nirp.pkg.validate(pkg) ;
end
