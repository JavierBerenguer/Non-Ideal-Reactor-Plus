function pkg = problem29Hydrolysis()
%PROBLEM29HYDROLYSIS Return the acetic-anhydride hydrolysis package.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    pkg.meta = struct('formatVersion',1,'name',"Problem 29 hydrolysis") ;
    cp = struct('type',"constant",'value',73.1,'unit',"J/(mol*K)") ;
    pkg.components = struct('name',{"A","W","B"}, ...
        'Mw',{102.09,18.02,60.05},'cp',{cp,cp,cp},'hf',{[],[],[]}) ;
    pkg.reactions.stoich = [-1 -1 2] ;
    % The statement gives -29300 kJ/kmol of acetic acid. Two acid moles
    % are produced per mole of reaction extent, hence -58600 J/mol.
    pkg.reactions.DH = struct('value',-58600,'unit',"J/mol") ;
    pkg.reactions.Tref = struct('value',313.15,'unit',"K") ;
    pkg.reactions.rateUnits = struct('concentration',"mol/L",'time',"min") ;
    pkg.reactions.kinetics = struct('type',"powerlaw",'k0',0.38, ...
        'Ea',struct('value',0,'unit',"J/mol"),'orders',[1 0 0], ...
        'reverse',[],'expression',"") ;

    % 50 kg/h of 98 wt% acid at 85% yield determines the anhydride feed.
    acidFlow = 50*0.98/60.05 ;                 % kmol/h
    anhydrideFlow = acidFlow/(2*0.85) ;        % kmol/h
    anhydrideMass = anhydrideFlow*102.09 ;     % kg/h
    solutionMass = anhydrideMass/0.03 ;        % kg/h at 3 wt% A
    waterFlow = (solutionMass-anhydrideMass)/18.02 ; % kmol/h
    volumetricFlow = solutionMass/1000 ;       % m^3/h at 1000 kg/m^3
    pkg.feeds = struct('name',"F1",'phase',"L", ...
        'T',struct('value',313.15,'unit',"K"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"molarFlows", ...
        'values',[anhydrideFlow waterFlow 0],'valuesUnit',"kmol/h", ...
        'Q',struct('value',volumetricFlow,'unit',"m^3/h")) ;
    nirp.pkg.validate(pkg) ;
end
