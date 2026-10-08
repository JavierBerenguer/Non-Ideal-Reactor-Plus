classdef NirpDiagramModesTest < matlab.unittest.TestCase
%NIRPDIAGRAMMODESTEST Flowsheet reactor modes, signal connections and dialogs (T-131).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 7, 2026. Last update: October 7, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end
    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            nirp.flowsheet.new('modes_model',nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);
            load_system(fullfile(testCase.Folder,'modes_model.slx'));testCase.addTeardown(@() cleanup(testCase));
        end
    end
    methods (Test)
        function reactorBlocksOfferOnlyDiagramModes(testCase)
            % The System-object set retains the obsolete value solely so a
            % saved model can load far enough to emit jacketRequired. The
            % structured reactor dialog below is the user-facing offer.
            expected={'Isothermal','Adiabatic','Heat exchange'};
            testCase.verifyEqual(reshape(getAllowedValues(nirp.blocks.CSTR.HeatModeSet),1,[]),expected);
            testCase.verifyEqual(reshape(getAllowedValues(nirp.blocks.PFR.HeatModeSet),1,[]),expected);
            for className=["nirp.blocks.CSTR","nirp.blocks.PFR"]
                properties=meta.class.fromName(className).PropertyList;
                for name=["BypassRatio","SpecifiedT","SpecifiedTUnit","SpecifiedQ","SpecifiedQUnit","U","A","UtilityTin","UtilityTout","ASource","UtilityTinSource"]
                    item=properties(strcmp({properties.Name},name));
                    testCase.verifyTrue(item.Hidden,sprintf('%s.%s must be hidden.',className,name));
                end
            end
        end
        function removedModeIsRejected(testCase)
            addUnit('modes_model','CSTR','nirp.blocks.CSTR',[240 120 350 190]);
            addUnit('modes_model','PFR','nirp.blocks.PFR',[240 260 350 330]);
            for block=["modes_model/CSTR","modes_model/PFR"]
                for mode=["Specified T","Specified Q"]
                    testCase.verifyError(@() set_param(block,'HeatMode',mode),?MException);
                end
            end
        end
        function reactorResultsRowNeedsNoSpecifiedUnit(testCase)
            addUnit('modes_model','CSTR','nirp.blocks.CSTR',[260 120 370 190]);
            set_param('modes_model/CSTR','HeatMode','Isothermal','ShowHeatPort','on');
            addStream('modes_model','Product','Product',[430 130 540 180]);
            add_block('simulink/Sinks/Terminator','modes_model/Heat','Position',[430 220 450 240]);
            add_line('modes_model','F1/1','CSTR/1');add_line('modes_model','CSTR/1','Product/1');
            add_line('modes_model','CSTR/2','Heat/1');
            sim('modes_model');
            tables=testCase.verifyWarningFree(@() nirp.flowsheet.showResults('modes_model','NoWindow',true));
            row=tables.Units(tables.Units.Block=="CSTR",:);
            testCase.verifyEqual(height(row),1);
            testCase.verifyEqual(row.QUnit,"W");
            testCase.verifyTrue(isfinite(row.HeatDuty));
        end
        function reactorDialogHasNoBypassOrSpecifiedModes(testCase)
            for type=["CSTR","PFR"]
                addUnit('modes_model',char(type),"nirp.blocks."+type,[240 120 350 190]);
                d=nirp.flowsheet.ReactorDialog("modes_model/"+type,'Visible','off');
                testCase.verifyEqual(sort(string({d.HeatModeGroup.Children.Text})), ...
                    sort(["Isothermal","Adiabatic"]));
                for name=["BypassField","SpecifiedTField","SpecifiedQField"]
                    testCase.verifyFalse(isprop(d,name));
                end
                labels=string(get(findall(d.Figure,'Type','uilabel'),'Text'));
                testCase.verifyFalse(any(contains(labels,"Bypass")));
                testCase.verifyEqual(d.Figure.WindowStyle,'alwaysontop');
                delete(d);delete_block("modes_model/"+type);
            end
        end
        function adjustInputIsShownAsSignal(testCase)
            addUnit('modes_model','CSTR','nirp.blocks.CSTR',[260 120 370 190]);
            set_param('modes_model/CSTR','VSource','Input port');
            addUnit('modes_model','Adjust','nirp.blocks.Adjust',[60 260 340 330]);
            addStream('modes_model','Product','Product',[430 130 540 180]);
            add_line('modes_model','F1/1','CSTR/1');add_line('modes_model','Adjust/1','CSTR/2');
            add_line('modes_model','CSTR/1','Adjust/1');add_line('modes_model','CSTR/1','Product/1');
            d=nirp.flowsheet.ReactorDialog('modes_model/CSTR','Visible','off');testCase.addTeardown(@() deleteValid(d));
            data=d.getConnections();
            testCase.verifyEqual(data(1:2,3),{'F1';'Adjust (signal): Adjust'});
            testCase.verifyFalse(any(strcmp(data(:,3),'<missing>')));
            testCase.verifyWarningFree(@() nirp.flowsheet.checkTopology('modes_model'));
        end
        function streamDialogIsResizableWithoutTips(testCase)
            for role=["Feed","Product"]
                name="S"+role;addStream('modes_model',char(name),char(role),[430 130 540 180]);
                d=nirp.flowsheet.StreamDialog("modes_model/"+name,'Visible','off');testCase.addTeardown(@() deleteValid(d));
                testCase.verifyEqual(char(d.Figure.Resize),'on');
                testCase.verifyEqual(d.Figure.WindowStyle,'alwaysontop');
                areas=findall(d.Figure,'Type','uitextarea');
                testCase.verifyEmpty(areas);
                d.Figure.Visible='on';drawnow;
                verifyStreamLayout(testCase,d);
                d.Figure.Position(3:4)=[1000 700];drawnow;
                verifyStreamLayout(testCase,d);
                delete(d);delete_block("modes_model/"+name);
            end
        end
        function unitDialogsStayOnTop(testCase)
            addUnit('modes_model','Heater','nirp.blocks.Heater',[240 120 350 190]);
            addUnit('modes_model','Jacket','nirp.blocks.Jacket',[240 190 350 250]);
            addUnit('modes_model','Mixer','nirp.blocks.Mixer',[240 260 350 330]);
            addUnit('modes_model','Splitter','nirp.blocks.Splitter',[240 400 350 470]);
            dialogs={nirp.flowsheet.HeaterDialog('modes_model/Heater','Visible','off'), ...
                nirp.flowsheet.JacketDialog('modes_model/Jacket','Visible','off'), ...
                nirp.flowsheet.MixerDialog('modes_model/Mixer','Visible','off'), ...
                nirp.flowsheet.SplitterDialog('modes_model/Splitter','Visible','off'), ...
                nirp.flowsheet.ReactiveSystemDialog('Visible','off')};
            for i=1:numel(dialogs)
                testCase.addTeardown(@() deleteValid(dialogs{i}));
                testCase.verifyEqual(dialogs{i}.Figure.WindowStyle,'alwaysontop');
            end
        end
    end
