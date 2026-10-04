classdef NirpCollectionProblems4Test < matlab.unittest.TestCase
    % NirpCollectionProblems4Test verifies the fourth collection batch.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 4, 2026. Last update: October 4, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        Files
        FileGenerationConfig
        GeneratedFolder
    end

    methods (TestClassSetup)
        function createExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ; addpath(testCase.Folder) ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            testCase.addTeardown(@() removePath(testCase.SimulinkFolder)) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            testCase.GeneratedFolder = fullfile(testCase.Folder,'generated') ;
            Simulink.fileGenControl('set','CacheFolder', ...
                fullfile(testCase.GeneratedFolder,'cache'),'CodeGenFolder', ...
                fullfile(testCase.GeneratedFolder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl('setConfig', ...
                'config',testCase.FileGenerationConfig)) ;
            testCase.Files = build_examples(testCase.Folder) ;
        end
    end

    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function packagesAndExamplesAreRegistered(testCase)
            packages = {nirp.pkg.examples.problem29Hydrolysis(), ...
                nirp.pkg.examples.problem32AdiabaticCstr(), ...
                nirp.pkg.examples.problem48ReversibleGas()} ;
            for i = 1:numel(packages)
                testCase.verifyWarningFree(@() nirp.pkg.validate(packages{i})) ;
            end
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            expected = ["ex37_problem20b_adiabatic_reversible_pfr"; ...
                "ex38_problem29_cstr_volume"; ...
                "ex39_problem29_cooling_area"; ...
                "ex40_problem32_three_steady_states"; ...
                "ex41_problem48_cstr_then_adiabatic_pfr"; ...
                "ex42_problem33d_area_for_max_generation"] ;
            testCase.verifyEqual(names(37:42),expected) ;
            testCase.verifyTrue(all(strlength(descriptions(37:42)) > 20)) ;
            testCase.verifySubstring(descriptions(40),"unstable") ;
        end

        function problem32HasThreeSteadyStates(testCase)
            results = simulateExample(testCase.Files(40), ...
                "ex40_problem32_three_steady_states") ;
            pkg = nirp.pkg.examples.problem32AdiabaticCstr() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            names = ["ProductLow","ProductMiddle","ProductHigh"] ;
            guesses = [300 343 446] ;
            referenceX = [0.019840 0.299932 0.985140] ;
            referenceT = [300.9760 342.9899 445.7711] ;
            for i = 1:3
                expected = nirp.units.cstr(struct('V',18e-3, ...
                    'heatMode','Adiabatic','initialTemperatureGuess',guesses(i)), ...
                    feed,rs) ;
                actual = results.Streams.(names(i)).streamSI ;
                verifyStream(testCase,actual,expected,1e-9) ;
                testCase.verifyEqual(streamConversion(feed,actual), ...
                    referenceX(i),'AbsTol',1e-6) ;
                testCase.verifyEqual(actual.T,referenceT(i),'AbsTol',1e-3) ;
            end
        end

        function adjustedDiagramsMatchScriptsAndReferences(testCase)
            verifyProblem20(testCase,testCase.Files(37)) ;
            verifyProblem29(testCase,testCase.Files(38:39)) ;
            verifyProblem48(testCase,testCase.Files(41)) ;
            verifyProblem33d(testCase,testCase.Files(42)) ;
        end

        function derivedRowsMatchReferences(testCase)
            pkg33 = nirp.pkg.examples.problem33Gas() ;
            rs33 = nirp.pkg.toReactionSys(pkg33) ;
            feed33 = nirp.pkg.feedStream(pkg33,"F1") ;
            [equilibriumX,equilibriumT] = problem20Equilibrium() ;
            testCase.verifyEqual(equilibriumX,0.866637119317,'RelTol',1e-6) ;
            testCase.verifyEqual(equilibriumT,783.468559658,'RelTol',1e-6) ;

            objective = @(temperature) -streamConversion(feed33, ...
                nirp.units.cstr(struct('V',1.6,'heatMode','Specified T', ...
                'specifiedT',temperature),feed33,rs33)) ;
            [maximumT,negativeX] = fminbnd(objective,400,700, ...
                optimset('TolX',1e-10)) ;
            testCase.verifyEqual(maximumT,528.791487778,'RelTol',1e-6) ;
            testCase.verifyEqual(-negativeX,0.921980657504,'RelTol',1e-6) ;

            pkg29 = nirp.pkg.examples.problem29Hydrolysis() ;
            rs29 = nirp.pkg.toReactionSys(pkg29) ;
            feed29 = nirp.pkg.feedStream(pkg29,"F1") ;
            [~,info29] = nirp.units.cstr(struct('V',0.405965301820, ...
                'heatMode','Specified T','specifiedT',313.15),feed29,rs29) ;
            waterFlow = -info29.heatDuty/(4184*4) ;
            testCase.verifyEqual(waterFlow,0.396822711829,'RelTol',1e-6) ;

            pkg48 = nirp.pkg.examples.problem48ReversibleGas() ;
            rs48 = nirp.pkg.toReactionSys(pkg48) ;
            feed48 = nirp.pkg.feedStream(pkg48,"F1") ;
            [~,info48] = nirp.units.cstr(struct('V',0.0743517870876, ...
                'heatMode','Specified T','specifiedT',404.1),feed48,rs48) ;
            area48 = info48.heatDuty/(1200*(498.15-404.1)) ;
            testCase.verifyEqual(area48,8.70905251344,'RelTol',1e-6) ;
            heated = nirp.units.cstr(struct('V',0.0743517870876, ...
                'heatMode','Other','U',1200,'A',area48, ...
                'utilityTin',498.15),feed48,rs48) ;
            testCase.verifyEqual(heated.T,404.1,'RelTol',1e-6) ;
        end
    end
end

function verifyProblem20(testCase,file)
    name = "ex37_problem20b_adiabatic_reversible_pfr" ;
    results = simulateExample(file,name) ;
    pkg = nirp.pkg.examples.problem33Gas() ; rs = nirp.pkg.toReactionSys(pkg) ;
    feed = nirp.pkg.feedStream(pkg,"F1") ;
    volume = diagnosticParameter(results,name,"Adjust") ;
    expected = nirp.units.pfr(struct('V',volume,'D',0.1, ...
        'heatMode','Adiabatic'),feed,rs) ;
    verifyStream(testCase,results.Streams.Product.streamSI,expected,1e-9) ;
    testCase.verifyEqual(volume,0.149042202332,'RelTol',1e-5) ;
    [equilibriumX,~] = problem20Equilibrium() ;
    testCase.verifyEqual(results.Streams.Product.conversion, ...
        0.85*equilibriumX,'AbsTol',1e-6) ;
end

function verifyProblem29(testCase,files)
    pkg = nirp.pkg.examples.problem29Hydrolysis() ;
    rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
    volumeResults = simulateExample(files(1),"ex38_problem29_cstr_volume") ;
    volume = diagnosticParameter(volumeResults, ...
        "ex38_problem29_cstr_volume","Adjust") ;
    expectedVolume = nirp.units.cstr(struct('V',volume, ...
        'heatMode','Specified T','specifiedT',313.15),feed,rs) ;
    verifyStream(testCase,volumeResults.Streams.Product.streamSI, ...
        expectedVolume,1e-9) ;
    testCase.verifyEqual(volume,0.405965301820,'RelTol',1e-5) ;
    testCase.verifyEqual(volumeResults.Streams.Product.conversion,0.85, ...
        'AbsTol',1e-6) ;

    areaResults = simulateExample(files(2),"ex39_problem29_cooling_area") ;
    area = diagnosticParameter(areaResults, ...
        "ex39_problem29_cooling_area","Adjust") ;
    expectedArea = nirp.units.cstr(struct('V',0.405965302, ...
        'heatMode','Other','U',175,'A',area,'utilityTin',293.15, ...
        'utilityTout',297.15),feed,rs) ;
    verifyStream(testCase,areaResults.Streams.Product.streamSI,expectedArea,1e-9) ;
    testCase.verifyEqual(area,2.11706644345,'RelTol',1e-5) ;
    testCase.verifyEqual(areaResults.Streams.Product.streamSI.T,313.15, ...
        'AbsTol',1e-4) ;
end

function verifyProblem48(testCase,file)
    name = "ex41_problem48_cstr_then_adiabatic_pfr" ;
    results = simulateExample(file,name) ;
    pkg = nirp.pkg.examples.problem48ReversibleGas() ;
    rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
    cstrVolume = diagnosticParameter(results,name,"Adjust CSTR") ;
    pfrVolume = diagnosticParameter(results,name,"Adjust PFR") ;
    intermediate = nirp.units.cstr(struct('V',cstrVolume, ...
        'heatMode','Specified T','specifiedT',404.1),feed,rs) ;
    expected = nirp.units.pfr(struct('V',pfrVolume,'D',0.1, ...
        'heatMode','Adiabatic'),intermediate,rs) ;
    verifyStream(testCase,results.Streams.Product.streamSI,expected,1e-9) ;
    testCase.verifyEqual(cstrVolume,0.0743517870876,'RelTol',1e-5) ;
    testCase.verifyEqual(pfrVolume,0.0448824496173,'RelTol',1e-5) ;
    testCase.verifyEqual(streamConversion(feed, ...
        results.Streams.CSTROutlet.streamSI),0.2,'AbsTol',1e-6) ;
    testCase.verifyEqual(results.Streams.Product.conversion,0.25,'AbsTol',1e-6) ;
end

function verifyProblem33d(testCase,file)
    name = "ex42_problem33d_area_for_max_generation" ;
    results = simulateExample(file,name) ;
    pkg = nirp.pkg.examples.problem33Gas() ; rs = nirp.pkg.toReactionSys(pkg) ;
    feed = nirp.pkg.feedStream(pkg,"F1") ;
    area = diagnosticParameter(results,name,"Adjust") ;
    expected = nirp.units.cstr(struct('V',1.6,'heatMode','Other', ...
        'U',10,'A',area,'utilityTin',290.15, ...
        'initialTemperatureGuess',528.8),feed,rs) ;
    verifyStream(testCase,results.Streams.Product.streamSI,expected,1e-9) ;
    testCase.verifyEqual(area,94.6458,'RelTol',1e-5) ;
    testCase.verifyEqual(results.Streams.Product.streamSI.T,528.8,'AbsTol',1e-4) ;
    testCase.verifyEqual(results.Streams.Product.conversion,0.921981, ...
        'AbsTol',1e-6) ;
end

function [conversionValue,temperature] = problem20Equilibrium()
    temperature = @(conversion) 350.15+500*conversion ;
    equilibrium = @(value) (2*value)^2/(1-value)^2- ...
        (1.45e7/1.85e6)*exp(20000/(8.314*temperature(value))) ;
    conversionValue = fzero(equilibrium,[0.5 0.99]) ;
    temperature = temperature(conversionValue) ;
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ; load_system(char(file)) ;
    sim(char(name)) ; results = evalin('base','nirpResults') ;
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function value = diagnosticParameter(results,model,block)
    field = matlab.lang.makeValidName(model+"_"+block) ;
    value = results.Diagnostics.(field).lastInfo.value ;
end

function value = streamConversion(feed,product)
    value = (feed.F(1)-product.F(1))/feed.F(1) ;
end

function verifyStream(testCase,actual,expected,tolerance)
    testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance, ...
        'AbsTol',1e-12) ;
    testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance) ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
