classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpBlocksTest < matlab.unittest.TestCase
    % NirpBlocksTest verifies the milestone-1 Simulink block library.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties
        Folder
        ExamplesFolder
        Files
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;
            examples=testCase.getSharedTestFixtures('nirptest.ExamplesFixture');
            testCase.ExamplesFolder=examples.Folder;
            testCase.Files=examples.Files;
            addpath(testCase.Folder);
            testCase.addTeardown(@() rmpathIfPresent(testCase.Folder));
            testCase.addTeardown(@() closeAllModels());
            evalin('base','clear nirpResults');
        end
    end

    methods (Test)
        function examplesMatchScriptsAndReferences(testCase)
            files=testCase.Files;
            names=["ex1_cstr_isothermal","ex2_cstr_adiabatic_cooler", ...
                "ex3_pfr_adiabatic","ex4_problem40b_parallel"];
            for i=1:numel(names)
                evalin('base','clear nirpResults'); load_system(char(files(i))); sim(char(names(i)));
                results=evalin('base','nirpResults'); actual=results.Streams.Product.streamSI;
                [expected,feed]=NirpBlocksTest.scriptResult(i);
                testCase.verifyEqual(actual.F,expected.F,'RelTol',1e-9,'AbsTol',1e-14);
                testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-9);
                testCase.verifyEqual(actual.P,expected.P,'RelTol',1e-9);
                testCase.verifyEqual(results.Streams.Product.conversion,(feed.F(1)-actual.F(1))/feed.F(1),'AbsTol',1e-12);
                close_system(char(names(i)),0); Simulink.data.dictionary.closeAll('-discard');
            end
            load_system(char(files(1)));sim(char(names(1)));r=evalin('base','nirpResults');testCase.verifyEqual(r.Streams.Product.conversion,0.5,'AbsTol',1e-9);close_system(char(names(1)),0);
            evalin('base','clear nirpResults');load_system(char(files(2)));sim(char(names(2)));r=evalin('base','nirpResults');testCase.verifyEqual(r.Diagnostics.ex2_cstr_adiabatic_cooler_CSTR.lastOutput.T,550,'AbsTol',1e-6);close_system(char(names(2)),0);
            evalin('base','clear nirpResults');load_system(char(files(3)));sim(char(names(3)));r=evalin('base','nirpResults');testCase.verifyEqual(r.Streams.Product.streamSI.T,616.0602794,'AbsTol',1e-3);close_system(char(names(3)),0);
            evalin('base','clear nirpResults');load_system(char(files(4)));sim(char(names(4)));r=evalin('base','nirpResults');testCase.verifyEqual(r.Streams.Product.conversion,0.578473757692,'AbsTol',1e-6);
        end

        function displayUnitsAreConvertedToSI(testCase)
            name='unit_pairs'; NirpBlocksTest.createModel(testCase.Folder,name,NirpBlocksTest.referencePackage());
            NirpBlocksTest.addSystem(name,'F1','nirp.blocks.Stream',[20 150 100 200],'Role','Feed');
            NirpBlocksTest.addSystem(name,'CSTR L','nirp.blocks.CSTR',[160 50 280 110],'V','100','VUnit','L');
            NirpBlocksTest.addSystem(name,'CSTR SI','nirp.blocks.CSTR',[160 130 280 190],'V','0.1','VUnit','m^3');
            NirpBlocksTest.addSystem(name,'Heater C','nirp.blocks.Heater',[160 220 280 280],'Tout','26.85','ToutUnit',[char(176) 'C']);
            NirpBlocksTest.addSystem(name,'Heater K','nirp.blocks.Heater',[160 300 280 360],'Tout','300','ToutUnit','K');
            productNames={'CstrL','CstrSI','HeaterC','HeaterK'}; y=[65 145 235 315]; blocks={'CSTR L','CSTR SI','Heater C','Heater K'};
            for i=1:4
                NirpBlocksTest.addSystem(name,productNames{i},'nirp.blocks.Stream',[350 y(i) 450 y(i)+45],'Role','Product');
                add_line(name,'F1/1',[blocks{i} '/1'],'autorouting','on'); add_line(name,[blocks{i} '/1'],[productNames{i} '/1']);
            end
            save_system(name);sim(name);r=evalin('base','nirpResults');
            testCase.verifyEqual(r.Streams.CstrL.streamSI.F,r.Streams.CstrSI.streamSI.F,'RelTol',1e-12);
            testCase.verifyEqual(r.Streams.CstrL.streamSI.T,r.Streams.CstrSI.streamSI.T,'RelTol',1e-12);
            testCase.verifyEqual(r.Streams.HeaterC.streamSI.T,r.Streams.HeaterK.streamSI.T,'AbsTol',1e-12);
        end

        function cacheCalculatesOnlyOnce(testCase)
            name='cache_model'; NirpBlocksTest.createModel(testCase.Folder,name,NirpBlocksTest.referencePackage());
            set_param(name,'StopTime','2');
            NirpBlocksTest.addSystem(name,'F1','nirp.blocks.Stream',[20 80 100 130],'Role','Feed');
            NirpBlocksTest.addSystem(name,'CSTR','nirp.blocks.CSTR',[160 70 270 140],'V','100','VUnit','L');
            add_block('simulink/Sinks/Terminator',[name '/Sink'],'Position',[340 90 360 110]);
            add_line(name,'F1/1','CSTR/1');add_line(name,'CSTR/1','Sink/1');save_system(name);sim(name);
            r=evalin('base','nirpResults');testCase.verifyEqual(r.Diagnostics.cache_model_CSTR.calculationCount,1);
        end

        function errorsAreClear(testCase)
            name='bad_feed';NirpBlocksTest.createModel(testCase.Folder,name,NirpBlocksTest.referencePackage());
            NirpBlocksTest.addSystem(name,'missing','nirp.blocks.Stream',[20 20 100 70],'Role','Feed');
            add_block('simulink/Sinks/Terminator',[name '/Sink']);add_line(name,'missing/1','Sink/1');save_system(name);
            NirpBlocksTest.verifySimulationMessage(testCase,name,'Open this block');close_system(name,0);

            name='no_dictionary';new_system(name);set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','StopTime','0');
            NirpBlocksTest.addSystem(name,'Flowsheet','nirp.blocks.Flowsheet',[20 20 120 70]);
            NirpBlocksTest.verifySimulationMessage(testCase,name,'no data dictionary');close_system(name,0);

            name='bad_split';NirpBlocksTest.createModel(testCase.Folder,name,NirpBlocksTest.referencePackage());
            NirpBlocksTest.addSystem(name,'F1','nirp.blocks.Stream',[20 60 100 110],'Role','Feed');
            NirpBlocksTest.addSystem(name,'Splitter','nirp.blocks.Splitter',[160 50 270 120],'Fractions','[0.4 0.4]');
            add_line(name,'F1/1','Splitter/1');save_system(name);
            NirpBlocksTest.verifySimulationMessage(testCase,name,'must add up to 1');
        end

        function newCreatesRunnableEmptyFlowsheet(testCase)
            name='new_flowsheet';[modelFile,dictionaryFile]=nirp.flowsheet.new(name,NirpBlocksTest.referencePackage(),testCase.Folder);
            testCase.verifyTrue(isfile(modelFile));testCase.verifyTrue(isfile(dictionaryFile));
            testCase.verifyEqual(get_param(name,'DataDictionary'),[name '.sldd']);
            testCase.verifyEqual(get_param(name,'StopTime'),'0');sim(name);
        end
    end

    methods (Static,Access=private)
        function pkg=referencePackage()
            pkg=nirp.pkg.examples.firstOrderLiquid();
        end
        function [out,feed]=scriptResult(index)
            if index<4,pkg=NirpBlocksTest.referencePackage();else,pkg=nirp.pkg.examples.problem40Gas();end
            rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,"F1");
            switch index
                case 1,out=nirp.units.cstr(struct('V',0.1),feed,rs);
                case 2,mid=nirp.units.cstr(struct('V',0.1,'heatMode','Adiabatic'),feed,rs);out=nirp.units.heater(struct('mode','Outlet T','Tout',300),mid,rs);
                case 3,out=nirp.units.pfr(struct('V',0.1,'D',0.1,'heatMode','Adiabatic'),feed,rs);
                otherwise,b=nirp.units.splitter(struct('fractions',[0.5 0.5]),feed,rs);a=nirp.units.cstr(struct('V',0.4),b{1},rs);c=nirp.units.cstr(struct('V',0.4),b{2},rs);out=nirp.units.mixer([],{a,c},rs);
            end
        end
        function createModel(folder,name,pkg)
            dictionaryFile=fullfile(folder,[name '.sldd']);modelFile=fullfile(folder,[name '.slx']);
            nirp.pkg.writeDictionary(pkg,dictionaryFile);new_system(name);save_system(name,modelFile);
            set_param(name,'DataDictionary',[name '.sldd']);nirp.flowsheet.configure(name);
        end
        function addSystem(model,name,className,position,varargin)
            add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});
        end
        function verifySimulationMessage(testCase,name,text)
            try,sim(name);testCase.assertFail('Expected simulation to fail.');
            catch exception
                report=getReport(exception,'basic','hyperlinks','off');
                testCase.verifySubstring(report,text);
            end
        end
    end
end

function closeAllModels()
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');
end
function rmpathIfPresent(folder)
    if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end
