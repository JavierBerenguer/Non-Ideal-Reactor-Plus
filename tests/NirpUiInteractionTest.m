classdef NirpUiInteractionTest < matlab.unittest.TestCase
%NIRPUIINTERACTIONTEST Exercises callbacks exactly as the user triggers them.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 12, 2026. Last update: October 12, 2026
% =========================================================================

    properties
        Folder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder=fixture.Folder ;
            addpath(testCase.Folder) ;
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder', ...
                fullfile(testCase.Folder,'cache'),'CodeGenFolder', ...
                fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
        end
    end

    methods (Test)
        function kineticCallbacksRefreshEquationAndUnits(testCase)
            dialog=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;

            equation=string(dialog.RateEquationLabel.Text) ;
            k0Unit=string(dialog.K0UnitLabel.Text) ;
            event=struct('Indices',[1 2],'PreviousData',0, ...
                'NewData',2,'EditData','2') ;
            feval(dialog.OrdersField.CellEditCallback,dialog.OrdersField,event) ;
            testCase.verifyNotEqual(string(dialog.RateEquationLabel.Text),equation) ;
            testCase.verifyNotEqual(string(dialog.K0UnitLabel.Text),k0Unit) ;

            equation=string(dialog.RateEquationLabel.Text) ;
            k0Unit=string(dialog.K0UnitLabel.Text) ;
            dialog.ConcentrationUnitDropDown.Value=otherItem( ...
                dialog.ConcentrationUnitDropDown) ;
            feval(dialog.ConcentrationUnitDropDown.ValueChangedFcn, ...
                dialog.ConcentrationUnitDropDown,[]) ;
            testCase.verifyNotEqual(string(dialog.RateEquationLabel.Text),equation) ;
            testCase.verifyNotEqual(string(dialog.K0UnitLabel.Text),k0Unit) ;

            equation=string(dialog.RateEquationLabel.Text) ;
            k0Unit=string(dialog.K0UnitLabel.Text) ;
            dialog.TimeUnitDropDown.Value=otherItem(dialog.TimeUnitDropDown) ;
            feval(dialog.TimeUnitDropDown.ValueChangedFcn, ...
                dialog.TimeUnitDropDown,[]) ;
            testCase.verifyNotEqual(string(dialog.RateEquationLabel.Text),equation) ;
            testCase.verifyNotEqual(string(dialog.K0UnitLabel.Text),k0Unit) ;
        end

        function createFlowsheetChooserIsModalSafe(testCase)
            dialog=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            dialog.setPackage(nirp.pkg.examples.firstOrderLiquid()) ;
            figureHandle=dialog.Figure ;
            dialog.FileChooser=@(~,~,~) chooserResult(figureHandle, ...
                'interactive_model.slx',testCase.Folder) ;
            button=findall(figureHandle,'Type','uibutton', ...
                'Text','Create flowsheet...') ;
            feval(button.ButtonPushedFcn,button,[]) ;

            testCase.verifyEqual(string(getappdata(groot, ...
                'NirpStyleDuringChooser')),"normal") ;
            testCase.verifyFalse(isvalid(figureHandle)) ;
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, ...
                'interactive_model.slx'))) ;
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, ...
                'interactive_model.sldd'))) ;
        end

        function cancellingCreateRestoresWindowStyle(testCase)
            dialog=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            figureHandle=dialog.Figure ;
            dialog.FileChooser=@(~,~,~) chooserResult(figureHandle,0,0) ;
            button=findall(figureHandle,'Type','uibutton', ...
                'Text','Create flowsheet...') ;
            feval(button.ButtonPushedFcn,button,[]) ;

            testCase.verifyEqual(string(getappdata(groot, ...
                'NirpStyleDuringChooser')),"normal") ;
            testCase.verifyTrue(isvalid(figureHandle)) ;
            testCase.verifyEqual(string(figureHandle.WindowStyle),"alwaysontop") ;
            testCase.verifyEmpty(dir(fullfile(testCase.Folder,'*.slx'))) ;
        end

        function modalSafeRestoresWindowStyleAfterError(testCase)
            fig=uifigure('Visible','off','WindowStyle','alwaysontop') ;
            testCase.addTeardown(@() deleteValid(fig)) ;
            testCase.verifyError(@() nirp.flowsheet.internal.modalSafe( ...
                fig,@() error('nirptest:chooserFailure','Chooser failed.')), ...
                'nirptest:chooserFailure') ;
            testCase.verifyEqual(string(fig.WindowStyle),"alwaysontop") ;
        end

        function componentButtonsResizeEveryReactionOrderVector(testCase)
            dialog=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            dialog.setPackage(nirp.pkg.examples.firstOrderLiquid()) ;
            dialog.ReactionCountSpinner.Value=2 ;
            feval(dialog.ReactionCountSpinner.ValueChangedFcn, ...
                dialog.ReactionCountSpinner,[]) ;
            initialComponents=size(dialog.ComponentTable.Data,1) ;

            generalTab=findall(dialog.Figure,'Type','uitab','Title','General') ;
            addButton=findall(generalTab,'Type','uibutton','Text','Add') ;
            feval(addButton.ButtonPushedFcn,addButton,[]) ;
            package=dialog.getPackage() ;
            for index=1:numel(package.reactions.kinetics)
                testCase.verifyNumElements( ...
                    package.reactions.kinetics(index).orders, ...
                    initialComponents+1) ;
            end

            removeButton=findall(generalTab,'Type','uibutton','Text','Remove') ;
            feval(removeButton.ButtonPushedFcn,removeButton,[]) ;
            package=dialog.getPackage() ;
            for index=1:numel(package.reactions.kinetics)
                testCase.verifyNumElements( ...
                    package.reactions.kinetics(index).orders, ...
                    initialComponents) ;
            end
        end

        function savedExamplesAcceptAndPersistCallbackEdits(testCase)
            examples=["ex1_cstr_isothermal" ...
                "ex23_problem23_butane_isomerization" ...
                "ex36_problem36_air_cooled_cstr"] ;
            examplesFolder=fullfile(testCase.Folder,'examples') ;
            repoRoot=fileparts(fileparts(mfilename('fullpath'))) ;
            simulinkFolder=fullfile(repoRoot,'simulink') ;
            addpath(simulinkFolder) ;
            pathCleanup=onCleanup(@() rmpathIfPresent(simulinkFolder)) ; %#ok<NASGU>
            files=build_examples(examplesFolder,examples) ;
            examplesPathCleanup=onCleanup( ...
                @() rmpathIfPresent(examplesFolder)) ; %#ok<NASGU>

            for index=1:numel(files)
                [~,model]=fileparts(files(index)) ;
                load_system(files(index)) ;
                dialog=nirp.flowsheet.ReactiveSystemDialog('Mode','edit', ...
                    'Model',model,'Visible','off') ;
                figureHandle=dialog.Figure ;
                oldK0=str2double(dialog.K0Field.Value) ;
                dialog.K0Field.Value=num2str(oldK0*1.01,17) ;
                feval(dialog.K0Field.ValueChangedFcn,dialog.K0Field,[]) ;

                oldMw=dialog.GeneralComponentTable.Data{1,2} ;
                mwEvent=struct('Indices',[1 2],'PreviousData',oldMw, ...
                    'NewData',oldMw+0.01,'EditData',num2str(oldMw+0.01)) ;
                feval(dialog.GeneralComponentTable.CellEditCallback, ...
                    dialog.GeneralComponentTable,mwEvent) ;

                oldDh=dialog.ThermoReactionTable.Data{1,2} ;
                dhEvent=struct('Indices',[1 2],'PreviousData',oldDh, ...
                    'NewData',oldDh+0.01,'EditData',num2str(oldDh+0.01)) ;
                feval(dialog.ThermoReactionTable.CellEditCallback, ...
                    dialog.ThermoReactionTable,dhEvent) ;

                button=findall(figureHandle,'Type','uibutton','Text','OK') ;
                feval(button.ButtonPushedFcn,button,[]) ;
                testCase.verifyFalse(isvalid(figureHandle), ...
                    sprintf('%s did not close after OK.',model)) ;

                stored=nirp.pkg.readDictionary(fullfile(examplesFolder, ...
                    char(string(model)+".sldd"))) ;
                testCase.verifyEqual(stored.reactions.kinetics(1).k0, ...
                    oldK0*1.01,'RelTol',1e-14) ;
                testCase.verifyEqual(stored.components(1).Mw,oldMw+0.01, ...
                    'AbsTol',1e-14) ;
                testCase.verifyEqual(stored.reactions.DH.value(1), ...
                    oldDh+0.01,'AbsTol',1e-14) ;
                close_system(model,0) ;
            end
        end

        function okAndApplyNeverRunTheModel(testCase)
            editor=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            editor.setPackage(nirp.pkg.examples.firstOrderLiquid()) ;
            editor.createFlowsheet('ui_no_autorun',testCase.Folder, ...
                'OpenModel',false) ;
            delete(editor) ;
            load_system(fullfile(testCase.Folder,'ui_no_autorun.slx')) ;
            add_block('simulink/User-Defined Functions/MATLAB System', ...
                'ui_no_autorun/CSTR','System','nirp.blocks.CSTR', ...
                'Position',[210 140 310 200],'V','100','VUnit','L', ...
                'HeatMode','Isothermal') ;
            add_block('simulink/User-Defined Functions/MATLAB System', ...
                'ui_no_autorun/Product','System','nirp.blocks.Stream', ...
                'Position',[380 140 520 200],'Role','Product', ...
                'ReferenceFeed','F1','KeyComponent','A') ;
            nirp.flowsheet.setupUnitBlock('ui_no_autorun/CSTR') ;
            nirp.flowsheet.setupStreamBlock('ui_no_autorun/Product') ;
            add_line('ui_no_autorun','F1/1','CSTR/1') ;
            add_line('ui_no_autorun','CSTR/1','Product/1') ;
            nirp.flowsheet.configure('ui_no_autorun') ;
            flow=flowsheetBlock('ui_no_autorun');
            testCase.verifyFalse(any(strcmp(get_param(flow,'MaskNames'),'AutoRun')));
            acceptReactorDialog('ui_no_autorun/CSTR') ;
            testCase.verifyEqual(evalin('base', ...
                'exist(''nirpResults'',''var'')'),0) ;
        end
    end
