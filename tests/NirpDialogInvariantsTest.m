classdef NirpDialogInvariantsTest < matlab.unittest.TestCase
%NIRPDIALOGINVARIANTSTEST Common presentation and editing invariants.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;
            addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            testCase.addTeardown(@()cleanup(testCase));
        end
    end

    methods (Test)
        function everyTableHasOneEditableFlagPerColumn(testCase)
            createDialogModel(testCase,'dialog_invariants');
            dialogs={nirp.flowsheet.StreamDialog('dialog_invariants/F1','Visible','off'), ...
                nirp.flowsheet.ReactorDialog('dialog_invariants/CSTR','Visible','off'), ...
                nirp.flowsheet.SplitterDialog('dialog_invariants/Splitter','Visible','off'), ...
                nirp.flowsheet.SeparatorDialog('dialog_invariants/Separator','Visible','off'), ...
                nirp.flowsheet.HeaterDialog('dialog_invariants/Heater','Visible','off'), ...
                nirp.flowsheet.JacketDialog('dialog_invariants/Jacket','Visible','off'), ...
                nirp.flowsheet.MixerDialog('dialog_invariants/Mixer','Visible','off'), ...
                nirp.flowsheet.RecycleDialog('dialog_invariants/Recycle','Visible','off'), ...
                nirp.flowsheet.AdjustDialog('dialog_invariants/Adjust','Visible','off'), ...
                nirp.flowsheet.ReactiveSystemDialog('Visible','off')};
            testCase.addTeardown(@()deleteDialogs(dialogs));
            for i=1:numel(dialogs)
                tables=findall(dialogs{i}.Figure,'Type','uitable');
                for j=1:numel(tables)
                    if strcmp(tables(j).Visible,'off'),continue,end
                    width=numel(tables(j).ColumnName);
                    testCase.verifyNumElements(tables(j).ColumnEditable,width, ...
                        sprintf('%s table %d has %d columns.',class(dialogs{i}),j,width));
                end
            end
        end

        function visibleFieldLabelsHaveVisibleControlsBesideThem(testCase)
            createDialogModel(testCase,'label_invariants');
            dialogs=allDialogs('label_invariants','off');testCase.addTeardown(@()deleteDialogs(dialogs));
            checked=0;
            for i=1:numel(dialogs)
                labels=findall(dialogs{i}.Figure,'Type','uilabel');
                for j=1:numel(labels)
                    if ~strcmp(labels(j).Visible,'on')||~strcmp(labels(j).HorizontalAlignment,'right')||strlength(string(labels(j).Text))==0,continue,end
                    checked=checked+1;
                    testCase.verifyTrue(hasVisibleControlBeside(labels(j)), ...
                        sprintf('%s has an orphan visible label: %s',class(dialogs{i}),string(labels(j).Text)));
                end
            end
            testCase.verifyGreaterThan(checked,20);
        end

        function fullySpecifiedDialogsApplyAndReopen(testCase)
            createDialogModel(testCase,'apply_roundtrip');
            stream=nirp.flowsheet.StreamDialog('apply_roundtrip/F1','Visible','off');before=stream.getValues();
            testCase.verifyTrue(stream.apply());delete(stream);stream=nirp.flowsheet.StreamDialog('apply_roundtrip/F1','Visible','off');
            after=stream.getValues();testCase.verifyEqual(after.T.value,before.T.value);testCase.verifyEqual(string(after.T.origin),string(before.T.origin));delete(stream);

            reactor=nirp.flowsheet.ReactorDialog('apply_roundtrip/CSTR','Visible','off');reactor.setHeatMode('Heat exchange');reactor.setValues('tau',10);
            testCase.verifyTrue(reactor.apply());delete(reactor);reactor=nirp.flowsheet.ReactorDialog('apply_roundtrip/CSTR','Visible','off');
            testCase.verifyEqual(reactor.getValues().Result.origins.tau,'specified');delete(reactor);add_line('apply_roundtrip','Jacket/1','CSTR/2');

            splitter=nirp.flowsheet.SplitterDialog('apply_roundtrip/Splitter','Visible','off');splitter.setFractions([0.4 NaN]);
            testCase.verifyTrue(splitter.apply());delete(splitter);splitter=nirp.flowsheet.SplitterDialog('apply_roundtrip/Splitter','Visible','off');
            testCase.verifyEqual(string(splitter.getValues().Fractions.origin),["specified" "calculated"]);delete(splitter);

            separator=nirp.flowsheet.SeparatorDialog('apply_roundtrip/Separator','Visible','off');separator.setRecovery([0.4 0.3]);
            testCase.verifyTrue(separator.apply());delete(separator);separator=nirp.flowsheet.SeparatorDialog('apply_roundtrip/Separator','Visible','off');
            origins=string(separator.getValues().Recovery.origin);testCase.verifyEqual(origins(:)',["specified" "specified"]);delete(separator);

            heater=nirp.flowsheet.HeaterDialog('apply_roundtrip/Heater','Visible','off');heater.setValues('dT',10,'dP',0);
            testCase.verifyTrue(heater.apply());delete(heater);heater=nirp.flowsheet.HeaterDialog('apply_roundtrip/Heater','Visible','off');
            testCase.verifyEqual(heater.getValues().Result.origins.dT,'specified');delete(heater);

            set_param('apply_roundtrip/Jacket','Mode','Select...');jacket=nirp.flowsheet.JacketDialog('apply_roundtrip/Jacket','Visible','off');jacket.ModeDropDown.Value='Utility';
            feval(jacket.ModeDropDown.ValueChangedFcn,jacket.ModeDropDown,struct('PreviousValue','Select...','Value','Utility'));
            jacket.setValues('UA',1000,'A',5,'UtilityTin',290);testCase.verifyTrue(jacket.apply());delete(jacket);
            jacket=nirp.flowsheet.JacketDialog('apply_roundtrip/Jacket','Visible','off');testCase.verifyEqual(string(jacket.ModeDropDown.Value),"Utility");
            specs=nirp.dof.readSpecs(get_param('apply_roundtrip/Jacket','Specifications'));testCase.verifyTrue(all(isfield(specs,{'UA','A','T_in_s'})));delete(jacket);

            mixer=nirp.flowsheet.MixerDialog('apply_roundtrip/Mixer','Visible','off');mixer.setNumInputs(3);testCase.verifyTrue(mixer.apply());delete(mixer);
            mixer=nirp.flowsheet.MixerDialog('apply_roundtrip/Mixer','Visible','off');testCase.verifyEqual(mixer.getValues().NumInputs.value,3);delete(mixer);

            reactive=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model','apply_roundtrip','Visible','off');
            apply=findall(reactive.Figure,'Type','uibutton','Text','Apply');feval(apply.ButtonPushedFcn,apply,[]);testCase.verifyTrue(isvalid(reactive.Figure));delete(reactive);
            reactive=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model','apply_roundtrip','Visible','off');testCase.verifyEqual(string(reactive.StatusLabel.Text),"Package loaded.");delete(reactive);
        end

        function conflictAlertLeavesDialogResponsive(testCase)
            createDialogModel(testCase,'alert_invariant');
            dialog=nirp.flowsheet.SplitterDialog('alert_invariant/Splitter','Visible','on');testCase.addTeardown(@()deleteValid(dialog));drawnow;
            dialog.setFractions([0.8 0.8]);testCase.verifyFalse(dialog.apply());drawnow;
            testCase.verifyTrue(isvalid(dialog.Figure));testCase.verifyEqual(string(dialog.NameField.Value),"Splitter");
            dialog.setFractions([0.4 NaN]);testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');
        end

        function calculatedPreviewUsesCalculatedReadOnlyStyle(testCase)
            createPreviewModel(testCase,'preview_style');
            nirp.flowsheet.propagate('preview_style');
            dialog=nirp.flowsheet.StreamDialog('preview_style/Product','Visible','off');
            testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyEqual(string(dialog.StatusLabel.Text),"Calculated before run");
            fields=[dialog.TotalMolarFlowField dialog.TotalConcentrationField ...
                dialog.VolumetricFlowField dialog.TemperatureField dialog.PressureField];
            for field=fields
                testCase.verifyEqual(field.BackgroundColor,[0.92 0.92 0.92],'AbsTol',1e-12);
                testCase.verifyEqual(string(field.FontAngle),"italic");
                testCase.verifyEqual(string(field.Editable),"off");
            end
            testCase.verifyFalse(any(dialog.ComponentTable.ColumnEditable));
        end

        function numericPresentationUsesSixSignificantDigits(testCase)
            testCase.verifyEqual(nirp.flowsheet.internal.formatTableNumber(26.0767059333732),'26.0767');
            createDialogModel(testCase,'numeric_format');
            dialog=nirp.flowsheet.StreamDialog('numeric_format/New Feed','Visible','off');
            testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyEqual(string(dialog.TemperatureField.ValueDisplayFormat),"%.6g");
            precise=1.23456789012345;
            editCell(dialog.ComponentTable,1,3,precise);
            editCell(dialog.ComponentTable,2,3,2.34567890123456);
            editNumeric(dialog.VolumetricFlowField,0.01);
            editNumeric(dialog.TemperatureField,310.123456789);
            editNumeric(dialog.PressureField,150123.456789);
            testCase.verifyTrue(dialog.apply());
            package=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary('numeric_format'));
            feed=nirp.pkg.feedStream(package,"New Feed");
            flowSI=UnitConverterHelper.convertToSI('VolumetricFlow',0.01,dialog.VolumetricFlowUnitDropDown.Value);
            firstSI=UnitConverterHelper.convertToSI('Concentration',precise,dialog.ConcentrationUnitDropDown.Value);
            secondSI=UnitConverterHelper.convertToSI('Concentration',2.34567890123456,dialog.ConcentrationUnitDropDown.Value);
            testCase.verifyEqual(feed.F(1),firstSI*flowSI,'RelTol',1e-12);
            testCase.verifyEqual(feed.F(2),secondSI*flowSI,'RelTol',1e-12);
        end

        function onlyExternalFeedControlsAreLocked(testCase)
            createDialogModel(testCase,'editable_states');
            dialog=nirp.flowsheet.StreamDialog('editable_states/F1','Visible','off');
            testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyEqual(string(dialog.VolumetricFlowField.Editable),"on");
            testCase.verifyTrue(all(dialog.ComponentTable.ColumnEditable(2:end)));
            dialog.QSourceDropDown.Value='Input port';
            feval(dialog.QSourceDropDown.ValueChangedFcn,dialog.QSourceDropDown,struct( ...
                'PreviousValue','Dialog','Value','Input port'));
            testCase.verifyEqual(string(dialog.VolumetricFlowField.Editable),"off");
            testCase.verifyEqual(string(dialog.VolumetricFlowField.Visible),"off");
            testCase.verifyEqual(string(dialog.QPortLabel.Visible),"on");
            dialog.QSourceDropDown.Value='Dialog';
            feval(dialog.QSourceDropDown.ValueChangedFcn,dialog.QSourceDropDown,struct( ...
                'PreviousValue','Input port','Value','Dialog'));
            testCase.verifyEqual(string(dialog.VolumetricFlowField.Editable),"on");
        end

        function statusAndTooltipsDoNotExposeInternalNames(testCase)
            createDialogModel(testCase,'friendly_messages');
            dialogs={nirp.flowsheet.StreamDialog('friendly_messages/F1','Visible','off'), ...
                nirp.flowsheet.ReactorDialog('friendly_messages/CSTR','Visible','off'), ...
                nirp.flowsheet.SplitterDialog('friendly_messages/Splitter','Visible','off'), ...
                nirp.flowsheet.SeparatorDialog('friendly_messages/Separator','Visible','off'), ...
                nirp.flowsheet.HeaterDialog('friendly_messages/Heater','Visible','off'), ...
                nirp.flowsheet.JacketDialog('friendly_messages/Jacket','Visible','off')};
            testCase.addTeardown(@()deleteDialogs(dialogs));
            pattern='(?<![A-Za-z0-9_])(x\d+|F_(top|bot|out)\d+|tau|T_out|P_out|Q0)(?![A-Za-z0-9_])';
            for i=1:numel(dialogs)
                controls=findall(dialogs{i}.Figure);
                text=string(dialogs{i}.StatusLabel.Text);
                for j=1:numel(controls)
                    if isprop(controls(j),'Tooltip')&&strlength(string(controls(j).Tooltip))>0
                        text(end+1)=string(controls(j).Tooltip); %#ok<AGROW>
                    end
                end
                testCase.verifyEmpty(regexp(strjoin(text,' '),pattern,'once'),class(dialogs{i}));
            end
        end
    end
