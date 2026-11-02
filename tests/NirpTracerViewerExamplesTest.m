classdef NirpTracerViewerExamplesTest < matlab.unittest.TestCase
    % Headless tests for the tracer viewer, launcher, and examples.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function setup(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink'));
            testCase.addTeardown(@()cleanupUiAndModels());
        end
    end
    methods (Test)
        function viewerShowsCorrectedMomentsAndTransfersRtd(testCase)
            grid=nirp.tracer.grid(0.02,40);source=nirp.tracer.source(grid,1,50*[1 zeros(1,grid.length-1)],1);
            cstr=nirp.tracer.rtdModel(grid,'cstr',struct('tau',2),1);out=nirp.tracer.vessel(grid,nirp.tracer.vessel(grid,source,cstr),cstr);
            result=makeResult(grid,out,source.C);viewer=nirp.tracerflowsheet.showResults(result,'Visible','off', ...
                'AppFactory',@()NonIdealReactorApp('Visible','off','ProgressFcn',@(~,~)[]));
            testCase.verifyEqual(result.rtdMoments.tau,4,'RelTol',1e-3);testCase.verifyEqual(result.rtdMoments.sigma2,8,'RelTol',1e-2);
            lines=findall(viewer.Axes,'Type','ConstantLine');testCase.verifyNumElements(lines,1);
            testCase.verifyEqual(string(viewer.TauLine.LabelOrientation),"horizontal");
            testCase.verifyGreaterThanOrEqual(viewer.TauLine.FontSize,12);
            testCase.verifyNotEmpty(viewer.SourceLine);testCase.verifyEqual(viewer.SourceLine.YData,source.C);
            testCase.verifyEqual(viewer.SourceMarker.YData,max(source.C));
            testCase.verifyLessThan(viewer.Axes.XLim(1),0);
            testCase.verifyGreaterThan(viewer.SourceAxes.YLim(2),max(source.C));
            testCase.verifyEqual(viewer.ResultsPanel.Title,'Results');
            testCase.verifySubstring(viewer.Description.Text,'equivalent tanks-in-series');
            feval(viewer.UseButton.ButtonPushedFcn,viewer.UseButton,[]);
            appFigure=findall(groot,'Type','Figure','Name','Non-Ideal Reactor Analysis');app=getappdata(appFigure(1),'NirpNonIdealReactorApp');
            file=fullfile(testCase.Folder,'received.mat');app.saveSessionToFile(file,'received');loaded=load(file,'sessionData');rtd=loaded.sessionData.shared.rtd;
            received=RTD(rtd.t,rtd.Et);testCase.verifyEqual(rtd.source,'tracer_flowsheet');testCase.verifyEqual(trapz(received.t,received.Et),1,'AbsTol',1e-12);testCase.verifyEqual(received.tau,4,'RelTol',1e-3);testCase.verifyEqual(received.sigma2,8,'RelTol',1e-2);
        end
        function multipleSourcesDisableTransfer(testCase)
            grid=nirp.tracer.grid(.1,5);a=nirp.tracer.source(grid,1,ones(size(grid.t)),1);b=nirp.tracer.source(grid,1,ones(size(grid.t)),2);
            mixed=nirp.tracer.mixer(grid,{a,b});result=makeResult(grid,mixed,nan(size(grid.t)));viewer=nirp.tracerflowsheet.showResults(result,'Visible','off');
            testCase.verifyEqual(string(viewer.UseButton.Enable),"off");testCase.verifySubstring(viewer.Explanation.Text,'multiple tracer sources');
        end
        function peakDominatedResponseOffersPeakClipping(testCase)
            grid=nirp.tracer.grid(.02,40);source=nirp.tracer.source(grid,1,50*[1 zeros(1,grid.length-1)],1);
            pfr=nirp.tracer.rtdModel(grid,'pfr',struct('tau',3),1);cstr=nirp.tracer.rtdModel(grid,'cstr',struct('tau',3),1);
            stream=nirp.tracer.vessel(grid,source,.25*pfr+.75*cstr);result=makeResult(grid,stream,source.C);viewer=nirp.tracerflowsheet.showResults(result,'Visible','off');
            testCase.verifyTrue(viewer.PeakCheckBox.Value);testCase.verifyEqual(string(viewer.Axes.YScale),"linear");
            testCase.verifyLessThan(viewer.Axes.YLim(2),max(stream.C));
            testCase.verifySubstring(viewer.Explanation.Text,'area');
            viewer.PeakCheckBox.Value=false;feval(viewer.PeakCheckBox.ValueChangedFcn,viewer.PeakCheckBox,[]);
            testCase.verifyGreaterThanOrEqual(viewer.Axes.YLim(2),max(stream.C));
        end
        function launcherHasIndependentTracerGroupAndCallbacks(testCase)
            calls=strings(0,1);launcher=NonIdealReactorPlus('Visible','off');
            launcher.TestActionOverrides.TracerOpenLibrary=@()record('library');launcher.TestActionOverrides.TracerOpenExample=@()record('example');launcher.TestActionOverrides.TracerNewFlowsheet=@()record('new');
            panels=findall(launcher.UIFigure,'Type','uipanel');testCase.verifyTrue(any(string({panels.Title})=="Non-ideal flowsheet (tracer)"));
            tags=["NirpTracerOpenLibrary" "NirpTracerOpenExample" "NirpTracerNewFlowsheet"];
            for tag=tags,b=findall(launcher.UIFigure,'Type','uibutton','Tag',tag);feval(b.ButtonPushedFcn,b,[]);end
            testCase.verifyEqual(calls,["library";"example";"new"]);
            function record(value),calls(end+1,1)=value;end
        end
        function examplesGenerateSimulateValidateAndRestore(testCase)
            validation=run_tracer_validation(testCase.Folder);testCase.verifySize(validation,[3 5]);testCase.verifyLessThanOrEqual(validation.maxAbsError,5e-3);
            names=nirp.tracerflowsheet.exampleNames();file=nirp.tracerflowsheet.openExample(names(1),'Folder',testCase.Folder,'NoWindow',true,'PromptFcn',@(~)'Restore');
            testCase.verifyTrue(isfile(file));testCase.verifyTrue(isfile(fullfile(testCase.Folder,[char(names(1)) '.sldd'])));
        end
    end
end
function result=makeResult(grid,stream,sourceSignal)
cm=nirp.tracerflowsheet.presentationMoments(grid,stream.C,grid.dt);if stream.status==1,rm=nirp.tracerflowsheet.presentationMoments(grid,stream.E,grid.dt);warning='';else,rm=[];warning='Global RTD is undefined because the network contains multiple sources.';end
result=struct('grid',grid,'stream',stream,'sourceSignal',sourceSignal,'concentrationMoments',cm,'rtdMoments',rm,'warning',warning);
end
function cleanupUiAndModels(),figures=findall(groot,'Type','Figure');for k=1:numel(figures),try,delete(figures(k));catch,end,end;bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpTracerResults');end
