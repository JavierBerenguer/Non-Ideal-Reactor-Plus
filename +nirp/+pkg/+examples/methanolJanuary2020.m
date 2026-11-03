function pkg = methanolJanuary2020()
%METHANOLJANUARY2020 Return the package for the January 2020 methanol exam.
%   The statement specifies mole fractions totalling 0.91. The remaining
%   0.09 is represented by inert N2 with Cp = 29.1 J/(mol*K).
% =========================================================================
% Javier Berenguer Sabater
% Created: November 4, 2026. Last update: November 4, 2026
% =========================================================================

    pkg = methanolPackage(true) ;
    pkg.meta.name = "Methanol January 2020 exam" ;
    pkg.feeds = struct('name',"Feed",'phase',"G", ...
        'T',struct('value',285,'unit',"C"), ...
        'P',struct('value',150,'unit',"bar"), ...
        'basis',"molarFlows",'values',[840 2400 0 400 0 360], ...
        'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end

function pkg = methanolPackage(includeNitrogen)
    pkg.meta = struct('formatVersion',1,'name',"",'thermodynamics',true) ;
    names = {"CO","H2","CH3OH","CO2","H2O"} ;
    heatCapacities = [31.75 29.21 195.7 53.10 112.6] ;
    if includeNitrogen
        names{end+1} = "N2" ;
        heatCapacities(end+1) = 29.1 ;
    end
    cp = arrayfun(@(value) struct('type',"constant",'value',value, ...
        'unit',"J/(mol*K)"),heatCapacities,'UniformOutput',false) ;
    molecularWeights = repmat({[]},size(heatCapacities)) ;
    pkg.components = struct('name',names,'Mw',molecularWeights, ...
        'cp',cp,'hf',repmat({[]},size(heatCapacities))) ;

    stoichiometry = [-1 -2 1 0 0;1 2 -1 0 0; ...
        0 -3 1 -1 1;0 3 -1 1 -1] ;
    if includeNitrogen, stoichiometry(:,end+1) = 0 ; end
    pkg.reactions.stoich = stoichiometry ;
    pkg.reactions.DH = struct('value',[-90.7 90.7 -49.32 49.32], ...
        'unit',"kJ/mol") ;
    pkg.reactions.Tref = struct('value',298,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3", ...
        'time',"s") ;
    expressions = { ...
        "165*exp(-66200/(8.314*T))*concentration(1)*concentration(2)", ...
        "4.1e17*exp(-164588/(8.314*T))*concentration(3)/concentration(2)", ...
        "0.012*exp(-25800/(8.314*T))*concentration(2)*concentration(4)", ...
        "2.80e11*exp(-84505/(8.314*T))*concentration(3)*" + ...
        "concentration(5)/concentration(2)^2"} ;
    common = struct('type',"expression",'k0',[],'Ea',[],'orders',[], ...
        'reverse',[],'expression',"") ;
    pkg.reactions.kinetics = repmat(common,1,4) ;
    for index = 1:4
        pkg.reactions.kinetics(index).expression = expressions{index} ;
    end
end
