function pkg = problem26ScaleUpGas()
%PROBLEM26SCALEUPGAS Return the gas CSTR scale-up package for problem 26.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 26 gas scale-up") ;
    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"Acetaldehyde","Methane","CO"}, ...
        'Mw',{44.05,[],[]},'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 1 1] ;
    pkg.reactions.DH = struct('value',0,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',793.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/m^3",'time',"s") ;
    laboratoryFlow = (25/44.05)/3600 ;
    laboratoryConversion = 0.8 ;
    inletConcentration = 101325/(8.314*793.15) ;
    outletConcentration = inletConcentration*(1-laboratoryConversion)/ ...
        (1+laboratoryConversion) ;
    % Derived from the 100 L, 25 g/h laboratory CSTR in the statement.
    rateConstant = laboratoryFlow*laboratoryConversion/ ...
        (0.1*outletConcentration^2) ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',rateConstant, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[2 0 0], ...
        'reverse',[],'expression',"") ;
    pkg.feeds = struct('name',"F1",'phase',"G", ...
        'T',struct('value',520,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"molarFlows", ...
        'values',[0.1/0.04405 0 0],'valuesUnit',"mol/s",'Q',[]) ;
    nirp.pkg.validate(pkg) ;
end
