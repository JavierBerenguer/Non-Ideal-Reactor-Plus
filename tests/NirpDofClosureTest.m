classdef NirpDofClosureTest < matlab.unittest.TestCase
%NIRPDOFCLOSURETEST Tests simple flowsheet degree-of-freedom closures.
% =========================================================================
% Javier Berenguer Sabater
% October 9, 2026
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
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true);
            testCase.addTeardown(@() cleanup(testCase));
        end
    end

    methods (Test)
        function closeSumCompletesOneMissingFraction(testCase)
            [values,origin,message]=nirp.flowsheet.closeSum( ...
                [0.5 0.25 NaN],1);
            testCase.verifyEqual(values,[0.5 0.25 0.25],'AbsTol',1e-15);
            testCase.verifyEqual(origin, ...
                ["specified" "specified" "calculated"]);
            testCase.verifyEqual(message,"");
        end

        function closeSumReportsInvalidSpecifications(testCase)
            input=[0.5 NaN NaN];
            [actual,~,message]=nirp.flowsheet.closeSum(input,1);
            testCase.verifyTrue(isequaln(actual,input));
            testCase.verifyEqual(message,"");

            [~,~,message]=nirp.flowsheet.closeSum([0.7 0.5 NaN],1);
            testCase.verifyEqual(message, ...
                "Known fractions add up to 1.2 (> 1).");
            [~,~,message]=nirp.flowsheet.closeSum([0.5 0.4],1);
            testCase.verifyEqual(message, ...
                "Fractions add up to 0.9; they must add up to 1.");
            [~,~,message]=nirp.flowsheet.closeSum([-0.1 1.1],1);
            testCase.verifyEqual(message,"Fractions cannot be negative.");
            [~,~,message]=nirp.flowsheet.closeSum([0.2 1.1],1);
            testCase.verifyEqual(message,"Fractions cannot exceed 1.");
        end

        function splitterDialogCompletesAndRejectsMissingFractions(testCase)
            createModel(testCase,'dialog_dof');
            addSystem('dialog_dof','Splitter','nirp.blocks.Splitter', ...
                [180 80 300 170]);
            dialog=nirp.flowsheet.SplitterDialog( ...
                'dialog_dof/Splitter','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));

            dialog.setFractions([0.5 0.25 NaN]);
            values=dialog.getValues();
            testCase.verifyEqual(values.Fractions.value, ...
                [0.5 0.25 0.25],'AbsTol',1e-15);
            testCase.verifyEqual(values.Fractions.origin, ...
                ["specified" "specified" "calculated"]);
            data=dialog.FractionTable.Data;
            data{3,2}=0.25;
            dialog.FractionTable.Data=data;
            event=struct('Indices',[3 2]);
            feval(dialog.FractionTable.CellEditCallback, ...
                dialog.FractionTable,event);
            testCase.verifyEqual(dialog.getValues().Fractions.origin, ...
                repmat("specified",1,3));
            dialog.setFractions([0.5 0.25 NaN]);
            dialog.accept();
            testCase.verifyFalse(isvalid(dialog));
            testCase.verifyEqual( ...
                str2num(get_param('dialog_dof/Splitter','Fractions')), ... %#ok<ST2NM>
                [0.5 0.25 NaN]);

            dialog=nirp.flowsheet.SplitterDialog( ...
                'dialog_dof/Splitter','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            dialog.setFractions([0.5 NaN NaN]);
            dialog.accept();
            testCase.verifyTrue(isvalid(dialog));
            testCase.verifyEqual(dialog.StatusLabel.Text,'');
            testCase.verifyEqual( ...
                str2num(get_param('dialog_dof/Splitter','Fractions')), ... %#ok<ST2NM>
                [0.5 0.25 NaN]);
        end

        function splitterBlockClosesNaNAndConservesFlow(testCase)
            createModel(testCase,'block_dof');
            addSystem('block_dof','Splitter','nirp.blocks.Splitter', ...
                [180 120 300 220],'Fractions','[0.5 0.25 NaN]');
            fractions=[0.5 0.25 0.25];
            for i=1:3
                name=sprintf('Product%d',i);
                addSystem('block_dof',name,'nirp.blocks.Stream', ...
                    [390 40+100*i 500 85+100*i],'Role','Product');
                add_line('block_dof',sprintf('Splitter/%d',i), ...
                    sprintf('%s/1',name));
            end
            add_line('block_dof','F1/1','Splitter/1');
            sim('block_dof');
            feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");
            total=zeros(size(feed.F));
            for i=1:3
                result=evalin('base',sprintf( ...
                    'nirpResults.Streams.Product%d.streamSI',i));
                testCase.verifyEqual(result.F,feed.F*fractions(i), ...
                    'AbsTol',1e-12);
                total=total+result.F;
            end
            testCase.verifyEqual(total,feed.F,'AbsTol',1e-12);
        end

        function closeProductCompletesAndChecksRelationship(testCase)
            [values,origin,message]=nirp.flowsheet.closeProduct( ...
                [0.1 NaN 0.1 1],pi/4,[1 -1 -2 -1]);
            testCase.verifyEqual(values(2),0.1/(pi*0.05^2),'RelTol',1e-12);
            testCase.verifyEqual(origin, ...
                ["specified" "calculated" "specified" "specified"]);
            testCase.verifyEqual(message,"");
            [~,~,message]=nirp.flowsheet.closeProduct( ...
                [0.1 1 0.1 1],pi/4,[1 -1 -2 -1]);
            testCase.verifyNotEqual(message,"");
            [~,~,message]=nirp.flowsheet.closeProduct( ...
                [0.1 NaN NaN 1],pi/4,[1 -1 -2 -1]);
            testCase.verifyEqual(message,"");
        end

        function liquidFeedClosesAllThreeWaysAndPreservesUnits(testCase)
            createModel(testCase,'liquid_dof');
            dialog=nirp.flowsheet.StreamDialog('liquid_dof/F1','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            dialog.setUnits('F','mol/s','C','mol/L','Q','L/min');

            dialog.setValues('C',[NaN NaN],'F',[1 0],'Q',60);
            testCase.verifyEqual(dialog.getValue('C'),[1;0],'AbsTol',1e-12);
            testCase.verifyEqual(dialog.getValues().Concentration.origin,'calculated');

            dialog.setValues('F',[NaN NaN],'C',[1 0],'Q',60);
            testCase.verifyEqual(dialog.getValue('F'),[1;0],'AbsTol',1e-12);
            testCase.verifyEqual(dialog.getValues().MolarFlow.origin,'calculated');

            dialog.setValues('Q',NaN,'F',[1 0],'C',[1 0]);
            testCase.verifyEqual(dialog.getValue('Q'),60,'AbsTol',1e-10);
            testCase.verifyEqual(dialog.getValues().Q.origin,'calculated');
            fSI=UnitConverterHelper.convertToSI('MolarFlow',dialog.getValue('F'),'mol/s');
            dialog.setUnits('F','mol/min','C','mol/m^3','Q','m^3/s');
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'MolarFlow',dialog.getValue('F'),'mol/min'),fSI,'AbsTol',1e-12);
            testCase.verifyEqual(dialog.getValue('Q'),1e-3,'AbsTol',1e-15);

            dialog.setUnits('F','mol/s','C','mol/L','Q','L/min');
            dialog.setValues('F',[1 0],'C',[1 0],'Q',30);
            testCase.verifySubstring(dialog.getValue('status'),'inconsistent');
        end

        function gasFeedCalculatesReadOnlyVolumetricFlow(testCase)
            createModel(testCase,'gas_dof');
            dialog=nirp.flowsheet.StreamDialog('gas_dof/F1','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            dialog.setUnits('F','mol/s','T','K','P','Pa','Q','m^3/s');
            dialog.setValues('phase','G','F',[1 2],'T',300,'P',101325);
            expected=3*8.314*300/101325;
            testCase.verifyEqual(dialog.getValue('Q'),expected,'RelTol',1e-12);
            testCase.verifyEqual(dialog.getValues().Q.origin,'calculated');
            testCase.verifyEqual(string(dialog.VolumetricFlowField.Editable),"off");
        end

        function pfrGeometryClosesAndPersistsOrigin(testCase)
            createModel(testCase,'pfr_dof');
            addSystem('pfr_dof','PFR','nirp.blocks.PFR',[200 100 320 180]);
            dialog=nirp.flowsheet.ReactorDialog('pfr_dof/PFR','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            dialog.VUnitDropDown.Value='m^3';dialog.LUnitDropDown.Value='m';dialog.DUnitDropDown.Value='m';
            dialog.setValues('V',0.1,'L',NaN,'D',0.1,'NTubes',1);
            expectedL=0.1/(pi*0.05^2);
            testCase.verifyEqual(dialog.LField.Value,expectedL,'RelTol',1e-12);
            testCase.verifyEqual(dialog.getValues().L.origin,"calculated");
            testCase.verifyTrue(dialog.apply());
            testCase.verifyTrue(isnan(str2double(get_param('pfr_dof/PFR','L'))));
            delete(dialog);
            reopened=nirp.flowsheet.ReactorDialog('pfr_dof/PFR','Visible','off');
            testCase.addTeardown(@() deleteValid(reopened));
            testCase.verifyEqual(reopened.getValues().L.origin,"calculated");
            testCase.verifyEqual(reopened.LField.Value,expectedL,'RelTol',1e-12);
            addSystem('pfr_dof','Product','nirp.blocks.Stream',[430 100 550 160],'Role','Product');
            set_param('pfr_dof/Product','ReferenceFeed','F1','KeyComponent','A');
            add_line('pfr_dof','F1/1','PFR/1');add_line('pfr_dof','PFR/1','Product/1');
            sim('pfr_dof');result=evalin('base','nirpResults.Streams.Product.streamSI');
            testCase.verifyEqual(result.status,1);

            reopened.setValues('V',NaN,'L',2,'D',0.1,'NTubes',1);
            testCase.verifyEqual(reopened.VField.Value,pi*0.05^2*2,'RelTol',1e-12);
            testCase.verifyEqual(reopened.getValues().V.origin,"calculated");
            reopened.setValues('V',0.1,'L',2,'D',0.1,'NTubes',1);
            testCase.verifySubstring(string(reopened.StatusLabel.Text),'do not satisfy');
        end

        function dialogActionsAreUniformAndInvalidOkStaysOpen(testCase)
            createModel(testCase,'buttons_dof');
            addSystem('buttons_dof','CSTR','nirp.blocks.CSTR',[200 70 320 130]);
            addSystem('buttons_dof','Heater','nirp.blocks.Heater',[200 160 320 220]);
            addSystem('buttons_dof','Splitter','nirp.blocks.Splitter',[400 70 520 140]);
            addSystem('buttons_dof','Mixer','nirp.blocks.Mixer',[400 170 520 240]);
            dialogs={nirp.flowsheet.StreamDialog('buttons_dof/F1','Visible','off'), ...
                nirp.flowsheet.ReactorDialog('buttons_dof/CSTR','Visible','off'), ...
                nirp.flowsheet.HeaterDialog('buttons_dof/Heater','Visible','off'), ...
                nirp.flowsheet.SplitterDialog('buttons_dof/Splitter','Visible','off'), ...
                nirp.flowsheet.MixerDialog('buttons_dof/Mixer','Visible','off')};
            for i=1:numel(dialogs),testCase.addTeardown(@() deleteValid(dialogs{i}));verifyActions(testCase,dialogs{i}.Figure,["OK" "Cancel" "Apply"]);end

            addSystem('buttons_dof','Product','nirp.blocks.Stream',[600 70 720 130],'Role','Product');
            readOnly=nirp.flowsheet.StreamDialog('buttons_dof/Product','Visible','off');testCase.addTeardown(@() deleteValid(readOnly));verifyActions(testCase,readOnly.Figure,"Close");
            editor=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model','buttons_dof','Visible','off');testCase.addTeardown(@() deleteValid(editor));verifyActions(testCase,editor.Figure,["OK" "Cancel"]); % T-144: no Apply
            fresh=nirp.flowsheet.ReactiveSystemDialog('Visible','off');testCase.addTeardown(@() deleteValid(fresh));verifyActions(testCase,fresh.Figure,["Create flowsheet..." "Cancel"]);

            invalid=dialogs{4};invalid.setFractions([0.5 NaN NaN]);invalid.accept();
            testCase.verifyTrue(isvalid(invalid));testCase.verifyEqual(invalid.StatusLabel.Text,'');
        end
    end
end

function createModel(testCase,name)
    nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(), ...
        testCase.Folder,'OpenModel',false);
    load_system(fullfile(testCase.Folder,[name '.slx']));
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System', ...
        [model '/' name],'System',className,'Position',position,varargin{:});
    if strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupStreamBlock([model '/' name]);
    else
        nirp.flowsheet.setupUnitBlock([model '/' name]);
    end
end

function verifyActions(testCase,figure,expected)
    labels=["OK" "Cancel" "Apply" "Close" "Create flowsheet..." "Validate" "Save to model" "Save stream"];
    % Only visible buttons count: since T-136 the Stream dialog keeps OK/Apply
    % hidden on products so that the role can be changed from the dialog.
    buttons=findall(figure,'Type','uibutton','Visible','on');texts=string({buttons.Text});
    action=buttons(ismember(texts,labels));texts=string({action.Text});
    x=zeros(size(action));
    for i=1:numel(action)
        if isa(action(i).Parent,'matlab.ui.container.GridLayout'),x(i)=action(i).Layout.Column(1);else,x(i)=action(i).Position(1);end
    end
    [~,order]=sort(x);testCase.verifyEqual(reshape(texts(order),1,[]),reshape(expected,1,[]));
end

function cleanup(testCase)
    bdclose('all');
    Simulink.data.dictionary.closeAll('-discard');
    figures=findall(groot,'Type','Figure');
    if ~isempty(figures)
        delete(figures);
    end
    evalin('base','clear nirpResults');
    rmpath(testCase.Folder);
    Simulink.fileGenControl('setConfig','config', ...
        testCase.FileGenerationConfig);
end

function deleteValid(value)
    try
        if isvalid(value)
            delete(value);
        end
    catch
    end
end
