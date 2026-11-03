classdef NirpNonIdealReactorDialogTest < matlab.unittest.TestCase
%NIRPNONIDEALREACTORDIALOGTEST Headless structured-editor user journeys.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================
    properties,Folder,end
    methods (TestMethodSetup)
        function createWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.addTeardown(@()cleanup(testCase.Folder));evalin('base','clear nirpResults');
        end
    end
    methods (Test)
        function emptyBlockControlsApplySimulateAndShowResults(testCase)
            createModel(testCase,'dialog_nonideal');dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_nonideal/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            choose(dialog.OriginDropDown,'Model');choose(dialog.ModelDropDown,'CSTR');editNumber(dialog.TauField,2);
            testCase.verifyEqual(dialog.VField.BackgroundColor,[0.92 0.92 0.92],'AbsTol',1e-12);
            choose(dialog.MicromixingDropDown,'Maximum mixedness');testCase.verifySubstring(string(dialog.StatusLabel.Text),"Fully specified");ok=findall(dialog.Figure,'Type','uibutton','Text','OK');feval(ok.ButtonPushedFcn,ok,[]);testCase.verifyFalse(isvalid(dialog));
            specs=nirp.dof.readSpecs(get_param('dialog_nonideal/Reactor','Specifications'));
            testCase.verifyTrue(isfield(specs,'tau'));testCase.verifyEqual(specs.tau.si,2,'RelTol',1e-12);
            sim('dialog_nonideal');results=evalin('base','nirpResults');info=results.Diagnostics.dialog_nonideal_Reactor.lastInfo;
            testCase.verifyEqual(info.micromixing,'maxmixedness');testCase.verifyEqual(info.tau,2,'RelTol',1e-10);
            dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_nonideal/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyNotEmpty(dialog.ResultsTable.Data);testCase.verifyTrue(any(strcmp(dialog.ResultsTable.Data(:,1),'Mean RTD time (s)')));
            choose(dialog.MicromixingDropDown,'Segregation');testCase.verifyTrue(dialog.apply());sim('dialog_nonideal');
            second=evalin('base','nirpResults.Diagnostics.dialog_nonideal_Reactor.lastInfo');testCase.verifyEqual(second.micromixing,'segregation');
        end
        function dataImportConflictAndCancelAreVisible(testCase)
            createModel(testCase,'dialog_data');path=fullfile(testCase.Folder,'rtd.csv');writematrix([0 0;1 0.5;2 0.5;3 0],path);
            before=get_param('dialog_data/Reactor','RTDOrigin');dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_data/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.importData(path);testCase.verifyEqual(dialog.DataTable.Data,[0 0;1 0.5;2 0.5;3 0]);
            choose(dialog.MicromixingDropDown,'Segregation');editNumber(dialog.TauField,99);
            testCase.verifySubstring(string(dialog.StatusLabel.Text),"Conflict");testCase.verifyFalse(dialog.apply());
            dialog.cancel();testCase.verifyEqual(get_param('dialog_data/Reactor','RTDOrigin'),before);
            dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_data/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.importData(path);choose(dialog.MicromixingDropDown,'Segregation');testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(get_param('dialog_data/Reactor','RTDOrigin'),'Data');testCase.verifyEqual(str2num(get_param('dialog_data/Reactor','DataTime')),[0 1 2 3]); %#ok<ST2NM>
            help=findall(dialog.Figure,'Type','uibutton','Text','Help');testCase.verifyNumElements(help,1);testCase.verifyNotEmpty(help.ButtonPushedFcn);
        end
        function modelSpecificControlsAndMicromixingText(testCase)
            createModel(testCase,'dialog_controls');dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_controls/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            choose(dialog.OriginDropDown,'Model');choose(dialog.ModelDropDown,'Tanks in series');testCase.verifyEqual(dialog.NField.Visible,matlab.lang.OnOffSwitchState.on);testCase.verifyEqual(dialog.PeField.Visible,matlab.lang.OnOffSwitchState.off);
            choose(dialog.ModelDropDown,'Dispersion');testCase.verifyEqual(dialog.NField.Visible,matlab.lang.OnOffSwitchState.off);testCase.verifyEqual(dialog.PeField.Visible,matlab.lang.OnOffSwitchState.on);testCase.verifyEqual(dialog.BoundaryDropDown.Visible,matlab.lang.OnOffSwitchState.on);
            editNumber(dialog.TauField,2);editNumber(dialog.PeField,10);choose(dialog.ModelDropDown,'Dispersion');
            choose(dialog.MicromixingDropDown,'Segregation');testCase.verifySubstring(string(dialog.MicromixingDescription.Text),"mixing only at the outlet");
            choose(dialog.MicromixingDropDown,'Maximum mixedness');testCase.verifySubstring(string(dialog.MicromixingDescription.Text),"Earliest possible mixing");
            lines=findobj(dialog.RTDAxes,'Type','Line');testCase.verifyGreaterThan(numel(lines),0);
        end
        function setupInstallsStructuredCallback(testCase)
            createModel(testCase,'dialog_callback');nirp.flowsheet.setupUnitBlock('dialog_callback/Reactor');
            testCase.verifySubstring(get_param('dialog_callback/Reactor','OpenFcn'),'NonIdealReactorDialog.open');
        end
        function measuredRtdDistinguishesPendingInletFromComplete(testCase)
            createModel(testCase,'dialog_pending');delete_line('dialog_pending','F1/1','Reactor/1');
            dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_pending/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.DataTable.Data=[0 0;1 1;2 0];choose(dialog.OriginDropDown,'Data');choose(dialog.MicromixingDropDown,'Segregation');
            testCase.verifySubstring(string(dialog.StatusLabel.Text),"waiting for the inlet stream");
            delete(dialog);add_line('dialog_pending','F1/1','Reactor/1');
            dialog=nirp.flowsheet.NonIdealReactorDialog('dialog_pending/Reactor','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.DataTable.Data=[0 0;1 1;2 0];choose(dialog.OriginDropDown,'Data');choose(dialog.MicromixingDropDown,'Segregation');
            testCase.verifySubstring(string(dialog.StatusLabel.Text),"Fully specified");
        end
    end
end

function createModel(testCase,name)
nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
if getSimulinkBlockHandle([name '/F1'])<=0,addUnit(name,'F1','nirp.blocks.Stream',[20 90 110 140],'Role','Feed');end
addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[180 75 340 155]);addUnit(name,'Product','nirp.blocks.Stream',[420 90 530 140],'Role','Product','ReferenceFeed','F1','KeyComponent','A');
add_line(name,'F1/1','Reactor/1');add_line(name,'Reactor/1','Product/1');nirp.flowsheet.configure(name);save_system(name);
end
function addUnit(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});end
function choose(control,value),control.Value=value;feval(control.ValueChangedFcn,control,[]);end
function editNumber(control,value),control.Value=value;feval(control.ValueChangedFcn,control,struct('Value',value));end
function deleteValid(value),if ~isempty(value)&&isvalid(value),delete(value);end,end
function cleanup(folder),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');f=findall(groot,'Type','Figure');if ~isempty(f),delete(f);end;if contains(path,folder),rmpath(folder);end,end
