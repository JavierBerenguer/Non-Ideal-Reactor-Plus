function pkg = problem35NOReduction()
%PROBLEM35NOREDUCTION Return the selective NO-reduction package for problem 35.
%   The 200 L CSTR is represented as liquid so its 0.15 m^3/s volumetric
%   flow remains constant, matching the statement's same-output-flow
%   assumption. Rates use concentration in mol/m^3 and time in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1, ...
        'name',"Problem 35 selective NO reduction") ;
    cpValues = [29.9 35.15 29.4 29.1 37.6] ; % J/(mol*K)
    names = {"NO","NH3","O2","N2","H2O"} ;
    cp = cell(1,numel(cpValues)) ;
    for i = 1:numel(cpValues)
        cp{i} = struct('type',"constant",'value',cpValues(i), ...
            'unit',"J/(mol*K)") ;
    end
    pkg.components = struct('name',names,'Mw',{[],[],[],[],[]}, ...
        'cp',cp,'hf',{[],[],[],[],[]}) ;
    pkg.reactions.stoich = [-4 -4 -1 4 6; 0 -4 -3 2 6] ;
    pkg.reactions.DH = struct('value',[-1627.7 -1266.22], ...
        'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',298.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3",'time',"s") ;
    common = struct('type',"expression",'k0',[],'Ea',[], ...
        'orders',[],'reverse',[],'expression',"") ;
    kinetics = repmat(common,1,2) ;
    activity = "(2.68e-17*exp(213000/(8.314*T)))" ;
    kinetics(1).expression = "1e6*exp(-60000/(8.314*T))*concentration(1)*"+ ...
        activity+"*concentration(2)/(1+"+activity+"*concentration(2))" ;
    kinetics(2).expression = ...
        "6.8e7*exp(-85000/(8.314*T))*concentration(2)" ;
    pkg.reactions.kinetics = kinetics ;
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',500,'unit',"K"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations", ...
        'values',[0.016 0.022 0.947 0 0],'valuesUnit',"mol/m^3", ...
        'Q',struct('value',0.15,'unit',"m^3/s")) ;
    nirp.pkg.validate(pkg) ;
end
