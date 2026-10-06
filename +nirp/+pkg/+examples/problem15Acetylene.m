function pkg = problem15Acetylene()
%PROBLEM15ACETYLENE Return the acetylene tetramerization package for problem 15.
%   4 C2H2 -> (C2H2)4 in an isothermal gas PFR at 550 C and 20 atm, with
%   -r_C2H2 = k*C^2 (k = 0.6 L/(mol*s)); per reaction extent r = k*C^2/4.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 6, 2026. Last update: October 6, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 15 acetylene PFR") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"C2H2","Tetramer","Inert"}, ...
        'Mw',{[],[],[]},'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-4 1 0] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',550,'unit',"C") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"s") ;
    % The statement gives the consumption rate of acetylene; the extent
    % rate of 4 C2H2 -> tetramer is a quarter of it.
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',0.6/4, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[2 0 0], ...
        'reverse',[],'expression',"") ;
    % 1000 m^3/h measured at the inlet conditions (550 C, 20 atm).
    totalFlow = 20*101325*(1000/3600)/(8.314*(550+273.15)) ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',550,'unit',"C"), ...
        'P',struct('value',20,'unit',"atm"),'basis',"totalAndFractions", ...
        'values',[totalFlow 0.8 0 0.2],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