end

function createDialogModel(testCase,name)
    nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);
    load_system(fullfile(testCase.Folder,[name '.slx']));
    addSystem(name,'CSTR','nirp.blocks.CSTR',[180 20 290 80]);
    addSystem(name,'Splitter','nirp.blocks.Splitter',[180 100 290 170]);
    addSystem(name,'Separator','nirp.blocks.Separator',[180 190 290 260]);
    addSystem(name,'Heater','nirp.blocks.Heater',[360 20 470 90]);
    addSystem(name,'Jacket','nirp.blocks.Jacket',[360 110 470 180]);
    addSystem(name,'Mixer','nirp.blocks.Mixer',[360 290 470 360]);
    addSystem(name,'Recycle','nirp.blocks.Recycle',[360 200 470 270]);
    addSystem(name,'Adjust','nirp.blocks.Adjust',[530 20 640 90]);
    addSystem(name,'New Feed','nirp.blocks.Stream',[530 110 640 170],'Role','Feed');
end

function dialogs=allDialogs(model,visible)
    dialogs={nirp.flowsheet.StreamDialog([model '/F1'],'Visible',visible), ...
        nirp.flowsheet.ReactorDialog([model '/CSTR'],'Visible',visible), ...
        nirp.flowsheet.SplitterDialog([model '/Splitter'],'Visible',visible), ...
        nirp.flowsheet.SeparatorDialog([model '/Separator'],'Visible',visible), ...
        nirp.flowsheet.HeaterDialog([model '/Heater'],'Visible',visible), ...
        nirp.flowsheet.JacketDialog([model '/Jacket'],'Visible',visible), ...
        nirp.flowsheet.MixerDialog([model '/Mixer'],'Visible',visible), ...
        nirp.flowsheet.RecycleDialog([model '/Recycle'],'Visible',visible), ...
        nirp.flowsheet.AdjustDialog([model '/Adjust'],'Visible',visible), ...
        nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model',model,'Visible',visible)};
end

function flag=hasVisibleControlBeside(label)
    flag=false;row=layoutExtent(label.Layout.Row);column=layoutExtent(label.Layout.Column);siblings=label.Parent.Children;
    for i=1:numel(siblings)
        candidate=siblings(i);if candidate==label||~isprop(candidate,'Visible')||~strcmp(candidate.Visible,'on')||~isprop(candidate,'Layout'),continue,end
        otherRow=layoutExtent(candidate.Layout.Row);otherColumn=layoutExtent(candidate.Layout.Column);
        if rangesOverlap(row,otherRow)&&otherColumn(1)>column(2),flag=true;return,end
    end
end

function extent=layoutExtent(value)
    if isnumeric(value),extent=[value(1) value(end)];else,extent=[NaN NaN];end
end

function flag=rangesOverlap(first,second)
    flag=all(isfinite([first second]))&&first(1)<=second(2)&&second(1)<=first(2);
end

function createPreviewModel(testCase,name)
    nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);
    load_system(fullfile(testCase.Folder,[name '.slx']));
    addSystem(name,'Splitter','nirp.blocks.Splitter',[180 80 290 160], ...
        'Fractions','[0.4 0.6]');
    addSystem(name,'Product','nirp.blocks.Stream',[380 50 480 100],'Role','Product');
    addSystem(name,'Product 2','nirp.blocks.Stream',[380 150 480 200],'Role','Product');
    add_line(name,'F1/1','Splitter/1');
    add_line(name,'Splitter/1','Product/1');
    add_line(name,'Splitter/2','Product 2/1');
    nirp.flowsheet.configure(name);
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:});
    if strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupStreamBlock([model '/' name]);
    else
        nirp.flowsheet.setupUnitBlock([model '/' name]);
    end
end

function editCell(tableHandle,row,column,value)
    data=tableHandle.Data;previous=data{row,column};data{row,column}=value;tableHandle.Data=data;
    event=struct('Indices',[row column],'PreviousData',previous,'NewData',value, ...
        'EditData',num2str(value,17));
    feval(tableHandle.CellEditCallback,tableHandle,event);
end

function editNumeric(field,value)
    previous=field.Value;field.Value=value;
    feval(field.ValueChangedFcn,field,struct('PreviousValue',previous,'Value',value));
end

function cleanup(testCase)
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');
    evalin('base','clear nirpResults');
    if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);
    figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end
end

function deleteDialogs(dialogs)
    for i=1:numel(dialogs),deleteValid(dialogs{i});end
end

function deleteValid(value)
    try,if isvalid(value),delete(value);end,catch,end
end
