classdef NirpCollectionProblems5Test < matlab.unittest.TestCase
    % NirpCollectionProblems5Test verifies problems 15 and 22 and the
    % problem 20b Adjust with default settings (T-128).
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 6, 2026. Last update: October 6, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        Files
        FileGenerationConfig
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
            generated = fullfile(testCase.Folder,'generated') ;
            Simulink.fileGenControl('set','CacheFolder',fullfile(generated,'cache'), ...
                'CodeGenFolder',fullfile(generated,'codegen'),'createDir',true) ;
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
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.problem15Acetylene())) ;
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.problem22NOOxidation())) ;
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            testCase.verifyEqual(names(43:44),["ex43_problem15_number_of_tubes"; ...
                "ex44_problem22_no_oxidation"]) ;
            testCase.verifyTrue(all(strlength(descriptions(43:44)) > 20)) ;
            testCase.verifyEqual(numel(testCase.Files),44) ;
        end

        function problem20bConvergesWithDefaultAdjust(testCase)
            name = "ex37_problem20b_adiabatic_reversible_pfr" ;
            load_system(char(testCase.Files(37))) ;
            adjust = [char(name) '/Adjust'] ;
            testCase.verifyEqual(str2double(get_param(adjust,'Damping')),1) ;
            testCase.verifyEqual(str2double(get_param(adjust,'Tolerance')),1e-10) ;
            close_system(char(name),0) ;
            results = simulateExample(testCase.Files(37),name) ;
            volume = diagnosticParameter(results,name,"Adjust") ; % m^3
            testCase.verifyEqual(volume,149.042202e-3,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.736642, ...
                'AbsTol',1e-6) ;
        end

        function problem15FindsTheNumberOfTubes(testCase)
            name = "ex43_problem15_number_of_tubes" ;
            results = simulateExample(testCase.Files(43),name) ;
            volume = diagnosticParameter(results,name,"Adjust") ; % m^3
            pkg = nirp.pkg.examples.problem15Acetylene() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            pfr = @(v) nirp.units.pfr(struct('V',v,'D',0.2, ...
                'heatMode','Isothermal'),feed,rs) ;
            tubeVolume = pi*0.1^2*3.5 ; % m^3
            testCase.verifyEqual(volume,1.750730,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.6,'AbsTol',1e-6) ;
            verifyStream(testCase,results.Streams.Product.streamSI,pfr(volume),1e-9) ;
            testCase.verifyEqual(ceil(volume/tubeVolume),16) ;
            testCase.verifyGreaterThanOrEqual(streamConversion(feed,pfr(16*tubeVolume)),0.6) ;
            testCase.verifyLessThan(streamConversion(feed,pfr(15*tubeVolume)),0.6) ;
            testCase.verifyEqual(streamConversion(feed,pfr(16*tubeVolume)),0.601707, ...
                'AbsTol',1e-6) ;
        end

        function problem22ReachesNO2ToNORatioOfFive(testCase)
            name = "ex44_problem22_no_oxidation" ;
            results = simulateExample(testCase.Files(44),name) ;
            volume = diagnosticParameter(results,name,"Adjust") ; % m^3
            pkg = nirp.pkg.examples.problem22NOOxidation() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            expected = nirp.units.pfr(struct('V',volume,'D',1, ...
                'heatMode','Adiabatic'),feed,rs) ;
            product = results.Streams.Product.streamSI ;
            testCase.verifyEqual(volume,164.6830,'RelTol',1e-5) ;
            testCase.verifyEqual(product.T,436.184,'AbsTol',1e-2) ;
            testCase.verifyEqual(product.F(3)/product.F(1),5,'RelTol',1e-5) ;
            verifyStream(testCase,product,expected,1e-9) ;
            testCase.verifyEqual(round(volume),165) ;
        end
    end
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
