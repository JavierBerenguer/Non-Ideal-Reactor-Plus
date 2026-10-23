classdef NirpTracerBlocksTest < matlab.unittest.TestCase
    % NirpTracerBlocksTest verifies tracer blocks, separation, and dialogs.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 23, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function createFolder(testCase),fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink'));testCase.addTeardown(@()closeAllModels());evalin('base','clear nirpTracerResults');end
    end
    methods (Test)
        function generatedTwoCstrDiagramMatchesCore(testCase)
            name='tracer_two_cstr';[~,dictionary]=nirp.tracerflowsheet.new(name,testCase.Folder,'Dt',0.05,'TFinal',20,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{'Q','1','DataTime','0:0.05:20','DataConcentration','ones(1,401)'});
            addTracer(name,'Vessel 1','nirp.tracerblocks.Vessel',[230 150 370 210],{'Tau','2'});addTracer(name,'Vessel 2','nirp.tracerblocks.Vessel',[430 150 570 210],{'Tau','2'});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[630 150 760 210],{});
            add_line(name,'Source/1','Vessel 1/1');add_line(name,'Vessel 1/1','Vessel 2/1');add_line(name,'Vessel 2/1','Monitor/1');configure(name);sim(name);
            results=evalin('base','nirpTracerResults');actual=results.tracer_two_cstr_Monitor.stream;grid=nirp.tracer.grid(0.05,20);source=nirp.tracer.source(grid,1,ones(size(grid.t)),1);rtd=nirp.tracer.rtdModel(grid,'cstr',struct('tau',2),1);expected=nirp.tracer.vessel(grid,nirp.tracer.vessel(grid,source,rtd),rtd);
            testCase.verifyEqual(actual.C(:)',expected.C,'AbsTol',2e-13);testCase.verifyEqual(actual.E(:)',expected.E,'AbsTol',2e-13);testCase.verifyEqual(actual.Q,1,'AbsTol',1e-14);
            d=Simulink.data.dictionary.open(dictionary);cleanup=onCleanup(@()close(d));bus=getValue(getEntry(getSection(d,'Design Data'),'NirpTracer'));testCase.verifyEqual({bus.Elements.Name},{'Q','C','E','sourceId','valid','status'});
        end
        function mixedIdealAndTracerBlocksAreRejectedWithBothNames(testCase)
            name='mixed_network';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));addTracer(name,'Tracer Source','nirp.tracerblocks.Source',[40 150 170 210],{});addTracer(name,'Ideal Mixer','nirp.blocks.Mixer',[250 150 380 210],{'NumInputs','2'});add_line(name,'Tracer Source/1','Ideal Mixer/1');
            testCase.verifyError(@()nirp.tracerflowsheet.validateSeparation(name),'nirp:tracerflowsheet:MixedFlowsheets');
            try,nirp.tracerflowsheet.validateSeparation(name);catch e,testCase.verifySubstring(e.message,'Tracer Source');testCase.verifySubstring(e.message,'Ideal Mixer');end
        end
        function libraryIsSeparateAndVisuallyDistinct(testCase)
            file=build_tracer_library(testCase.Folder);testCase.verifyTrue(isfile(file));load_system(file);blocks=find_system('NirpTracerLibrary','SearchDepth',1,'BlockType','MATLABSystem');testCase.verifyNumElements(blocks,6);systems=string(get_param(blocks,'System'));testCase.verifyTrue(all(startsWith(systems,'nirp.tracerblocks.')));testCase.verifyTrue(all(strcmp(get_param(blocks,'BackgroundColor'),'cyan')));
        end
        function dialogsApplyAndReopenHeadlessly(testCase)
            name='tracer_dialogs';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{});addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{});addTracer(name,'Splitter','nirp.tracerblocks.Splitter',[430 150 570 210],{});addTracer(name,'Mixer','nirp.tracerblocks.Mixer',[430 260 570 320],{});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[630 150 760 210],{});
            f=nirp.tracerflowsheet.FlowsheetDialog([name '/Tracer Flowsheet'],'Visible','off');f.setValues(0.2,12,'s');testCase.verifyTrue(f.apply());delete(f);f=nirp.tracerflowsheet.FlowsheetDialog([name '/Tracer Flowsheet'],'Visible','off');testCase.verifyEqual(f.getValues().dt,0.2,'AbsTol',1e-14);delete(f);
            s=nirp.tracerflowsheet.SourceDialog([name '/Source'],'Visible','off');s.setFlow(60,'L/min');s.setData([0 1 12],[0 2 0]);testCase.verifyTrue(s.apply());delete(s);s=nirp.tracerflowsheet.SourceDialog([name '/Source'],'Visible','off');testCase.verifyEqual(s.getValues().Q,60,'AbsTol',1e-12);delete(s);
            v=nirp.tracerflowsheet.VesselDialog([name '/Vessel'],'Visible','off');v.setModel('Tanks','tau',3,'N',2);testCase.verifyTrue(v.apply());delete(v);v=nirp.tracerflowsheet.VesselDialog([name '/Vessel'],'Visible','off');testCase.verifyEqual(v.getValues().N,2);testCase.verifyEqual(v.getValues().Model,"Tanks");delete(v);
            d=nirp.tracerflowsheet.SplitterDialog([name '/Splitter'],'Visible','off');d.setFractions([0.25 0.5]);testCase.verifyTrue(d.apply());delete(d);d=nirp.tracerflowsheet.SplitterDialog([name '/Splitter'],'Visible','off');testCase.verifyEqual(d.getValues(),[0.25 0.5 0.25],'AbsTol',1e-14);delete(d);
            m=nirp.tracerflowsheet.MixerDialog([name '/Mixer'],'Visible','off');m.setNumInputs(3);testCase.verifyTrue(m.apply());delete(m);m=nirp.tracerflowsheet.MixerDialog([name '/Mixer'],'Visible','off');testCase.verifyEqual(m.getValues(),3);delete(m);
            monitor=nirp.tracerflowsheet.MonitorDialog([name '/Monitor'],'Visible','off');monitor.WarningField.Value=2;testCase.verifyTrue(monitor.apply());delete(monitor);monitor=nirp.tracerflowsheet.MonitorDialog([name '/Monitor'],'Visible','off');testCase.verifyEqual(monitor.getValues(),0.02,'AbsTol',1e-14);delete(monitor);
        end
        function vesselDialogLayoutAndControlsFollowOrigin(testCase)
            name='tracer_vessel_layout';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{});dialog=nirp.tracerflowsheet.VesselDialog([name '/Vessel'],'Visible','off');testCase.addTeardown(@()deleteValid(dialog));drawnow;
            testCase.verifyGreaterThan(dialog.DataTable.Position(4),100);buttons=findall(dialog.Figure,'Type','uibutton');testCase.verifyLessThanOrEqual(max(arrayfun(@(button)button.Position(4),buttons)),40);
            testCase.verifyEqual(string(dialog.DataTable.Enable),"off");testCase.verifyEqual(string(dialog.SessionField.Enable),"off");testCase.verifyEqual(string(dialog.TauField.Enable),"on");testCase.verifyEqual(string(dialog.VolumeField.Enable),"off");
            dialog.setModel('Dispersion','volume',2,'Pe',10,'boundary','closed');testCase.verifyEqual(string(dialog.VolumeField.Enable),"on");testCase.verifyEqual(string(dialog.PeField.Enable),"on");testCase.verifyEqual(string(dialog.BoundaryDropDown.Enable),"on");testCase.verifyEqual(string(dialog.NField.Enable),"off");
            dialog.setData([0 1 2],[0 1 0]);testCase.verifyEqual(string(dialog.DataTable.Enable),"on");testCase.verifyEqual(string(dialog.AddRowButton.Enable),"on");testCase.verifyEqual(string(dialog.ModelDropDown.Enable),"off");
            dialog.setSessionFile(fullfile(fileparts(fileparts(mfilename('fullpath'))),'saves','SE51.mat'));testCase.verifyEqual(string(dialog.SessionField.Enable),"on");testCase.verifyEqual(string(dialog.BrowseButton.Enable),"on");testCase.verifyEqual(string(dialog.DataTable.Enable),"off");
        end
        function vesselDataButtonsImportAndApply(testCase)
            name='tracer_vessel_data';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{});block=[name '/Vessel'];dialog=nirp.tracerflowsheet.VesselDialog(block,'Visible','off');testCase.addTeardown(@()deleteValid(dialog));dialog.setData([0 1 2],[0 1 0]);
            rows=size(dialog.DataTable.Data,1);dialog.addRow();testCase.verifyEqual(size(dialog.DataTable.Data,1),rows+1);dialog.removeRow();testCase.verifyEqual(size(dialog.DataTable.Data,1),rows);
            file=fullfile(testCase.Folder,'rtd.csv');writematrix([0 0;1 1;2 0],file);dialog.importFile(file);testCase.verifyEqual(cell2mat(dialog.DataTable.Data),[0 0;1 1;2 0],'AbsTol',1e-14);
            testCase.verifyTrue(dialog.apply());testCase.verifyEqual(get_param(block,'Origin'),'Data');testCase.verifyEqual(str2num(get_param(block,'DataTime')),[0 1 2],'AbsTol',1e-14); %#ok<ST2NM>
        end
        function vesselSessionFileApplies(testCase)
            name='tracer_vessel_session';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{});block=[name '/Vessel'];dialog=nirp.tracerflowsheet.VesselDialog(block,'Visible','off');testCase.addTeardown(@()deleteValid(dialog));session=fullfile(fileparts(fileparts(mfilename('fullpath'))),'saves','SE51.mat');
            dialog.setSessionFile(session);testCase.verifyEqual(dialog.SessionField.Value,session);testCase.verifyTrue(dialog.apply());testCase.verifyEqual(get_param(block,'Origin'),'Session');testCase.verifyEqual(get_param(block,'SessionFile'),session);
        end
        function splitterButtonsChangeOutletCountAndPorts(testCase)
            name='tracer_splitter_dialog';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Splitter','nirp.tracerblocks.Splitter',[240 150 390 230],{});block=[name '/Splitter'];dialog=nirp.tracerflowsheet.SplitterDialog(block,'Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            add=findall(dialog.Figure,'Type','uibutton','Text','Add outlet');remove=findall(dialog.Figure,'Type','uibutton','Text','Remove');testCase.verifyNumElements(add,1);testCase.verifyNumElements(remove,1);
            feval(add.ButtonPushedFcn,add,[]);testCase.verifyEqual(size(dialog.FractionTable.Data,1),3);testCase.verifyEqual(dialog.FractionTable.Data(:,1),{'1';'2';'3'});testCase.verifyTrue(dialog.apply());testCase.verifyEqual(str2num(get_param(block,'Fractions')),[0.5 0],'AbsTol',1e-14);ports=get_param(block,'PortHandles');testCase.verifyNumElements(ports.Outport,3); %#ok<ST2NM>
            feval(remove.ButtonPushedFcn,remove,[]);feval(remove.ButtonPushedFcn,remove,[]);testCase.verifyEqual(size(dialog.FractionTable.Data,1),2);
            dialog.setFractions([0.8 0.4]);testCase.verifyFalse(dialog.apply());testCase.verifyEqual(str2num(get_param(block,'Fractions')),[0.5 0],'AbsTol',1e-14); %#ok<ST2NM>
        end
        function tracerDialogLatexCommandsAreDelimited(testCase)
            name='tracer_dialog_labels';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{});addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{});addTracer(name,'Splitter','nirp.tracerblocks.Splitter',[430 150 570 210],{});addTracer(name,'Mixer','nirp.tracerblocks.Mixer',[430 260 570 320],{});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[630 150 760 210],{});
            dialogs={nirp.tracerflowsheet.FlowsheetDialog([name '/Tracer Flowsheet'],'Visible','off'),nirp.tracerflowsheet.SourceDialog([name '/Source'],'Visible','off'),nirp.tracerflowsheet.VesselDialog([name '/Vessel'],'Visible','off'),nirp.tracerflowsheet.SplitterDialog([name '/Splitter'],'Visible','off'),nirp.tracerflowsheet.MixerDialog([name '/Mixer'],'Visible','off'),nirp.tracerflowsheet.MonitorDialog([name '/Monitor'],'Visible','off')};testCase.addTeardown(@()deleteDialogs(dialogs));
            for dialogIndex=1:numel(dialogs),labels=findall(dialogs{dialogIndex}.Figure,'Type','uilabel');for labelIndex=1:numel(labels),text=string(labels(labelIndex).Text);testCase.verifyFalse(contains(text,'sourceId'),sprintf('Internal sourceId text in %s',class(dialogs{dialogIndex})));if strcmpi(labels(labelIndex).Interpreter,'latex')&&contains(text,'\'),testCase.verifyTrue(startsWith(text,'$')&&endsWith(text,'$'),sprintf('Undelimited LaTeX in %s: %s',class(dialogs{dialogIndex}),text));elseif ~strcmpi(labels(labelIndex).Interpreter,'latex'),testCase.verifyFalse(contains(text,'\'),sprintf('Backslash in plain label from %s: %s',class(dialogs{dialogIndex}),text));end,end,end
        end
    end
end
function addTracer(model,name,system,position,parameters),block=[model '/' name];add_block('simulink/User-Defined Functions/MATLAB System',block,'System',system,'Position',position);for k=1:2:numel(parameters),set_param(block,parameters{k},parameters{k+1});end;nirp.tracerflowsheet.setupBlock(block);end
function configure(name),set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','0.05','StartTime','0','StopTime','0');save_system(name);end
function closeAllModels(),models=find_system('Type','block_diagram');for k=1:numel(models),try,close_system(models{k},0);catch,end,end;end
function deleteValid(value),if ~isempty(value)&&isvalid(value),delete(value);end,end
function deleteDialogs(values),for k=1:numel(values),deleteValid(values{k});end,end
