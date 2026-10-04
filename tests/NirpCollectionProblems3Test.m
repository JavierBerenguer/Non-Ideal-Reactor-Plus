classdef NirpCollectionProblems3Test < matlab.unittest.TestCase
    % NirpCollectionProblems3Test verifies the third collection batch.
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
            testCase.verifySinglePfr(files(21), ...
                "ex21_problem17_adiabatic_pfr_volume", ...
                nirp.pkg.examples.problem17AdiabaticGas(),"A", ...
                20.324520e-3,0.35,'Adiabatic') ;
            testCase.verifySinglePfr(files(22), ...
                "ex22_problem18_acetone_cracking", ...
                nirp.pkg.examples.problem18AcetoneCracking(),"Acetone", ...
                1.028539,0.2,'Adiabatic') ;
            testCase.verifySinglePfr(files(23), ...
                "ex23_problem23_butane_isomerization", ...
                nirp.pkg.examples.problem23ButaneIsomerization(),"n-C4", ...
                1.233841,0.65,'Adiabatic') ;
            testCase.verifyProblem26(files(24)) ;
            testCase.verifyProblem38(files(25)) ;
            testCase.verifySinglePfr(files(26), ...
                "ex26_problem40c_pfr_volume", ...
                nirp.pkg.examples.problem40cGas(),"A", ...
                56.006321e-3,0.6,'Isothermal') ;
            testCase.verifyProblem49(files(27:28)) ;
            testCase.verifyProblem34d(files(29)) ;
        end

        function examplesAreRegistered(testCase)
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            expected = ["ex21_problem17_adiabatic_pfr_volume"; ...
                "ex22_problem18_acetone_cracking"; ...
                "ex23_problem23_butane_isomerization"; ...
                "ex24_problem26_scale_up_cstr"; ...
                "ex25_problem38_parallel_pfrs"; ...
                "ex26_problem40c_pfr_volume"; ...
                "ex27_problem49a_two_adiabatic_cstrs"; ...
                "ex28_problem49b_one_adiabatic_cstr"; ...
                "ex29_problem34d_jacketed_cstr"] ;
            testCase.verifyEqual(names(21:29),expected) ;
            testCase.verifyTrue(all(strlength(descriptions(21:29)) > 20)) ;
        end

        function packagesAndFlowUnitsAreValid(testCase)
            packages = {nirp.pkg.examples.problem17AdiabaticGas(), ...
                nirp.pkg.examples.problem18AcetoneCracking(), ...
                nirp.pkg.examples.problem23ButaneIsomerization(), ...
                nirp.pkg.examples.problem26ScaleUpGas(), ...
                nirp.pkg.examples.problem38ParallelGas(), ...
                nirp.pkg.examples.problem40cGas(), ...
                nirp.pkg.examples.problem49AdiabaticLiquid(), ...
                nirp.pkg.examples.problem34dMonsanto()} ;
            for i = 1:numel(packages)
                testCase.verifyWarningFree(@() nirp.pkg.validate(packages{i})) ;
            end
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'VolumetricFlow',1,'L/h'),1e-3/3600,'RelTol',1e-15) ;
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'VolumetricFlow',1,'m^3/h'),1/3600,'RelTol',1e-15) ;
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'VolumetricFlow',1,'m^3/min'),1/60,'RelTol',1e-15) ;
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'MolarFlow',1,'kmol/min'),1e3/60,'RelTol',1e-15) ;
        end

        function problem30And31AreUnchangedWithLitresPerHour(testCase)
            pkg = nirp.pkg.examples.problem30Liquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feedPO = nirp.pkg.feedStream(pkg,"Feed PO") ;
            feedW = nirp.pkg.feedStream(pkg,"Feed W") ;
            oldPO = feedPO ; oldW = feedW ;
            oldPO.Q = UnitConverterHelper.convertToSI('VolumetricFlow', ...
                (1134/0.859+32.6*32.04/0.7914)/60,'L/min') ;
            oldW.Q = UnitConverterHelper.convertToSI('VolumetricFlow', ...
                (364.14*18.02/0.9941)/60,'L/min') ;
            mixed = nirp.units.mixer([],{feedPO,feedW},rs) ;
            oldMixed = nirp.units.mixer([],{oldPO,oldW},rs) ;
            out30 = nirp.units.cstr(struct('V',1.136, ...
                'heatMode','Adiabatic'),mixed,rs) ;
            old30 = nirp.units.cstr(struct('V',1.136, ...
                'heatMode','Adiabatic'),oldMixed,rs) ;
            out31 = nirp.units.cstr(struct('V',1.136,'heatMode','Other', ...
                'U',567.7,'A',3.7,'utilityTin',302.65),mixed,rs) ;
            old31 = nirp.units.cstr(struct('V',1.136,'heatMode','Other', ...
                'U',567.7,'A',3.7,'utilityTin',302.65),oldMixed,rs) ;
            testCase.verifyStream(out30,old30,1e-12) ;
            testCase.verifyStream(out31,old31,1e-12) ;
        end
    end

    methods (Access=private)
        function verifySinglePfr(testCase,file,name,pkg,key,reference,target,heatMode)
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            results = simulateExample(file,name) ;
            volume = diagnosticVolume(results,name,"PFR") ;
            expected = nirp.units.pfr(struct('V',volume,'D',0.1, ...
                'heatMode',heatMode),feed,rs) ;
            testCase.verifyStream(results.Streams.Product.streamSI,expected,1e-9) ;
            testCase.verifyEqual(volume,reference,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.Product.conversion,target, ...
                'AbsTol',1e-6) ;
            if reference < 0.1
                testCase.verifyEqual(round(volume*1000,1),round(reference*1000,1)) ;
            else
                testCase.verifyEqual(round(volume,2),round(reference,2)) ;
            end
            testCase.verifyNotEmpty(key) ;
        end

        function verifyProblem26(testCase,file)
            pkg = nirp.pkg.examples.problem26ScaleUpGas() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            name = "ex24_problem26_scale_up_cstr" ;
            results = simulateExample(file,name) ;
            volume = diagnosticVolume(results,name,"CSTR") ;
            expected = nirp.units.cstr(struct('V',volume, ...
                'heatMode','Isothermal'),feed,rs) ;
            testCase.verifyStream(results.Streams.Product.streamSI,expected,1e-9) ;
            testCase.verifyEqual(volume,816.6667,'RelTol',1e-5) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.75, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(volume,1),816.7) ;

            laboratoryFlow = (25/44.05)/3600 ;
            laboratoryFeed = nirp.stream.create([laboratoryFlow;0;0], ...
                793.15,101325,1,[]) ;
            laboratoryOut = nirp.units.cstr(struct('V',0.1, ...
                'heatMode','Isothermal'),laboratoryFeed,rs) ;
            conversion = (laboratoryFlow-laboratoryOut.F(1))/laboratoryFlow ;
            testCase.verifyEqual(conversion,0.8,'AbsTol',1e-10) ;
        end

        function verifyProblem38(testCase,file)
            pkg = nirp.pkg.examples.problem38ParallelGas() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            name = "ex25_problem38_parallel_pfrs" ;
            results = simulateExample(file,name) ;
            volume1 = diagnosticVolume(results,name,"PFR 1") ;
            volume2 = diagnosticVolume(results,name,"PFR 2") ;
            branches = nirp.units.splitter(struct('fractions',[0.5 0.5]),feed,rs) ;
            out1 = nirp.units.pfr(struct('V',volume1,'D',0.1),branches{1},rs) ;
            out2 = nirp.units.pfr(struct('V',volume2,'D',0.1),branches{2},rs) ;
            expected = nirp.units.mixer([],{out1,out2},rs) ;
            testCase.verifyStream(results.Streams.Product.streamSI,expected,1e-9) ;
            testCase.verifyEqual(volume1,32.065395e-3,'RelTol',1e-5) ;
            testCase.verifyEqual(volume2,volume1,'RelTol',1e-12) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.8, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(volume1*1000,1),32.1) ;
        end

        function verifyProblem49(testCase,files)
            pkg = nirp.pkg.examples.problem49AdiabaticLiquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            nameA = "ex27_problem49a_two_adiabatic_cstrs" ;
            resultsA = simulateExample(files(1),nameA) ;
            volume1 = diagnosticVolume(resultsA,nameA,"CSTR 1") ;
            volume2 = diagnosticVolume(resultsA,nameA,"CSTR 2") ;
            params = struct('V',volume1,'heatMode','Adiabatic') ;
            first = nirp.units.cstr(params,feed,rs) ;
            expectedA = nirp.units.cstr(params,first,rs) ;
            testCase.verifyStream(resultsA.Streams.Product.streamSI,expectedA,1e-9) ;
            testCase.verifyEqual(volume1,1.102400,'RelTol',1e-5) ;
            testCase.verifyEqual(volume2,volume1,'RelTol',1e-12) ;
            testCase.verifyEqual(resultsA.Streams.Product.conversion,0.8, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(volume1,2),1.10) ;

            nameB = "ex28_problem49b_one_adiabatic_cstr" ;
            resultsB = simulateExample(files(2),nameB) ;
            volume = diagnosticVolume(resultsB,nameB,"CSTR") ;
            expectedB = nirp.units.cstr(struct('V',volume, ...
                'heatMode','Adiabatic'),feed,rs) ;
            testCase.verifyStream(resultsB.Streams.Product.streamSI,expectedB,1e-9) ;
            testCase.verifyEqual(volume,4.763749,'RelTol',1e-5) ;
            testCase.verifyEqual(resultsB.Streams.Product.conversion,0.8, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(round(volume,2),4.76) ;
        end

        function verifyProblem34d(testCase,file)
            pkg = nirp.pkg.examples.problem34dMonsanto() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            legacyPkg = pkg ;
            legacyPkg.feeds.values = 60*pkg.feeds.values ;
            legacyPkg.feeds.valuesUnit = "kmol/h" ;
            legacyPkg.feeds.Q.value = 60*pkg.feeds.Q.value ;
            legacyPkg.feeds.Q.unit = "m^3/h" ;
            legacyFeed = nirp.pkg.feedStream(legacyPkg,"F1") ;
            testCase.verifyStream(feed,legacyFeed,1e-12) ;
            params = struct('V',1.5,'heatMode','Other', ...
                'U',35.85*4184/60,'A',1,'utilityTin',298.15, ...
                'initialTemperatureGuess',1050) ;
            expected = nirp.units.cstr(params,feed,rs) ;
            legacyExpected = nirp.units.cstr(params,legacyFeed,rs) ;
            testCase.verifyStream(expected,legacyExpected,1e-12) ;
            results = simulateExample(file,"ex29_problem34d_jacketed_cstr") ;
            actual = results.Streams.Product.streamSI ;
            testCase.verifyStream(actual,expected,1e-9) ;
            testCase.verifyEqual(results.Streams.Product.conversion,0.371469, ...
                'AbsTol',1e-6) ;
            testCase.verifyEqual(actual.T,1068.4332,'AbsTol',1e-3) ;
            testCase.verifyEqual(round(actual.T-273.15,1),795.3) ;

            cold = nirp.units.cstr(rmfield(params,'initialTemperatureGuess'),feed,rs) ;
            coldConversion = (feed.F(1)-cold.F(1))/feed.F(1) ;
            testCase.verifyLessThan(cold.T-273.15,16) ;
            testCase.verifyLessThan(coldConversion,1e-3) ;
        end

        function verifyStream(testCase,actual,expected,tolerance)
            testCase.verifyEqual(actual.F,expected.F, ...
                'RelTol',tolerance,'AbsTol',1e-14) ;
            testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance) ;
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

function value = diagnosticVolume(results,model,block)
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
