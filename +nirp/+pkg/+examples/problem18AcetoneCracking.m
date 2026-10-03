function pkg = problem18AcetoneCracking()
%PROBLEM18ACETONECRACKING Return the acetone-cracking package for problem 18.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 18 acetone cracking") ;
    cpAcetone = struct('type',"constant",'value',164,'unit',"J/(mol*K)") ;
    cpKetene = struct('type',"constant",'value',96,'unit',"J/(mol*K)") ;
    cpMethane = struct('type',"constant",'value',60,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"Acetone","Ketene","Methane"}, ...
        'Mw',{58.08,[],[]},'cp',{cpAcetone,cpKetene,cpMethane}, ...
        'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 1 1] ;
    pkg.reactions.DH = struct('value',80.8,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',298,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3",'time',"s") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',exp(34.34), ...
        'Ea',struct('value',34222*8.314,'unit',"J/mol"), ...
        'orders',[1 0 0],'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',1035,'unit',"K"), ...
        'P',struct('value',1.6,'unit',"atm"),'basis',"molarFlows", ...
        'values',[8000/58.08 0 0],'valuesUnit',"kmol/h",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
