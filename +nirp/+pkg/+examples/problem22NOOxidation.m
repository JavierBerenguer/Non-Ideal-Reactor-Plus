function pkg = problem22NOOxidation()
%PROBLEM22NOOXIDATION Return the NO oxidation package for problem 22.
%   NO + 0.5 O2 -> NO2 in an adiabatic gas PFR at 1 bar, fed at 293 K with
%   gas saturated with water vapour; r = 119844*exp(-629.11/T)*C_NO^2*C_O2
%   in kmol/(m^3*s) with C in kmol/m^3 (the same as mol/(L*s) and mol/L).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 6, 2026. Last update: October 6, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 22 NO oxidation") ;
    cpValues = [29.9 29.4 37.9 29.1 37.6] ; % J/(mol*K)
    names = {"NO","O2","NO2","N2","H2O"} ;
    cp = cell(1,numel(cpValues)) ;
    for i = 1:numel(cpValues)
        cp{i} = struct('type',"constant",'value',cpValues(i), ...
            'unit',"J/(mol*K)") ;
    end
    pkg.components = struct('name',names,'Mw',{[],[],[],[],[]}, ...
        'cp',cp,'hf',{[],[],[],[],[]}) ;
    pkg.reactions.stoich = [-1 -0.5 1 0 0] ;
    pkg.reactions.DH = struct('value',-56.6,'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',293,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"s") ;
    % Sign of the exponent as printed in the statement (reproduces 165 m^3).
    pkg.reactions.kinetics = struct('type',"expression",'k0',[], ...
        'Ea',[],'orders',[],'reverse',[],'expression', ...
        "119844*exp(-629.11/T)*concentration(1)^2*concentration(2)") ;
    % 10700 m^3/h measured at 293 K and 1 atm; water at its vapour pressure.
    totalFlow = 101325*(10700/3600)/(8.314*293) ;
    waterFraction = 17.5/760 ;
    fractions = [0.09 0.08 0.01 1-0.09-0.08-0.01-waterFraction waterFraction] ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',293,'unit',"K"), ...
        'P',struct('value',1,'unit',"bar"),'basis',"totalAndFractions", ...
        'values',[totalFlow fractions],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
