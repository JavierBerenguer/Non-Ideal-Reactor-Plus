classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpMethanolExamsTest < matlab.unittest.TestCase
    % NirpMethanolExamsTest verifies the January 2020 and 2022 examples.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 4, 2026. Last update: November 4, 2026
    % =========================================================================

    properties
        Files
    end

    methods (TestClassSetup)
        function useBuiltExamples(testCase)
            examples = testCase.getSharedTestFixtures( ...
                'nirptest.ExamplesFixture') ;
            testCase.Files = examples.Files ;
        end
    end

    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all') ;
            Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function packagesAndExamplesAreRegistered(testCase)
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.methanolJanuary2020())) ;
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.methanolJanuary2022())) ;
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            testCase.verifyEqual(names(55:56), ...
                ["ex55_methanol_exam_january2020"; ...
                "ex56_methanol_exam_january2022"]) ;
            testCase.verifyEqual(descriptions(55:56), ...
                ["Methanol: January 2020 exam - three adiabatic PFRs"; ...
                "Methanol: January 2022 exam - adiabatic and cooled PFRs"]) ;
            testCase.verifyEqual(numel(testCase.Files),56) ;
        end

        function january2020MatchesIndependentReference(testCase)
            name = "ex55_methanol_exam_january2020" ;
            results = simulateExample(testCase.Files(55),name) ;
            reference = methanolJanuary2020Reference() ;
            verifyState(testCase,resultStream(results,'PFR 1 outlet'), ...
                reference.pfr1) ;
            verifyState(testCase,resultStream(results,'PFR 2 outlet'), ...
                reference.pfr2) ;
            verifyState(testCase,resultStream(results,'Product'), ...
                reference.pfr3) ;
            testCase.verifyEqual(resultStream(results,'Heater 2 outlet').T, ...
                reference.heater2T,'RelTol',1e-4) ;
            testCase.verifyEqual(resultStream(results,'Heater 3 outlet').T, ...
                reference.heater3T,'RelTol',1e-4) ;
            testCase.verifyEqual(resultStream(results,'PFR 2 inlet').T, ...
                623.15,'AbsTol',0.01) ;
            testCase.verifyEqual(resultStream(results,'PFR 3 inlet').T, ...
                673.15,'AbsTol',0.01) ;
            verifyAtomicBalance(testCase,[840 2400 0 400 0 360]', ...
                resultStream(results,'Product').F,true) ;
            testCase.verifyEqual(resultStream(results,'Product').F(6),360, ...
                'RelTol',1e-12) ;

            description = modelDescription(testCase.Files(55),name) ;
            testCase.verifySubstring(description,'inert N2') ;
            profile = diagnosticInfo(results,name,"PFR 3").profile ;
            testCase.verifyEqual(reshape(string(profile.componentNames),1,[]), ...
                ["CO" "H2" "CH3OH" "CO2" "H2O" "N2"]) ;
            testCase.verifySize(profile.F,[201 6]) ;
        end

        function january2022MatchesIndependentReference(testCase)
            name = "ex56_methanol_exam_january2022" ;
            results = simulateExample(testCase.Files(56),name) ;
            reference = methanolJanuary2022Reference() ;
            pfr1 = resultStream(results,'PFR 1 outlet') ;
            product = resultStream(results,'Product') ;
            verifyState(testCase,pfr1,reference.pfr1) ;
            verifyState(testCase,product,reference.pfr2) ;
            heater = resultStream(results,'Heater outlet') ;
            testCase.verifyEqual(heater.T,pfr1.T,'RelTol',1e-10) ;
            testCase.verifyEqual(heater.T,reference.heaterT,'RelTol',1e-4) ;
            testCase.verifyEqual(resultStream(results,'PFR 2 inlet').T, ...
                pfr1.T,'RelTol',1e-10) ;
            verifyAtomicBalance(testCase,[840 2600 0 560 0]',product.F,false) ;

            pfr2Info = diagnosticInfo(results,name,"PFR 2") ;
            pfr1Info = diagnosticInfo(results,name,"PFR 1") ;
            testCase.verifyEqual(pfr2Info.heatDuty,-1.8e7,'RelTol',1e-12) ;
            heatPerLength = diff(pfr2Info.profile.Q)./ ...
                diff(pfr2Info.profile.L) ;
            testCase.verifyEqual(heatPerLength, ...
                repmat(-1.8e7/4,size(heatPerLength)),'RelTol',1e-8, ...
                'AbsTol',0.1) ;
            testCase.verifySize(pfr1Info.profile.F,[201 5]) ;
            testCase.verifySize(pfr2Info.profile.F,[201 5]) ;
            description = modelDescription(testCase.Files(56),name) ;
            testCase.verifySubstring(description, ...
                'Heater outlet set to the PFR 1 outlet temperature') ;
            testCase.verifySubstring(description,'-1.8e7 W total') ;
        end
    end
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ;
    load_system(char(file)) ; sim(char(name)) ;
    results = evalin('base','nirpResults') ;
    close_system(char(name),0) ;
    Simulink.data.dictionary.closeAll('-discard') ;
end

function description = modelDescription(file,name)
    load_system(char(file)) ;
    description = string(get_param(char(name),'Description')) ;
    close_system(char(name),0) ;
    Simulink.data.dictionary.closeAll('-discard') ;
end

function stream = resultStream(results,name)
    key = matlab.lang.makeValidName(name) ;
    stream = results.Streams.(key).streamSI ;
end

function info = diagnosticInfo(results,model,block)
    key = matlab.lang.makeValidName(model+"_"+block) ;
    info = results.Diagnostics.(key).lastInfo ;
end

function verifyState(testCase,actual,reference)
    testCase.verifyEqual(actual.F,reference.F,'RelTol',1e-4, ...
        'AbsTol',1e-9) ;
    testCase.verifyEqual(actual.T,reference.T,'RelTol',1e-4) ;
end

function verifyAtomicBalance(testCase,feed,product,includeNitrogen)
    atoms = [1 0 1 1 0;0 2 4 0 2;1 0 1 2 1] ;
    if includeNitrogen, atoms(:,end+1) = 0 ; end
    inletTotals = atoms*feed ; outletTotals = atoms*product ;
    relative = abs(outletTotals-inletTotals)./max(abs(inletTotals),1) ;
    testCase.verifyLessThanOrEqual(relative,repmat(1e-8,3,1)) ;
end

function reference = methanolJanuary2020Reference()
    cp = [31.75 29.21 195.7 53.10 112.6 29.1] ;
    stoichiometry = [-1 -2 1 0 0 0;1 2 -1 0 0 0; ...
        0 -3 1 -1 1 0;0 3 -1 1 -1 0] ;
    branch = [840 2400 0 400 0 360]'/3 ;
    reference.pfr1 = methanolPfrReference(branch,558.15,1,0, ...
        cp,stoichiometry) ;
    reference.heater2T = fzero(@(temperature) methanolMixTemperature( ...
        reference.pfr1.F,reference.pfr1.T,branch,temperature,cp)-623.15, ...
        [500 900]) ;
    reference.pfr2 = methanolPfrReference(reference.pfr1.F+branch, ...
        623.15,1,0,cp,stoichiometry) ;
    reference.heater3T = fzero(@(temperature) methanolMixTemperature( ...
        reference.pfr2.F,reference.pfr2.T,branch,temperature,cp)-673.15, ...
        [500 1000]) ;
    reference.pfr3 = methanolPfrReference(reference.pfr2.F+branch, ...
        673.15,1,0,cp,stoichiometry) ;
end

function reference = methanolJanuary2022Reference()
    cp = [31.75 29.21 195.7 53.10 112.6] ;
    stoichiometry = [-1 -2 1 0 0;1 2 -1 0 0; ...
        0 -3 1 -1 1;0 3 -1 1 -1] ;
    branch = [840 2600 0 560 0]'/2 ;
    reference.pfr1 = methanolPfrReference(branch,473.15,0.8,0, ...
        cp,stoichiometry) ;
    reference.heaterT = reference.pfr1.T ;
    reference.pfr2 = methanolPfrReference(reference.pfr1.F+branch, ...
        reference.heaterT,4,-1.8e7,cp,stoichiometry) ;
end

function outlet = methanolPfrReference(feed,temperature,length,Q,cp,stoichiometry)
    initial = [feed(:);temperature] ;
    tolerance = [max(1e-11*abs(feed(:)),1e-12);1e-9] ;
    options = odeset('RelTol',1e-10,'AbsTol',tolerance) ;
    [~,states] = ode15s(@(~,state) methanolPfrDerivative( ...
        state,length,Q,cp,stoichiometry),[0 length],initial,options) ;
    outlet = struct('F',states(end,1:numel(feed))', ...
        'T',states(end,numel(feed)+1)) ;
end

function derivative = methanolPfrDerivative(state,length,Q,cp,stoichiometry)
    gasConstant = 8.314 ; pressure = 150e5 ;
    totalArea = 5000*pi*(0.025/2)^2 ;
    flows = state(1:numel(cp))' ; temperature = state(end) ;
    concentration = flows/sum(flows)*pressure/(gasConstant*temperature) ;
    rateConstants = [165 4.1e17 0.012 2.80e11].*exp( ...
        -[66200 164588 25800 84505]/(gasConstant*temperature)) ;
    rates = [rateConstants(1)*concentration(1)*concentration(2), ...
        rateConstants(2)*concentration(3)/concentration(2), ...
        rateConstants(3)*concentration(2)*concentration(4), ...
        rateConstants(4)*concentration(3)*concentration(5)/ ...
        concentration(2)^2] ;
    baseCp = cp(1:5) ;
    reactionEnthalpy = [-90.7e3 90.7e3 -49.32e3 49.32e3]+ ...
        (temperature-298)*(stoichiometry(:,1:5)*baseCp')' ;
    flowDerivative = totalArea*(rates*stoichiometry) ;
    temperatureDerivative = (Q/length-totalArea* ...
        sum(rates.*reactionEnthalpy))/(flows*cp') ;
    derivative = [flowDerivative';temperatureDerivative] ;
end

function temperature = methanolMixTemperature(flow1,T1,flow2,T2,cp)
    temperature = (flow1'*cp'*T1+flow2'*cp'*T2)/ ...
        ((flow1+flow2)'*cp') ;
end