end

function verifyStreamLayout(testCase,d)
    % Grid positions are not computed in -batch sessions, so the layout is
    % checked through the grid rows (as in NirpUnitDialogsTest).
    table=d.ComponentTable;grid=table.Parent;
    for unit={d.MolarFlowUnitDropDown,d.ConcentrationUnitDropDown}
        testCase.verifyEqual(unit{1}.Parent,grid);
        testCase.verifyGreaterThan(unit{1}.Layout.Row(1),table.Layout.Row(end));
    end
    testCase.verifyLessThanOrEqual(table.Layout.Row(end),numel(grid.RowHeight));
    % The name field was 62 px high before T-131.
    nameRow=d.NameField.Layout.Row;
    testCase.verifyEqual(d.NameField.Parent,grid);
    testCase.verifyLessThanOrEqual(grid.RowHeight{nameRow},31);
end
function addUnit(model,name,className,pos),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',pos);nirp.flowsheet.setupUnitBlock([model '/' name]);end
function addStream(model,name,role,pos),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System','nirp.blocks.Stream','Role',role,'Position',pos);nirp.flowsheet.setupStreamBlock([model '/' name]);end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');f=findall(groot,'Type','Figure');if ~isempty(f),delete(f);end;evalin('base','clear nirpResults');rmpath(testCase.Folder);Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
