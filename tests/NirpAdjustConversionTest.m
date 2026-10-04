classdef NirpAdjustConversionTest < matlab.unittest.TestCase
    % NirpAdjustConversionTest verifies the live Adjust conversion reference.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 4, 2026. Last update: October 4, 2026
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
        function measurementUsesPublishedFeedThenPackageFallback(testCase)
            name = 'adjust_conversion_reference' ;
            pkg = nirp.pkg.examples.firstOrderLiquid() ;
            pkg.feeds(2) = pkg.feeds(1) ;
            pkg.feeds(2).name = "Reference Feed" ;
            NirpAdjustConversionTest.createModel(testCase.Folder,name,pkg) ;

            published = nirp.pkg.feedStream(pkg,"Reference Feed") ;
            published.F = 2*published.F ; published.Q = 2*published.Q ;
            published = nirp.stream.refresh(published) ;
            results = struct('Streams',struct()) ;
            results.Streams.ReferenceFeed = struct('streamSI',published) ;
            assignin('base','nirpResults',results) ;
            sim(name) ;
            results = evalin('base','nirpResults') ;
            testCase.verifyEqual(results.Diagnostics.adjust_conversion_reference_Adjust. ...
                lastInfo.measured,0.5, ...
                'AbsTol',1e-12) ;

            evalin('base','clear nirpResults') ;
            sim(name) ;
            results = evalin('base','nirpResults') ;
            testCase.verifyEqual(results.Diagnostics.adjust_conversion_reference_Adjust. ...
                lastInfo.measured,0, ...
                'AbsTol',1e-12) ;
        end

        function fixedFeedExamplesKeepTheirConversionMeasurement(testCase)
            files = build_examples(testCase.Folder) ;
            load_system(char(files(6))) ; sim('ex6_adjust_volume') ;
            results = evalin('base','nirpResults') ;
            testCase.verifyEqual(results.Diagnostics.ex6_adjust_volume_Adjust. ...
                lastInfo.measured, ...
                results.Streams.Product.conversion,'AbsTol',1e-12) ;
            close_system('ex6_adjust_volume',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            evalin('base','clear nirpResults') ;
            load_system(char(files(18))) ; sim('ex18_problem44a_volumes') ;
            results = evalin('base','nirpResults') ;
            testCase.verifyEqual(results.Diagnostics.ex18_problem44a_volumes_AdjustPFR. ...
                lastInfo.measured, ...
                results.Streams.ProductPFR.conversion,'AbsTol',1e-12) ;
            testCase.verifyEqual(results.Diagnostics.ex18_problem44a_volumes_AdjustCSTR. ...
                lastInfo.measured, ...
                results.Streams.ProductCSTR.conversion,'AbsTol',1e-12) ;
        end
    end

    methods (Static,Access=private)
        function createModel(folder,name,pkg)
            nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd'])) ;
            new_system(name) ; save_system(name,fullfile(folder,[name '.slx'])) ;
            set_param(name,'DataDictionary',[name '.sldd'], ...
                'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
                'FixedStep','1','StopTime','2') ;
            add_block('simulink/User-Defined Functions/MATLAB System', ...
                [name '/F1'],'System','nirp.blocks.Stream','Role','Feed', ...
                'Position',[30 80 130 130]) ;
            add_block('simulink/User-Defined Functions/MATLAB System', ...
                [name '/Adjust'],'System','nirp.blocks.Adjust', ...
                'ReferenceFeed','Reference Feed','KeyComponent','A', ...
                'TargetValue','0.5','Position',[190 70 330 140]) ;
            add_block('simulink/Sinks/Terminator',[name '/Parameter'], ...
                'Position',[380 95 400 115]) ;
            add_line(name,'F1/1','Adjust/1') ;
            add_line(name,'Adjust/1','Parameter/1') ;
            save_system(name) ;
        end
    end
end

function closeModels()
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
