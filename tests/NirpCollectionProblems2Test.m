classdef NirpCollectionProblems2Test < matlab.unittest.TestCase
    % NirpCollectionProblems2Test verifies the second collection batch.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 3, 2026. Last update: October 3, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ; addpath(testCase.Folder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl( ...
                'setConfig','config',testCase.FileGenerationConfig)) ;
            testCase.addTeardown(@() removePath(testCase.SimulinkFolder)) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            testCase.addTeardown(@() closeModels()) ;
        end
    end

    methods (Test)
        function diagramsMatchScriptsAndReferences(testCase)
            files = build_examples(testCase.Folder) ;
            testCase.verifyProblem21(files(13:14)) ;
            testCase.verifyProblem27(files(15)) ;
            testCase.verifyProblems30And31(files(16:17)) ;
            testCase.verifyProblem44a(files(18)) ;
            testCase.verifyProblem45(files(19:20)) ;
        end

        function examplesAreRegistered(testCase)
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            expected = ["ex13_problem21a_isothermal_pfr"; ...
                "ex14_problem21b_adiabatic_pfr"; ...
                "ex15_problem27_jacketed_cstr"; ...
                "ex16_problem30_adiabatic_cstr"; ...
                "ex17_problem31_cooled_cstr"; ...
                "ex18_problem44a_volumes"; ...
                "ex19_problem45a_three_cstrs"; ...
                "ex20_problem45b_feed_temperature"] ;
            testCase.verifyEqual(names(13:20),expected) ;
            testCase.verifyTrue(all(strlength(descriptions(13:20)) > 20)) ;
        end

        function packagesAreValid(testCase)
            packages = {nirp.pkg.examples.problem21Gas(), ...
                nirp.pkg.examples.problem27Jacketed(), ...
                nirp.pkg.examples.problem30Liquid(), ...
                nirp.pkg.examples.problem44Liquid(), ...
                nirp.pkg.examples.problem45Liquid()} ;
            for i = 1:numel(packages)
                testCase.verifyWarningFree(@() nirp.pkg.validate(packages{i})) ;
            end
        end
    end

    methods (Access=private)
        function verifyProblem21(testCase,files)
            pkg = nirp.pkg.examples.problem21Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            baseFeed = nirp.pkg.feedStream(pkg,"F1") ;
            names = ["ex13_problem21a_isothermal_pfr", ...
                "ex14_problem21b_adiabatic_pfr"] ;
            modes = {'Isothermal','Adiabatic'} ;
            references = [387.3711 433.3584] ;
            officials = [387 433] ;
            for i = 1:2
                results = simulateExample(files(i),names(i)) ;
                temperature = results.Streams.F1.streamSI.T ;
                feed = atTemperature(baseFeed,temperature) ;
                expected = nirp.units.pfr(struct('V',1,'D',0.1, ...
                    'heatMode',modes{i}),feed,rs) ;
                testCase.verifyStream(results.Streams.Product.streamSI,expected) ;
                testCase.verifyEqual(temperature,references(i),'RelTol',1e-5) ;
                testCase.verifyEqual(results.Streams.Product.conversion,0.9, ...
                    'AbsTol',1e-6) ;
                testCase.verifyEqual(round(temperature),officials(i)) ;
            end
        end

        function verifyProblem27(testCase,file)
            pkg = nirp.pkg.examples.problem27Jacketed() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            results = simulateExample(file,"ex15_problem27_jacketed_cstr") ;
            temperature = results.Streams.F1.streamSI.T ;
            feed = atTemperature(nirp.pkg.feedStream(pkg,"F1"),temperature) ;
            expected = nirp.units.cstr(struct('V',0.2,'heatMode','Other', ...
                'U',300,'A',9,'utilityTin',273),feed,rs) ;
            testCase.verifyStream(results.Streams.Product.streamSI,expected) ;
            % Current-core fzero reference for the exact statement data.
            testCase.verifyEqual(temperature,298.623184,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.8, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(temperature,1),298.6) ;
        end

        function verifyProblems30And31(testCase,files)
            pkg = nirp.pkg.examples.problem30Liquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feedPO = nirp.pkg.feedStream(pkg,"Feed PO") ;
            feedW = nirp.pkg.feedStream(pkg,"Feed W") ;
            mixed = nirp.units.mixer([],{feedPO,feedW},rs) ;
            params = {struct('V',1.136,'heatMode','Adiabatic'), ...
                struct('V',1.136,'heatMode','Other','U',567.7, ...
                'A',3.7,'utilityTin',302.65)} ;
            names = ["ex16_problem30_adiabatic_cstr", ...
                "ex17_problem31_cooled_cstr"] ;
            temperatures = [340.6551 311.5865] ;
            conversions = [0.852987 0.326500] ;
            for i = 1:2
                expected = nirp.units.cstr(params{i},mixed,rs) ;
                results = simulateExample(files(i),names(i)) ;
                actual = results.Streams.Product.streamSI ;
                testCase.verifyStream(actual,expected) ;
                testCase.verifyEqual(actual.T,temperatures(i),'AbsTol',1e-3) ;
                testCase.verifyEqual(results.Streams.Product.conversion, ...
                    conversions(i),'AbsTol',1e-6) ;
            end
        end

        function verifyProblem44a(testCase,file)
            pkg = nirp.pkg.examples.problem44Liquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            results = simulateExample(file,"ex18_problem44a_volumes") ;
            pfrVolume = diagnosticVolume(results, ...
                "ex18_problem44a_volumes","PFR") ;
            cstrVolume = diagnosticVolume(results, ...
                "ex18_problem44a_volumes","CSTR") ;
            expectedPfr = nirp.units.pfr(struct('V',pfrVolume,'D',0.1, ...
                'heatMode','Adiabatic'),feed,rs) ;
            expectedCstr = nirp.units.cstr(struct('V',cstrVolume, ...
                'heatMode','Adiabatic'),feed,rs) ;
            testCase.verifyStream(results.Streams.ProductPFR.streamSI,expectedPfr) ;
            testCase.verifyStream(results.Streams.ProductCSTR.streamSI,expectedCstr) ;
            testCase.verifyEqual(pfrVolume,30.509470e-3,'RelTol',1e-5) ;
            testCase.verifyEqual(cstrVolume,17.592665e-3,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.ProductPFR.conversion,0.85, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(results.Streams.ProductCSTR.conversion,0.85, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(pfrVolume*1000,1),30.5) ;
            testCase.verifyEqual(round(cstrVolume*1000,1),17.6) ;
        end

        function verifyProblem45(testCase,files)
            pkg = nirp.pkg.examples.problem45Liquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            resultsA = simulateExample(files(1), ...
                "ex19_problem45a_three_cstrs") ;
            volume = diagnosticVolume(resultsA, ...
                "ex19_problem45a_three_cstrs","CSTR 1") ;
            params = struct('V',volume,'heatMode','Specified T', ...
                'specifiedT',368.15) ;
            first = nirp.units.cstr(params,feed,rs) ;
            second = nirp.units.cstr(params,first,rs) ;
            expected = nirp.units.cstr(params,second,rs) ;
            testCase.verifyStream(resultsA.Streams.Product.streamSI,expected) ;
            testCase.verifyEqual(volume,250.480335e-3,'RelTol',1e-5) ;
            testCase.verifyEqual(resultsA.Streams.Product.conversion,0.9, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(volume*1000,1),250.5) ;

            resultsB = simulateExample(files(2), ...
                "ex20_problem45b_feed_temperature") ;
            temperature = resultsB.Streams.F1.streamSI.T ;
            adjustedFeed = atTemperature(feed,temperature) ;
            expected = nirp.units.cstr(struct('V',0.250480335, ...
                'heatMode','Adiabatic'),adjustedFeed,rs) ;
            testCase.verifyStream(resultsB.Streams.Product.streamSI,expected) ;
            testCase.verifyEqual(temperature,346.8439,'RelTol',1e-5) ;
            testCase.verifyEqual(resultsB.Streams.Product.streamSI.T,368.15, ...
                'AbsTol',1e-4) ;
            testCase.verifyEqual(round(temperature,1),346.8) ;
        end

        function verifyStream(testCase,actual,expected)
            testCase.verifyEqual(actual.F,expected.F, ...
                'RelTol',1e-9,'AbsTol',1e-14) ;
            testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-9) ;
            testCase.verifyEqual(actual.P,expected.P,'RelTol',1e-9) ;
        end
    end
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ;
    load_system(char(file)) ; simulation = sim(char(name)) ;
    results = evalin('base','nirpResults') ;
    if any(strcmp(simulation.who,'nirpAdjustedPfrVolume'))
        values = simulation.get('nirpAdjustedPfrVolume') ;
        results.AdjustedPfrVolume = values(end) ;
    end
    close_system(char(name),0) ;
    Simulink.data.dictionary.closeAll('-discard') ;
end

function stream = atTemperature(stream,temperature)
    stream.T = temperature ;
    stream = nirp.stream.refresh(stream) ;
end

function value = diagnosticVolume(results,model,block)
    if block == "PFR" && isfield(results,'AdjustedPfrVolume')
        value = results.AdjustedPfrVolume ;
        return
    end
    field = matlab.lang.makeValidName(model+"_"+block) ;
    value = results.Diagnostics.(field).lastInfo.V ;
end

function closeModels()
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
