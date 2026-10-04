function pkg = problem43Liquid()
%PROBLEM43LIQUID Return the elementary liquid package for problem 43.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 43 liquid") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","R","S"}, ...
        'Mw',{[],[],[],[]},'cp',{cp,cp,cp,cp},'hf',{[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1 1] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',25,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"s") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',1, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[1 1 0 0], ...
        'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',25,'unit',"C"),'P',struct('value',1,'unit',"atm"), ...
        'basis',"concentrations",'values',[1 1 0 0],'valuesUnit',"mol/L", ...
        'Q',struct('value',100,'unit',"m^3/h")) ;
    nirp.pkg.validate(pkg) ;
end
