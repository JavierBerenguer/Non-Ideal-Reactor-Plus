classdef NirpPropagationTest < matlab.unittest.TestCase
%NIRPPROPAGATIONTEST Forward flowsheet calculation before Simulink Run.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end
    methods (TestClassSetup)
        function buildModels(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            repo=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(repo,'simulink'));addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            build_examples(testCase.Folder,["ex1_cstr_isothermal" "ex3_pfr_adiabatic" ...
                "ex5_recycle_cstr" "ex6_adjust_volume" "ex10_problem42_cstr_pfr" ...
                "ex17_problem31_cooled_cstr"]);
            buildSplitter(testCase.Folder,'preview_splitter');
            testCase.addTeardown(@()cleanup(testCase));
        end
    end
    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all');Simulink.data.dictionary.closeAll('-discard');
            evalin('base','clear nirpResults');
        end
    end
    methods (Test)
        function splitterOutputsEqualRunWithoutRunningFirst(testCase)
            loadModel(testCase,'preview_splitter');
            preview=nirp.flowsheet.propagate('preview_splitter');
            testCase.verifyEqual(preview.Streams.Out1.status,'calculated');
            testCase.verifyEqual(preview.Streams.Out2.status,'calculated');
            sim('preview_splitter');results=evalin('base','nirpResults');
            verifyStream(testCase,preview.Streams.Out1.streamSI,results.Streams.Out1.streamSI,1e-12);
            verifyStream(testCase,preview.Streams.Out2.streamSI,results.Streams.Out2.streamSI,1e-12);
        end

        function idealExamplesEqualRun(testCase)
            names=["ex1_cstr_isothermal" "ex3_pfr_adiabatic" "ex10_problem42_cstr_pfr"];
            for name=names
                loadModel(testCase,name);preview=nirp.flowsheet.propagate(name);
                testCase.verifyEqual(preview.Streams.Product.status,'calculated',char(name));
                expected=preview.Streams.Product.streamSI;sim(char(name));
                results=evalin('base','nirpResults');verifyStream(testCase,expected,results.Streams.Product.streamSI,1e-10);
                close_system(char(name),0);Simulink.data.dictionary.closeAll('-discard');
            end
        end

        function recycleAndAdjustStopForwardCalculation(testCase)
            loadModel(testCase,'ex5_recycle_cstr');preview=nirp.flowsheet.propagate('ex5_recycle_cstr');
            testCase.verifyEqual(preview.Blocks.Recycle.status,'waiting');
            testCase.verifySubstring(preview.Streams.RecycleOutlet.reason,'Recycle');
            testCase.verifyEqual(preview.Streams.Product.status,'waiting');
            close_system('ex5_recycle_cstr',0);Simulink.data.dictionary.closeAll('-discard');
            loadModel(testCase,'ex6_adjust_volume');preview=nirp.flowsheet.propagate('ex6_adjust_volume');
            testCase.verifyEqual(preview.Streams.F1.status,'calculated');
            testCase.verifyEqual(preview.Streams.Product.status,'waiting');
            testCase.verifySubstring(preview.Streams.Product.reason,'Adjust');
        end

        function outletFlowSpecificationClosesUpstreamSplitter(testCase)
            loadModel(testCase,'preview_splitter');feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");
            set_param('preview_splitter/Splitter','Fractions','[NaN NaN]','Specifications','{}');
            nirp.dof.writeSpecs('preview_splitter/Out 1',struct('F',spec(0.3*sum(feed.F),'mol/s')));
            preview=nirp.flowsheet.propagate('preview_splitter');
            testCase.verifyEqual(sum(preview.Streams.Out1.streamSI.F),0.3*sum(feed.F),'AbsTol',1e-12);
            testCase.verifyEqual(sum(preview.Streams.Out2.streamSI.F),0.7*sum(feed.F),'AbsTol',1e-12);
            testCase.verifyEqual(preview.Streams.Product2.status,'calculated');
        end

        function completeJacketEnablesReactor(testCase)
            loadModel(testCase,'ex17_problem31_cooled_cstr');preview=nirp.flowsheet.propagate('ex17_problem31_cooled_cstr');
            testCase.verifyEqual(preview.Streams.Product.status,'calculated');expected=preview.Streams.Product.streamSI;
            sim('ex17_problem31_cooled_cstr');results=evalin('base','nirpResults');
            verifyStream(testCase,expected,results.Streams.Product.streamSI,1e-10);
        end

        function cacheSkipsUnchangedReactorAndInvalidatesUpstream(testCase)
            loadModel(testCase,'ex1_cstr_isothermal');first=nirp.flowsheet.propagate('ex1_cstr_isothermal');
            second=nirp.flowsheet.propagate('ex1_cstr_isothermal');
            testCase.verifyEqual(first.Blocks.CSTR.calculationCount,second.Blocks.CSTR.calculationCount);
            original=second.Streams.Product.streamSI;
            set_param('ex1_cstr_isothermal/CSTR','V','120');third=nirp.flowsheet.propagate('ex1_cstr_isothermal');
            testCase.verifyEqual(third.Blocks.CSTR.calculationCount,second.Blocks.CSTR.calculationCount+1);
            testCase.verifyGreaterThan(max(abs(third.Streams.Product.streamSI.F-original.F)),1e-12);
        end

        function applyCallbackRefreshesDownstreamStreams(testCase)
            loadModel(testCase,'preview_splitter');initial=nirp.flowsheet.propagate('preview_splitter');
            dialog=nirp.flowsheet.StreamDialog('preview_splitter/F1','Visible','off');
            testCase.addTeardown(@()deleteValid(dialog));
            field=dialog.TemperatureField;oldValue=field.Value;field.Value=oldValue+10;
            event=struct('PreviousValue',oldValue,'Value',field.Value);
            feval(field.ValueChangedFcn,field,event);
            feval(dialog.ApplyButton.ButtonPushedFcn,dialog.ApplyButton,[]);
            updated=nirp.flowsheet.preview('get','preview_splitter');
            testCase.verifyEqual(updated.Streams.Out1.status,'calculated');
            testCase.verifyEqual(updated.Streams.Out1.streamSI.T,initial.Streams.Out1.streamSI.T+10,'AbsTol',1e-12);
        end

        function incompleteBlockPublishesWaitingReason(testCase)
            loadModel(testCase,'preview_splitter');set_param('preview_splitter/Heater','Specifications','{}');
            preview=nirp.flowsheet.propagate('preview_splitter');
            testCase.verifyEqual(preview.Streams.Product2.status,'waiting');
            testCase.verifySubstring(preview.Streams.Product2.reason,'waiting for');
            dialog=nirp.flowsheet.StreamDialog('preview_splitter/Product 2','Visible','off');
            testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifySubstring(dialog.StatusLabel.Text,'Waiting for:');
        end

        function runClearsPreviewAndKeepsSameResult(testCase)
            loadModel(testCase,'ex1_cstr_isothermal');preview=nirp.flowsheet.propagate('ex1_cstr_isothermal');
            expected=preview.Streams.Product.streamSI;sim('ex1_cstr_isothermal');
            cleared=nirp.flowsheet.preview('get','ex1_cstr_isothermal');testCase.verifyEmpty(fieldnames(cleared.Streams));
            results=evalin('base','nirpResults');verifyStream(testCase,expected,results.Streams.Product.streamSI,1e-12);
        end
    end
