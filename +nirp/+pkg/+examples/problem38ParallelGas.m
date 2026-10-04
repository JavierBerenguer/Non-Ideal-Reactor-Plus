function pkg = problem38ParallelGas()
%PROBLEM38PARALLELGAS Return the parallel-PFR gas package for problem 38.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 38 parallel gas PFRs") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","B","Inert"}, ...
        'Mw',{[],[],[]},'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 3 0] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',623.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3",'time',"s") ;
    epsilon = 2 ; conversion = 0.6 ;
    pilotVolume = pi*0.0125^2*2 ;
    pilotFlow = 4/3600 ;
    inletConcentration = 5*101325/(8.314*623.15) ;
    numerator = 2*epsilon*(1+epsilon)*log(1-conversion)+ ...
        epsilon^2*conversion+(1+epsilon)^2*conversion/(1-conversion) ;
    % Derived from the 25 mm diameter, 2 m pilot PFR in the statement.
    rateConstant = numerator/((pilotVolume/pilotFlow)*inletConcentration) ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',rateConstant, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[2 0 0], ...
        'reverse',[],'expression',"") ;
    totalFlow = 25*101325*(320/3600)/(8.314*623.15) ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',350,'unit',"C"), ...
        'P',struct('value',25,'unit',"atm"),'basis',"totalAndFractions", ...
        'values',[totalFlow 0.6 0 0.4],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
