function pkg = problem30Liquid()
%PROBLEM30LIQUID Return the two-feed liquid package for problems 30 and 31.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problems 30 and 31 liquid") ;
    cpPO = struct('type',"constant",'value',35,'unit',"cal/(mol*K)") ;
    cpW = struct('type',"constant",'value',18,'unit',"cal/(mol*K)") ;
    cpPG = struct('type',"constant",'value',46,'unit',"cal/(mol*K)") ;
    cpMeOH = struct('type',"constant",'value',19.5,'unit',"cal/(mol*K)") ;
    pkg.components = struct('name',{"PO","W","PG","MeOH"}, ...
        'Mw',{[],[],[],[]},'cp',{cpPO,cpW,cpPG,cpMeOH}, ...
        'hf',{[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1 0] ;
    pkg.reactions.DH = struct('value',-84663.7,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',293.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"h") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',16.96e12, ...
        'Ea',struct('value',9064*8.314,'unit',"J/mol"), ...
        'orders',[1 0 0 0],'reverse',[],'expression',"") ;
    common = struct('name',"",'phase',"L", ...
        'T',struct('value',24,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"molarFlows", ...
        'values',zeros(1,4),'valuesUnit',"kmol/h", ...
        'Q',struct('value',0,'unit',"L/min")) ;
    % VolumetricFlow supports L/min, so the stated L/h values are divided by 60.
    pkg.feeds(1) = common ;
    pkg.feeds(1).name = "Feed PO" ;
    pkg.feeds(1).values = [1134/58.08 0 0 32.6] ;
    pkg.feeds(1).Q.value = (1134/0.859+32.6*32.04/0.7914)/60 ;
    pkg.feeds(2) = common ;
    pkg.feeds(2).name = "Feed W" ;
    pkg.feeds(2).values = [0 364.14 0 0] ;
    pkg.feeds(2).Q.value = (364.14*18.02/0.9941)/60 ;
    nirp.pkg.validate(pkg) ;
end