end

function buildSplitter(folder,name)
    pkg=nirp.pkg.examples.firstOrderLiquid();nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd']));
    new_system(name);save_system(name,fullfile(folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);
    addSystem(name,'F1','nirp.blocks.Stream',[20 100 100 150],'Role','Feed');
    addSystem(name,'Splitter','nirp.blocks.Splitter',[160 80 270 170],'Fractions','[0.4 0.6]');
    addSystem(name,'Out 1','nirp.blocks.Stream',[330 35 420 85],'Role','Product');
    addSystem(name,'Out 2','nirp.blocks.Stream',[330 150 420 200],'Role','Intermediate');
    addSystem(name,'Heater','nirp.blocks.Heater',[470 140 580 210],'Mode','Outlet T','Tout','320','PressureDrop','0');
    addSystem(name,'Product 2','nirp.blocks.Stream',[640 150 740 200],'Role','Product');
    add_line(name,'F1/1','Splitter/1');add_line(name,'Splitter/1','Out 1/1');add_line(name,'Splitter/2','Out 2/1');
    add_line(name,'Out 2/1','Heater/1');add_line(name,'Heater/1','Product 2/1');nirp.flowsheet.configure(name);save_system(name);close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
end
function loadModel(testCase,name),load_system(fullfile(testCase.Folder,[char(name) '.slx']));end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});end
function value=spec(si,unit),value=struct('si',si,'unit',unit);end
function verifyStream(testCase,actual,expected,tolerance)
    testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance,'AbsTol',1e-12);
    testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance,'AbsTol',1e-10);
    testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance,'AbsTol',1e-8);
    testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance,'AbsTol',1e-12);
end
function deleteValid(value)
    try
        if isvalid(value),delete(value);end
    catch
    end
end
function cleanup(testCase)
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');
    nirp.flowsheet.preview('clear','ex1_cstr_isothermal');
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);
    if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end
end