end

function value=otherItem(dropdown)
    items=string(dropdown.Items) ;
    value=char(items(find(items~=string(dropdown.Value),1))) ;
end

function [file,folder]=chooserResult(fig,file,folder)
    setappdata(groot,'NirpStyleDuringChooser',fig.WindowStyle) ;
end

function acceptReactorDialog(block)
    dialog=nirp.flowsheet.ReactorDialog(block,'Visible','off') ;
    button=findall(dialog.Figure,'Type','uibutton','Text','OK') ;
    feval(button.ButtonPushedFcn,button,[]) ;
end

function block=flowsheetBlock(model)
    blocks=find_system(model,'SearchDepth',1,'BlockType','SubSystem') ;
    block='';
    for index=1:numel(blocks)
        if strcmp(get_param(blocks{index},'Mask'),'on') && ...
                any(strcmp(get_param(blocks{index},'MaskNames'),'MaxIterations'))
            block=blocks{index};
            return
        end
    end
    error('nirptest:missingFlowsheet','Flowsheet block was not found.') ;
end

function cleanup(testCase)
    bdclose('all') ;
    Simulink.data.dictionary.closeAll('-discard') ;
    figures=findall(groot,'Type','Figure') ;
    if ~isempty(figures),delete(figures);end
    if isappdata(groot,'NirpStyleDuringChooser')
        rmappdata(groot,'NirpStyleDuringChooser') ;
    end
    evalin('base','clear nirpResults') ;
    if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
end

function deleteValid(value)
    try
        if isvalid(value),delete(value);end
    catch
    end
end

function rmpathIfPresent(folder)
    if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end
