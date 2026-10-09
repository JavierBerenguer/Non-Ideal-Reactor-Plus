classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpAdjustDialogTest < matlab.unittest.TestCase
    % NirpAdjustDialogTest verifies Adjust targets, units, and editor UI.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        Files
    end

    methods (TestClassSetup)
        function prepareExamples(testCase)
            examples=testCase.getSharedTestFixtures('nirptest.ExamplesFixture');
            testCase.Folder=examples.Folder;testCase.Files=examples.Files;
        end
    end

    methods (TestMethodTeardown)
        function closeRun(~)
            figures=findall(groot,'Type','Figure');
            if ~isempty(figures),delete(figures);end
            bdclose('all');Simulink.data.dictionary.closeAll('-discard');
            evalin('base','clear nirpResults');
        end
    end

    methods (Test)
        function targetsIdentifyExampleParameterPorts(testCase)
            load_system(char(testCase.Files(18)));
            verifyTarget(testCase,'ex18_problem44a_volumes/Adjust PFR', ...
                "PFR / V","Volume",2);
            verifyTarget(testCase,'ex18_problem44a_volumes/Adjust CSTR', ...
                "CSTR / V","Volume",2);
            close_system('ex18_problem44a_volumes',0);

            load_system(char(testCase.Files(34)));
            verifyTarget(testCase,'ex34_problem45c_cooled_tanks/Adjust 2', ...
                "Jacket 2 / A","Area",1);
            verifyTarget(testCase,'ex34_problem45c_cooled_tanks/Adjust 3', ...
                "Jacket 3 / A","Area",1);
            close_system('ex34_problem45c_cooled_tanks',0);

            load_system(char(testCase.Files(35)));
            verifyTarget(testCase,'ex35_problem28_steam_jacket/Adjust', ...
                "Jacket / UtilityTin","Temperature",1);
            close_system('ex35_problem28_steam_jacket',0);

            load_system(char(testCase.Files(13)));
            verifyTarget(testCase,'ex13_problem21a_isothermal_pfr/Adjust', ...
                "F1 / T","Temperature",1);
        end

        function incompatibleParameterUnitIsRejected(testCase)
            load_system(char(testCase.Files(13)));
            set_param('ex13_problem21a_isothermal_pfr/Adjust','ParameterUnit','m^3');
            expected=['Adjust "Adjust" moves F1 / T (Temperature) but its ' ...
                'parameter unit is m^3 (Volume).'];
            testCase.verifyError(@() nirp.flowsheet.checkTopology( ...
                'ex13_problem21a_isothermal_pfr'), ...
                'nirp:blocks:invalidAdjustParameterUnit');
            try
                nirp.flowsheet.checkTopology('ex13_problem21a_isothermal_pfr');
            catch exception
                testCase.verifyEqual(exception.message,expected);
            end
        end

        function representativeExamplesSimulateWithCompatibleUnits(testCase)
            indices=[18 34 13];
            names=["ex18_problem44a_volumes","ex34_problem45c_cooled_tanks", ...
                "ex13_problem21a_isothermal_pfr"];
            for i=1:numel(indices)
                load_system(char(testCase.Files(indices(i))));
                testCase.verifyWarningFree(@() sim(char(names(i))));
                close_system(char(names(i)),0);
                Simulink.data.dictionary.closeAll('-discard');
                evalin('base','clear nirpResults');
            end
        end

        function dialogLoadsAppliesAndMovesConnection(testCase)
            new_system('adjust_dialog_test');
            addUnit('adjust_dialog_test','Adjust','nirp.blocks.Adjust',[30 180 240 240]);
            addUnit('adjust_dialog_test','CSTR 1','nirp.blocks.CSTR',[350 60 470 130], ...
                'VSource','Input port');
            addUnit('adjust_dialog_test','CSTR 2','nirp.blocks.CSTR',[350 220 470 290], ...
                'VSource','Input port');
            add_line('adjust_dialog_test','Adjust/1','CSTR 1/2');

            dialog=nirp.flowsheet.AdjustDialog( ...
                'adjust_dialog_test/Adjust','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(string(dialog.TargetLabel.Text),"CSTR 1 / V");
            testCase.verifyEqual(string(dialog.Figure.WindowStyle),"alwaysontop");
            testCase.verifyEqual(dialog.TargetValueField.Value,0.8);
            testCase.verifyEqual(string(dialog.ParameterUnitDropDown.Value),"m^3");
            items=string(dialog.TargetDropDown.Items);
            testCase.verifyFalse(any(items=="CSTR 1 / V"));
            testCase.verifyTrue(any(items=="CSTR 2 / V"));

            dialog.setValues('TargetValue',0.75,'InitialValue',0.2, ...
                'MinValue',0.05,'MaxValue',2,'Tolerance',1e-7, ...
                'Damping',0.5,'Strategy','Nested');
            testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(str2double(get_param( ...
                'adjust_dialog_test/Adjust','TargetValue')),0.75);
            testCase.verifyEqual(get_param( ...
                'adjust_dialog_test/Adjust','Strategy'),'Nested');

            dialog.TargetDropDown.Value='CSTR 2 / V';dialog.connect();
            target=nirp.flowsheet.adjustTarget('adjust_dialog_test/Adjust');
            testCase.verifyEqual(target.Label,"CSTR 2 / V");
            ports=get_param('adjust_dialog_test/CSTR 1','PortHandles');
            testCase.verifyEqual(get_param(ports.Inport(2),'Line'),-1);
            testCase.verifyEqual(string(dialog.ParameterUnitDropDown.Items), ...
                string(UnitConverterHelper.getUnits('Volume')));
        end

        function resultsNameBothAdjustedVariables(testCase)
            load_system(char(testCase.Files(18)));sim('ex18_problem44a_volumes');
            tables=nirp.flowsheet.showResults( ...
                'ex18_problem44a_volumes','NoWindow',true);
            testCase.verifyTrue(ismember('AdjustedVariable', ...
                tables.Adjust.Properties.VariableNames));
            expected=containers.Map( ...
                {'Adjust CSTR','Adjust PFR'},{'CSTR / V','PFR / V'});
            for i=1:height(tables.Adjust)
                testCase.verifyEqual(tables.Adjust.AdjustedVariable(i), ...
                    string(expected(char(tables.Adjust.Block(i)))));
            end
        end
    end
end

function verifyTarget(testCase,block,label,category,port)
    target=nirp.flowsheet.adjustTarget(block);
    testCase.verifyEqual(target.Label,label);
    testCase.verifyEqual(target.Category,category);
    testCase.verifyEqual(target.Port,port);
    testCase.verifyEqual(target.Variable,extractAfter(label," / "));
end
function addUnit(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System', ...
        [model '/' name],'System',className,'Position',position,varargin{:});
    nirp.flowsheet.setupUnitBlock([model '/' name]);
end
function deleteValid(value)
    try,if isvalid(value),delete(value);end,catch,end
end
