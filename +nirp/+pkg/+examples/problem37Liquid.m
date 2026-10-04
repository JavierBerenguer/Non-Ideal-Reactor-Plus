function pkg = problem37Liquid()
%PROBLEM37LIQUID Return the package for collection problem 37a.
%   PKG = nirp.pkg.examples.problem37Liquid() describes the two liquid
%   feeds for the elementary A + B -> C reaction in the problem statement.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 37a liquid") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","C"},'Mw',{[],[],[]}, ...
        'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 1] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',25,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L", ...
        'time',"min") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',0.025, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[1 1 0], ...
        'reverse',[],'expression',"") ;
    common = struct('name',"",'phase',"L", ...
        'T',struct('value',25,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',zeros(1,3),'valuesUnit',"mol/L", ...
        'Q',struct('value',10,'unit',"L/min")) ;
    pkg.feeds(1) = common ;
    pkg.feeds(1).name = "Feed A" ;
    pkg.feeds(1).values = [2 0 0] ;
    pkg.feeds(2) = common ;
    pkg.feeds(2).name = "Feed B" ;
    pkg.feeds(2).values = [0 2 0] ;
    nirp.pkg.validate(pkg) ;
end
